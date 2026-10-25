import { zipSync, strToU8 } from "fflate";
import native from "./generated/vigilance.json" with { type: "json" };
import { excelDate, validExportDate } from "../legacy/ambulatoryRows";
import { normalize, type Visit, type Worker } from "./model";
function escape(value: unknown) {
  return String(value ?? "")
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "")
    .slice(0, 32767)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}
function cell(
  column: string,
  row: number,
  value: unknown,
  style = 3,
  numeric = false,
) {
  return `<c r="${column}${row}" s="${style}"${numeric ? "" : ' t="inlineStr"'}>${numeric ? "<v>" + value + "</v>" : '<is><t xml:space="preserve">' + escape(value) + "</t></is>"}</c>`;
}
function organization(worker: Worker) {
  const site = normalize(worker.site || "");
  const fundo = [
    "LA VENTUROSA",
    "LA AVENTUROSA",
    "FUNDO LA VENTUROSA",
    "FUNDO LA AVENTUROSA",
    "VENTUROSA",
    "A071",
  ].includes(site);
  const plant = [
    "PLVENTUROSA",
    "PL VENTUROSA",
    "PLAVENTUROSA",
    "PL AVENTUROSA",
    "PLANTA LA VENTUROSA",
    "PLANTA LA AVENTUROSA",
    "PL LA VENTUROSA",
    "I031",
  ].includes(site);
  const society = fundo ? "1003" : plant ? "1001" : "";
  const matches = native.codes.filter(
    (c) =>
      c.society === society && normalize(c.area) === normalize(worker.area),
  );
  return {
    subdivision: fundo ? "A071" : plant ? "I031" : "",
    code: matches.length === 1 ? matches[0].code : "",
    recognized: !!society,
  };
}
export function exportVigilance(visits: Visit[], start: string, end: string) {
  if (!validExportDate(start) || !validExportDate(end) || start > end)
    throw Error("Fechas de vigilancia inválidas");
  const ids = new Set<string>();
  let skipped = 0,
    unresolved = 0;
  const selected = visits
    .filter((v) => {
      if (
        v.status !== "saved" ||
        normalize(v.system) !== "OSTEOMUSCULAR" ||
        v.date < start ||
        v.date > end
      )
        return false;
      if (!validExportDate(v.date) || !v.id || ids.has(v.id))
        throw Error("Atención inválida o duplicada");
      ids.add(v.id);
      if (!/^\d{8}$/.test(v.worker.dni) || !v.worker.name) {
        skipped++;
        return false;
      }
      return true;
    })
    .sort(
      (a, b) =>
        a.date.localeCompare(b.date) ||
        a.time.localeCompare(b.time) ||
        a.id.localeCompare(b.id),
    );
  if (selected.length > 20000)
    throw Error("Máximo 20 000 filas por exportación");
  const letters = "ABCDEFGHIJKLMNOPQ".split("");
  const header = letters
    .map((l, i) =>
      cell(l, 1, native.headers[i], ["C", "D"].includes(l) ? 2 : 1),
    )
    .join("");
  const body = selected
    .map((v, i) => {
      const row = i + 2,
        w = v.worker,
        code = organization(w);
      if (code.recognized && !code.code) unresolved++;
      let age = Number(w.age);
      if (w.birthDate && validExportDate(w.birthDate)) {
        const birth = new Date(w.birthDate + "T12:00:00Z"),
          at = new Date(v.date + "T12:00:00Z");
        age =
          at.getUTCFullYear() -
          birth.getUTCFullYear() -
          (at.getUTCMonth() < birth.getUTCMonth() ||
          (at.getUTCMonth() === birth.getUTCMonth() &&
            at.getUTCDate() < birth.getUTCDate())
            ? 1
            : 0);
      }
      const values = [
        w.site || "",
        w.area,
        code.subdivision,
        code.code,
        w.labor,
        (w as Worker & { planilla?: string }).planilla || "",
        excelDate(v.date),
        v.time,
        w.dni,
        w.name,
        Number.isInteger(age) && age >= 0 && age <= 120 ? age : "",
        w.sex,
        "DISERGONOMICO",
        "Posturas inadecuadas",
        "Capacitacion y ejecucion de pausas activas",
        v.responsibleDni,
        v.responsible,
      ];
      return (
        `<row r="${row}" spans="1:17" ht="18" customHeight="1">` +
        values
          .map((value, j) =>
            cell(
              letters[j],
              row,
              value,
              j === 6
                ? 5
                : [2, 3].includes(j)
                  ? 4
                  : [8, 15].includes(j)
                    ? 6
                    : 3,
              j === 6 || (j === 10 && typeof value === "number"),
            ),
          )
          .join("") +
        "</row>"
      );
    })
    .join("");
  const last = Math.max(2, selected.length + 1);
  const worksheet = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:Q${last}"/><sheetViews><sheetView showGridLines="0" zoomScale="73" workbookViewId="0"><selection activeCell="A2" sqref="A2"/></sheetView></sheetViews><sheetFormatPr defaultRowHeight="15"/><cols>${native.widths.map((width, i) => `<col min="${i + 1}" max="${i + 1}" width="${width}" customWidth="1"/>`).join("")}</cols><sheetData><row r="1" spans="1:17" ht="37.15" customHeight="1">${header}</row>${body}</sheetData><autoFilter ref="A1:Q${last}"/><pageMargins left="0.3" right="0.3" top="0.5" bottom="0.5" header="0.2" footer="0.2"/><pageSetup orientation="landscape" fitToWidth="1"/></worksheet>`;
  const parts = {
    "[Content_Types].xml": native.types,
    "_rels/.rels": native.relationships,
    "xl/workbook.xml": native.workbook,
    "xl/_rels/workbook.xml.rels": native.workbookRels,
    "xl/styles.xml": native.styles,
    "xl/worksheets/sheet1.xml": worksheet,
  };
  return {
    bytes: zipSync(
      Object.fromEntries(
        Object.entries(parts).map(([k, v]) => [k, strToU8(v)]),
      ),
      { level: 0 },
    ),
    rows: selected.length,
    skipped,
    unresolved,
  };
}
