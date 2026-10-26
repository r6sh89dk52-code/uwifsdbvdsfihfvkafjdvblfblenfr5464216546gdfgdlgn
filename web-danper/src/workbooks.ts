import { notifySuccess } from "./feedback";
import { trialMode } from "./workspace";
import { strFromU8, strToU8, zipSync } from "fflate";
import { readAmbulatoryArchive } from "../legacy/ambulatoryArchive";
import {
  excelDate,
  type ExportPlan,
  type ExportValue,
} from "../legacy/ambulatoryRows";
import { exportAmbulatoryWorkbook } from "../legacy/ambulatoryExcel";
import { exportOfficialKardex } from "../legacy/kardexExcelTemplate";
import { procedureDetail } from "../legacy/procedureRules";
import { kardexCatalog } from "../legacy/kardexCatalog";
import template from "../legacy/ambulatoryTemplate.json";
import { reportBalance, candidates, isContainer } from "./accounting";
import {
  limaDay,
  normalize,
  type Visit,
  type Lot,
  type Movement,
  type Exam,
  type Worker,
} from "./model";
const NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
export function xml(s: string) {
  if (/<!DOCTYPE|<!ENTITY/i.test(s)) throw Error("Entidades XML no permitidas");
  const d = new DOMParser().parseFromString(
    s.replace(/^\uFEFF/, ""),
    "application/xml",
  );
  if (d.getElementsByTagName("parsererror").length) throw Error("XML inválido");
  return d;
}
const all = (d: Document | Element, n: string) =>
  Array.from(d.getElementsByTagNameNS("*", n));
export type Sheet = {
  name: string;
  part: string;
  rows: { row: number; values: Record<string, string> }[];
};
export function inspectWorkbook(bytes: Uint8Array): Sheet[] {
  const zip = readAmbulatoryArchive(bytes);
  const wb = xml(strFromU8(zip["xl/workbook.xml"]));
  const rels = xml(strFromU8(zip["xl/_rels/workbook.xml.rels"]));
  const shared = zip["xl/sharedStrings.xml"]
    ? all(xml(strFromU8(zip["xl/sharedStrings.xml"])), "si").map((si) =>
        all(si, "t")
          .map((t) => t.textContent || "")
          .join(""),
      )
    : [];
  return all(wb, "sheet").map((sheet) => {
    const rid = sheet.getAttribute("r:id");
    const target =
      all(rels, "Relationship")
        .find((r) => r.getAttribute("Id") === rid)
        ?.getAttribute("Target") || "";
    const part = target.startsWith("/")
      ? target.slice(1)
      : "xl/" + target.replace(/^\.\//, "");
    if (!/^xl\/worksheets\/[\w.-]+\.xml$/.test(part) || !zip[part])
      throw Error("Referencia de hoja inválida");
    const d = xml(strFromU8(zip[part]));
    return {
      name: sheet.getAttribute("name") || "",
      part,
      rows: all(d, "row").map((r) => ({
        row: Number(r.getAttribute("r")),
        values: Object.fromEntries(
          all(r, "c").map((c) => {
            const col = (c.getAttribute("r") || "").replace(/\d/g, "");
            const v = all(c, "v")[0]?.textContent || "";
            return [
              col,
              c.getAttribute("t") === "s"
                ? shared[Number(v)] || ""
                : c.getAttribute("t") === "inlineStr"
                  ? all(c, "t")
                      .map((t) => t.textContent || "")
                      .join("")
                  : v,
            ];
          }),
        ),
      })),
    };
  });
}
export function parseDate(raw: string): string {
  if (!raw) return "";
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) {
    if (new Date(raw + "T12:00:00Z").toISOString().slice(0, 10) === raw)
      return raw;
    return "";
  }
  if (/^\d{4,5}(\.\d+)?$/.test(raw)) {
    const d = new Date(
      Date.UTC(1899, 11, 30) + Math.floor(Number(raw)) * 86400000,
    );
    return d.toISOString().slice(0, 10);
  }
  const m = raw.match(/^(\d{1,2})[/-](\d{1,2})[/-](\d{4})$/);
  return m
    ? parseDate(
        m[3] + "-" + m[2].padStart(2, "0") + "-" + m[1].padStart(2, "0"),
      )
    : "";
}
export type ExamMapping = {
  dni: string;
  name: string;
  date: string;
  result: string;
  type: string;
  profile: string;
  area: string;
  labor: string;
  nextDate: string;
  campaign: string;
};
export async function previewExams(
  sheet: Sheet,
  m: ExamMapping,
  workers: Worker[],
  kind: "emo" | "cholinesterase",
  headerRow: number,
  mode: "results" | "campaign" = "results",
) {
  if (mode === "results" && (!m.dni || !m.date || !m.result))
    throw Error("Mapea DNI, fecha y resultado");
  if (mode === "campaign" && (!m.dni || (!m.nextDate && !m.campaign)))
    throw Error("Mapea DNI y fecha próxima o campaña de la base seleccionada");
  const roster = new Map(workers.map((w) => [w.dni, w]));
  const exams: Exam[] = [];
  const issues: { row: number; reason: string }[] = [];
  for (const row of sheet.rows.filter((r) => r.row > headerRow)) {
    const get = (k: keyof ExamMapping) => row.values[m[k]]?.trim() || "";
    const dni = get("dni").replace(/\.0$/, "");
    if (!dni && !get("date")) continue;
    const date = parseDate(get("date"));
    if (
      !/^\d{8}$/.test(dni) ||
      (mode === "results" && (!date || !get("result")))
    ) {
      issues.push({ row: row.row, reason: "DNI, fecha o resultado inválido" });
      continue;
    }
    if (
      mode === "results" &&
      kind === "cholinesterase" &&
      !/COLINESTERAS[AE]/.test(normalize(get("type") + " " + get("profile")))
    ) {
      issues.push({
        row: row.row,
        reason: "El tipo/perfil no acredita colinesterasa",
      });
      continue;
    }
    const w = roster.get(dni);
    if (!w)
      issues.push({
        row: row.row,
        reason: "DNI ausente del padrón vigente; conservar como histórico",
      });
    else if (get("name") && normalize(get("name")) !== normalize(w.name))
      issues.push({
        row: row.row,
        reason: "Nombre discrepante; vínculo por DNI",
      });
    const content = {
      dni,
      name: get("name"),
      date,
      result: mode === "results" ? get("result") : "PENDIENTE",
      type:
        get("type") ||
        (mode === "campaign" ? (kind === "emo" ? "EMO" : "COLINESTERASA") : ""),
      profile: get("profile"),
      area: get("area"),
      labor: get("labor"),
      nextDate: parseDate(get("nextDate")),
      campaign: get("campaign"),
    };
    const hash = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(JSON.stringify({ mode, ...content })),
    );
    const id = Array.from(new Uint8Array(hash), (b) =>
      b.toString(16).padStart(2, "0"),
    ).join("");
    exams.push({
      id,
      ...content,
      selected: mode === "campaign",
      source: sheet.name,
      verified: mode === "results",
      templateRow: row.row,
    });
  }
  return { exams: [...new Map(exams.map((e) => [e.id, e])).values()], issues };
}
/** Change only designated date cells. All other OOXML parts remain byte-identical. */
export function patchTemplateDates(
  bytes: Uint8Array,
  part: string,
  dates: Record<string, string>,
) {
  const zip = readAmbulatoryArchive(bytes);
  if (!zip[part]) throw Error("Hoja ausente en plantilla");
  const d = xml(strFromU8(zip[part]));
  for (const [ref, date] of Object.entries(dates)) {
    if (!/^[A-Z]{1,3}[1-9]\d*$/.test(ref)) throw Error("Celda inválida");
    const c = all(d, "c").find((c) => c.getAttribute("r") === ref);
    if (!c) throw Error("Celda no presente: " + ref);
    for (const n of Array.from(c.childNodes))
      if (["v", "f", "is"].includes((n as Element).localName)) c.removeChild(n);
    c.removeAttribute("t");
    if (date) {
      const v = d.createElementNS(NS, "v");
      v.textContent = String(excelDate(date));
      c.appendChild(v);
    }
  }
  zip[part] = strToU8(new XMLSerializer().serializeToString(d));
  return zipSync(zip, { level: 6 });
}
export function indicatorPlan(
  visits: Visit[],
  movements: Movement[],
  start: string,
  end: string,
  provisional: boolean,
): ExportPlan {
  const lines: { id: string; cells: ExportValue[] }[] = [];
  const blockers: string[] = [];
  const frequency = new Map<string, number>();
  let pending = 0,
    linked = 0;
  for (const a of visits
    .filter((v) => v.date >= start && v.date <= end)
    .sort(
      (a, b) => a.date.localeCompare(b.date) || a.time.localeCompare(b.time),
    )) {
    const frequencyKey = JSON.stringify([a.date, a.worker.dni]);
    const count = (frequency.get(frequencyKey) || 0) + 1;
    frequency.set(frequencyKey, count);
    for (const item of a.items.length ? a.items : [undefined]) {
      const events = movements.filter(
        (m) =>
          m.dispenseRef?.attentionId === a.id &&
          m.dispenseRef.itemId === item?.id,
      );
      if (item && events.length) linked++;
      if (item && !events.length) {
        pending++;
        if (!provisional)
          blockers.push("Consumo pendiente: " + a.id + " / " + item.id);
      }
      const tm = (s: string) =>
        s ? Number(s.slice(0, 2)) / 24 + Number(s.slice(3)) / 1440 : "";
      const p = item?.procedure || a.procedures.join(" / ");
      const r = item
        ? events.length
          ? events.reduce((s, m) => s + m.excelQuantity, 0)
          : provisional
            ? item.quantity
            : ""
        : "";
      lines.push({
        id: JSON.stringify([a.id, item?.id || null]),
        cells: [
          a.worker.site || "",
          a.worker.area,
          "",
          "",
          a.worker.labor,
          excelDate(a.date),
          tm(a.time),
          a.worker.dni,
          a.worker.name,
          a.worker.age ? Number(a.worker.age) : "",
          a.worker.sex,
          a.worker.ubigeo,
          a.category,
          a.system,
          a.segment,
          item?.code || "",
          item?.name || "",
          r,
          ["PRIMERA", "SEGUNDA", "TERCERA", "CUARTA", "QUINTA"][count - 1] ||
            "REVISAR",
          p,
          item ? procedureDetail(p) : "",
          a.permission,
          a.workStatus,
          tm(a.permissionTime),
          a.blueBandage ? "SI" : "NO",
          a.returned ? "SI" : "NO",
          a.photoSent ? "SI" : "NO",
          a.responsibleDni,
          a.responsible,
          a.diagnosis,
        ],
      });
    }
  }
  return {
    lines,
    blockers,
    warnings: ["Saldos e ingresos requieren conciliación independiente"],
    start,
    end,
    visits: visits.filter((v) => v.date >= start && v.date <= end).length,
    linkedDeliveries: linked,
    provisional: provisional && pending > 0,
    pendingDeliveries: pending,
    ...(provisional && pending > 0
      ? {
          unverifiedLineIds: lines
            .filter(
              (l) =>
                typeof l.cells[17] === "number" &&
                l.cells[17] > 0 &&
                !movements.some(
                  (m) =>
                    JSON.stringify([
                      m.dispenseRef?.attentionId,
                      m.dispenseRef?.itemId,
                    ]) === l.id,
                ),
            )
            .map((l) => l.id),
        }
      : {}),
  };
}
export function exportIndicator(plan: ExportPlan) {
  const bytes = Uint8Array.from(atob(template.zipBase64), (c) =>
    c.charCodeAt(0),
  );
  return exportAmbulatoryWorkbook(bytes, plan);
}
export function nursingReport(
  lots: Lot[],
  moves: Movement[],
  start: string,
  end: string,
) {
  return {
    date: start,
    periodEnd: end,
    rows: kardexCatalog.map((p) => {
      const related = lots.filter((l) => l.code === p.id);
      const periodMoves = moves.filter(
        (m) =>
          m.code === p.id && limaDay(m.at) >= start && limaDay(m.at) <= end,
      );
      const dated = related
        .map((l) => {
          const history = moves
            .filter((m) => m.lotId === l.id)
            .sort((a, b) => a.at - b.at);
          const initial = history[0]?.before || l;
          if (limaDay(initial.updatedAt) > end) return null;
          return history.find((m) => limaDay(m.at) > end)?.before || l;
        })
        .filter((l): l is Lot => !!l);
      const final = dated.reduce((s, l) => s + reportBalance(l), 0);
      const consumed = periodMoves
        .filter((m) => m.kind === "use")
        .reduce((s, m) => s + m.excelQuantity, 0);
      const extraordinary = periodMoves
        .filter((m) => m.kind === "extraordinary")
        .reduce(
          (s, m) =>
            s + (isContainer(m.unit) ? m.sealedAdded : m.physicalChange),
          0,
        );
      const adjusted = periodMoves
        .filter((m) => m.kind === "adjustment")
        .reduce(
          (s, m) => s + reportBalance(m.after) - reportBalance(m.before),
          0,
        );
      return {
        code: p.id,
        name: p.name,
        donated: false,
        stockKnown: dated.length > 0,
        initial: final + consumed - extraordinary - adjusted,
        extraordinary,
        total: final + consumed - adjusted,
        consumed,
        final,
        expiry:
          dated
            .map((l) => l.expires)
            .filter(Boolean)
            .sort()[0] || "",
        fs: null,
      };
    }),
    warnings: moves.some(
      (m) =>
        m.kind === "adjustment" &&
        limaDay(m.at) >= start &&
        limaDay(m.at) <= end,
    )
      ? ["Hay ajustes auditados en el período; concilia antes de exportar"]
      : [],
    exportable: !moves.some(
      (m) =>
        m.kind === "adjustment" &&
        limaDay(m.at) >= start &&
        limaDay(m.at) <= end,
    ),
  };
}
export async function exportNursing(
  report: ReturnType<typeof nursingReport>,
  responsible: string,
) {
  const response = await fetch("/internal/kardex-template.bin");
  if (!response.ok) throw Error("Plantilla oficial no disponible");
  return exportOfficialKardex(
    new Uint8Array(await response.arrayBuffer()),
    report,
    "CONSOLIDADO",
    responsible,
  );
}
export function download(name: string, bytes: Uint8Array | string) {
  const blob = new Blob(
    [typeof bytes === "string" ? bytes : new Uint8Array(bytes).buffer],
    {
      type:
        typeof bytes === "string"
          ? "application/json"
          : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    },
  );
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download =
    trialMode && !name.startsWith("FICTICIO_") ? "FICTICIO_" + name : name;
  a.click();
  notifySuccess(
    "El archivo " +
      a.download +
      " está preparado. Revisa las descargas de tu navegador.",
    "Archivo preparado",
  );
  setTimeout(() => URL.revokeObjectURL(url), 2000);
}
export function projectedConsumption(
  visits: Visit[],
  lots: Lot[],
  moves: Movement[],
  start: string,
  end: string,
) {
  return visits
    .filter((v) => v.date >= start && v.date <= end)
    .flatMap((v) =>
      v.items
        .filter(
          (i) =>
            !moves.some(
              (m) =>
                m.dispenseRef?.attentionId === v.id &&
                m.dispenseRef.itemId === i.id,
            ),
        )
        .map((i) => {
          const links = candidates(i);
          const code = links.length === 1 ? links[0].kardexCode : "";
          const unitProjection =
            !!code &&
            ["UND", "TBL", "PAR"].includes(i.unit) &&
            !["E-86", "E-94", "E-95"].includes(code) &&
            !lots.some((l) => l.code === code && isContainer(l.catalogUnit));
          return {
            visitId: v.id,
            itemId: i.id,
            code,
            clinicalQuantity: i.quantity,
            reportedUse: unitProjection ? i.quantity : null,
            physicalDebit: false,
          };
        }),
    );
}
