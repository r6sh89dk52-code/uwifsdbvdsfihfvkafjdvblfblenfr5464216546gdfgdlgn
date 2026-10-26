import { notifySuccess, FieldError } from "./feedback";
import { clinician } from "./clinician";
import { trialMode, switchWorkspace } from "./workspace";
import { loadTrial } from "./trial";
import { exportDataSheet } from "./dataExport";
import { useState } from "react";
import {
  Section,
  Text,
  Check,
  Select,
  Empty,
  useRecords,
  useAction,
  atomic,
  changed,
} from "./main";
import { store, put } from "./storage";
import {
  cutPeriod,
  limaDay,
  normalize,
  type Worker,
  type Visit,
  type Lot,
  type Movement,
  type Collection,
  type Change,
} from "./model";
import {
  inspectWorkbook,
  parseDate,
  download,
  indicatorPlan,
  exportIndicator,
  nursingReport,
  exportNursing,
  projectedConsumption,
} from "./workbooks";
import {
  compileWorkers,
  reconcileWorkers,
  type ImportResult,
} from "../legacy/workerRules";
import {
  decryptPortableBackup,
  encryptPortableBackup,
} from "../legacy/portableBackup";
import { configured, syncStatus, synchronize } from "./sync";
import { exportVigilance } from "./vigilance";
export default function Tools({
  mode,
}: {
  mode: "reports" | "settings" | "workers";
}) {
  return mode === "workers" ? (
    <WorkerImport />
  ) : mode === "reports" ? (
    <Reports />
  ) : (
    <Settings />
  );
}
function WorkerImport() {
  const workers = useRecords<Worker>("workers");
  const [preview, setPreview] = useState<
      (ImportResult & { workers: Worker[] }) | null
    >(null),
    [confirmed, setConfirmed] = useState(false),
    [message, setMessage] = useState("");
  const action = useAction();
  const merged = preview ? reconcileWorkers(workers, preview.workers) : null;
  return (
    <Section title="Importar PERSONAL desde Excel">
      <p className="muted">
        Vista previa antes de incorporar. Conserva las atenciones y las
        correcciones manuales del padrón actual.
      </p>
      <input
        type="file"
        accept=".xlsx"
        aria-label="Importar PERSONAL"
        onChange={(e) =>
          void action.run(async () => {
            const f = e.target.files?.[0];
            if (!f) return;
            if (f.size > 20 * 1024 * 1024) throw Error("Archivo mayor a 20 MB");
            const sheets = inspectWorkbook(
              new Uint8Array(await f.arrayBuffer()),
            );
            const sheet = sheets.find((s) => normalize(s.name) === "PERSONAL");
            if (!sheet) throw Error("No existe la hoja PERSONAL");
            const first = sheet.rows[0];
            if (!first) throw Error("PERSONAL está vacía");
            const cols = Object.keys(first.values);
            const rows = sheet.rows.map((r) =>
              cols.map((c) => r.values[c] || ""),
            );
            const parsed = compileWorkers(rows);
            const header = Object.fromEntries(
              cols.map((c) => [normalize(first.values[c]), c]),
            );
            const byDni = new Map(
              sheet.rows.slice(1).map((r) => [r.values[header.DNI], r]),
            );
            const incoming = parsed.workers.map((w) => {
              const r = byDni.get(w.dni);
              const birth =
                header["FECHA DE NACIMIENTO"] ||
                header["FECHA NACIMIENTO"] ||
                header.NACIMIENTO;
              const site = header.SEDE || header.SUBDIVISION;
              return {
                ...w,
                ...(r && birth
                  ? { birthDate: parseDate(r.values[birth] || "") }
                  : {}),
                ...(r && site ? { site: r.values[site] || "" } : {}),
              };
            });
            setPreview({ ...parsed, workers: incoming });
            setConfirmed(false);
            setMessage("");
          })
        }
      />
      {preview && merged && (
        <>
          <div className="metrics">
            {Object.entries({
              Válidos: preview.stats.valid,
              Duplicados: preview.stats.duplicates,
              "Nombres discrepantes":
                preview.stats.nameConflicts + merged.stats.nameConflicts,
              Nuevos: merged.stats.added,
              Actualizados: merged.stats.merged,
            }).map(([s, n]) => (
              <div className="metric" key={s}>
                <span>{s}</span>
                <strong>{n}</strong>
              </div>
            ))}
          </div>
          <p>
            Descartados: {preview.stats.invalidDni} DNI inválidos y{" "}
            {preview.stats.withoutName} sin nombre. Correcciones manuales
            conservadas: {merged.stats.manualPreserved}.
          </p>
          <div className="preview">
            <table>
              <thead>
                <tr>
                  <th>DNI</th>
                  <th>Nombre recibido</th>
                  <th>Nombre conservado</th>
                  <th>Área</th>
                  <th>Labor</th>
                </tr>
              </thead>
              <tbody>
                {preview.workers.slice(0, 25).map((w) => (
                  <tr key={w.dni}>
                    <td>{w.dni}</td>
                    <td>{w.name}</td>
                    <td>{merged.workers.find((x) => x.dni === w.dni)?.name}</td>
                    <td>{w.area}</td>
                    <td>{w.labor}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          {preview.stats.nameConflicts + merged.stats.nameConflicts > 0 && (
            <p className="warning">
              Los nombres discrepantes no se sobrescribirán. Revisa después la
              ficha del DNI afectado.
            </p>
          )}
          <Check
            label="Revisé las discrepancias y confirmo incorporar el padrón"
            value={confirmed}
            onChange={setConfirmed}
          />
          <button
            disabled={!confirmed}
            onClick={() =>
              void action.run(async () => {
                const incoming = new Set(preview.workers.map((w) => w.dni));
                const changedWorkers = merged.workers.filter((w) =>
                  incoming.has(w.dni),
                );
                const birth = new Map(preview.workers.map((w) => [w.dni, w]));
                for (let i = 0; i < changedWorkers.length; i += 100) {
                  const changes: Change[] = [];
                  for (const w of changedWorkers.slice(i, i + 100)) {
                    const previous = workers.find((x) => x.dni === w.dni);
                    const extra = birth.get(w.dni) as Worker | undefined;
                    const data = {
                      ...extra,
                      ...w,
                      ...(previous?.source === "manual"
                        ? {
                            birthDate: previous.birthDate || extra?.birthDate,
                            site: previous.site || extra?.site,
                          }
                        : {
                            birthDate: extra?.birthDate || previous?.birthDate,
                            site: extra?.site || previous?.site,
                          }),
                    };
                    const clean = JSON.parse(JSON.stringify(data));
                    changes.push(await changed("workers", w.dni, clean));
                  }
                  await atomic(changes);
                }
                setMessage(
                  changedWorkers.length + " fichas incorporadas por DNI.",
                );
                setPreview(null);
              })
            }
          >
            Confirmar importación
          </button>
        </>
      )}
      {message && (
        <p role="status" className="success">
          {message}
        </p>
      )}
      {action.error && <p role="alert">{action.error}</p>}
    </Section>
  );
}
function Reports() {
  const visits = useRecords<Visit>("attentions"),
    lots = useRecords<Lot>("lots"),
    moves = useRecords<Movement>("movements"),
    corrections = useRecords<{
      attentionId: string;
      field: string;
      after: string;
      at: number;
    }>("corrections");
  const initial = cutPeriod(limaDay());
  const [start, setStart] = useState(initial.start),
    [end, setEnd] = useState(limaDay()),
    [provisional, setProvisional] = useState(true),
    [responsible, setResponsible] = useState(clinician.name);
  const action = useAction();
  const effective = visits.map((v) => {
    const result = { ...v };
    for (const c of corrections
      .filter((c) => c.attentionId === v.id)
      .sort((a, b) => a.at - b.at))
      if (["diagnosis", "system", "segment", "responsible"].includes(c.field))
        (result as unknown as Record<string, unknown>)[c.field] = c.after;
    return result;
  });
  const pending = projectedConsumption(effective, lots, moves, start, end);
  return (
    <>
      <Section title="Indicador Ambulatorio y Kardex oficiales">
        <div className="grid">
          <Text label="Desde" type="date" value={start} onChange={setStart} />
          <Text label="Hasta" type="date" value={end} onChange={setEnd} />
          <Text
            label="Responsable del Kardex"
            readOnly
            value={responsible}
            onChange={setResponsible}
          />
        </div>
        <button
          className="quiet"
          onClick={() => {
            const period = cutPeriod(end);
            setStart(period.start);
          }}
        >
          Usar corte mensual 9–8
        </button>
        <Check
          label="Indicador provisional con consumos clínicos pendientes identificados"
          value={provisional}
          onChange={setProvisional}
        />
        <div className="actions">
          <button
            onClick={() =>
              void action.run(async () => {
                if (!parseDate(start) || !parseDate(end) || start > end)
                  throw Error("Período inválido");
                const plan = indicatorPlan(
                  effective,
                  moves,
                  start,
                  end,
                  provisional,
                );
                download(
                  "DANPER_INDICADOR_" +
                    (plan.provisional ? "PROVISIONAL_" : "") +
                    end +
                    ".xlsx",
                  exportIndicator(plan),
                );
              })
            }
          >
            Exportar Indicador (10 hojas)
          </button>
          <button
            onClick={() =>
              void action.run(async () => {
                if (!parseDate(start) || !parseDate(end) || start > end)
                  throw Error("Período inválido");
                download(
                  "DANPER_KARDEX_" + end + ".xlsx",
                  await exportNursing(
                    nursingReport(lots, moves, start, end),
                    responsible,
                  ),
                );
              })
            }
          >
            Exportar Kardex (98 productos)
          </button>
          <button
            onClick={() =>
              void action.run(async () => {
                const report = exportVigilance(effective, start, end);
                download(
                  "DANPER_VIGILANCIA_OSTEOMUSCULAR_" + end + ".xlsx",
                  report.bytes,
                );
              })
            }
          >
            Exportar vigilancia osteomuscular
          </button>
        </div>
        <p className="muted">
          Se utilizan los recursos oficiales incluidos en el repositorio. Los
          saldos del indicador requieren conciliación; un consumo proyectado no
          modifica el stock físico.
        </p>
        {action.error && <p role="alert">{action.error}</p>}
      </Section>
      <Section title="Consumos históricos y pendientes de conciliación">
        <p className="muted">
          {pending.length} líneas sin movimiento físico confirmado. La
          reconstrucción del corte no vuelve a descontar el inventario actual.
        </p>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Atención</th>
                <th>Producto Kardex</th>
                <th>Cantidad clínica</th>
                <th>R proyectado</th>
                <th>Stock físico</th>
              </tr>
            </thead>
            <tbody>
              {pending.slice(0, 100).map((p) => (
                <tr key={p.visitId + p.itemId}>
                  <td>{p.visitId.slice(0, 8)}</td>
                  <td>{p.code || "Sin correspondencia única"}</td>
                  <td>{p.clinicalQuantity}</td>
                  <td>{p.reportedUse ?? "Apertura desconocida"}</td>
                  <td>Sin descuento</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!pending.length && (
          <Empty>No hay consumos pendientes en el período.</Empty>
        )}
      </Section>
    </>
  );
}
type Migration = {
  counts: Record<string, number>;
  snapshot: Record<string, unknown>;
  errors: string[];
  changes: { collection: Collection; id: string; data: unknown }[];
};
export function inspectMigration(raw: unknown): Migration {
  if (!raw || typeof raw !== "object" || Array.isArray(raw))
    throw Error("Respaldo sin fuente válida");
  const s = raw as Record<string, unknown>;
  const errors: string[] = [];
  const changes: Migration["changes"] = [];
  const counts: Record<string, number> = {};
  const aliases: {
    source: string;
    collection: Collection;
    identity: string;
  }[] = [
    { source: "workers", collection: "workers", identity: "dni" },
    { source: "allergies", collection: "allergies", identity: "dni" },
    { source: "attentions", collection: "attentions", identity: "id" },
    { source: "stockLots", collection: "lots", identity: "id" },
    { source: "stockMovements", collection: "movements", identity: "id" },
    { source: "lots", collection: "lots", identity: "id" },
    { source: "movements", collection: "movements", identity: "id" },
    { source: "emo", collection: "emo", identity: "id" },
    { source: "cholinesterase", collection: "cholinesterase", identity: "id" },
    { source: "leaves", collection: "leaves", identity: "id" },
    { source: "corrections", collection: "corrections", identity: "id" },
    { source: "mappings", collection: "mappings", identity: "id" },
    {
      source: "reconciliations",
      collection: "reconciliations",
      identity: "id",
    },
  ];
  const seen = new Set<string>();
  for (const a of aliases) {
    const source = s[a.source];
    if (source === undefined) continue;
    if (!Array.isArray(source)) {
      errors.push(a.source + ": se esperaba una colección de registros");
      continue;
    }
    counts[a.source] = source.length;
    for (const r of source) {
      if (!r || typeof r !== "object") {
        errors.push(a.source + ": registro inválido");
        continue;
      }
      const data = r as Record<string, unknown>;
      const id = data[a.identity];
      if (typeof id !== "string" || !id || id.includes("/")) {
        errors.push(a.source + ": identificador inválido");
        continue;
      }
      const key = a.collection + ":" + id;
      if (seen.has(key)) {
        errors.push("Duplicado: " + a.collection);
        continue;
      }
      seen.add(key);
      if (a.collection === "workers" && !/^\d{8}$/.test(id))
        errors.push("DNI inválido");
      changes.push({ collection: a.collection, id, data });
    }
  }
  if (!counts.workers || !Array.isArray(s.attentions))
    errors.push("Faltan trabajadores o atenciones de la fuente nativa");
  const dnis = new Set(
    changes.filter((c) => c.collection === "workers").map((c) => c.id),
  );
  const lots = new Set(
    changes.filter((c) => c.collection === "lots").map((c) => c.id),
  );
  const visits = new Map(
    changes
      .filter((c) => c.collection === "attentions")
      .map((c) => [c.id, c.data as Visit]),
  );
  for (const c of changes) {
    const d = c.data as Record<string, unknown>;
    if (c.collection === "attentions") {
      const v = c.data as Visit;
      if (!dnis.has(v.worker?.dni) || !Array.isArray(v.items))
        errors.push("Atención con referencias incompletas");
      else {
        const ids = new Set<string>();
        for (const item of v.items) {
          if (!item.id || ids.has(item.id))
            errors.push("Ítem duplicado o sin ID");
          ids.add(item.id);
        }
      }
    }
    if (c.collection === "movements") {
      const m = c.data as Movement;
      if (!lots.has(m.lotId) || !m.before || !m.after)
        errors.push("Movimiento con lote o estados incompletos");
      if (m.dispenseRef) {
        const v = visits.get(m.dispenseRef.attentionId);
        if (!v?.items.some((i) => i.id === m.dispenseRef!.itemId))
          errors.push("Movimiento sin referencia clínica válida");
      }
    }
  }
  return { counts, snapshot: s, errors: [...new Set(errors)], changes };
}
function Settings() {
  const [pass, setPass] = useState(""),
    [preview, setPreview] = useState<Migration | null>(null),
    [confirm, setConfirm] = useState(false),
    [queue, setQueue] = useState<Awaited<ReturnType<typeof store.queue>>>([]),
    [message, setMessage] = useState("");
  const action = useAction();
  return (
    <>
      <Section title="Prueba con datos ficticios">
        <p>
          Explora el historial, registra atenciones y prueba las exportaciones
          con tres trabajadores, dos atenciones y un lote ficticios. Se guardan
          en un espacio separado de tus registros y nunca se envían a Firebase.
        </p>
        <div className="actions">
          <button
            onClick={() =>
              void action.run(async () => {
                await loadTrial();
                switchWorkspace(true);
              })
            }
          >
            {trialMode
              ? "Continuar prueba local"
              : "Probar con datos ficticios"}
          </button>
          {trialMode && (
            <button
              className="quiet"
              onClick={() => {
                download(
                  "PERSONAL_FICTICIO_PARA_IMPORTAR.xlsx",
                  exportDataSheet(
                    "PERSONAL",
                    [
                      "DNI",
                      "NOMBRES",
                      "AREA",
                      "LABOR",
                      "SEXO",
                      "FECHA NACIMIENTO",
                      "SEDE",
                    ],
                    ["00000004", "00000005"].map((dni, i) => [
                      dni,
                      "PERSONA IMPORTADA FICTICIA " + (i + 1),
                      "PRODUCCION",
                      "PUESTO FICTICIO",
                      i ? "M" : "F",
                      "1996-01-01",
                      i ? "PLVENTUROSA" : "LA VENTUROSA",
                    ]),
                  ),
                );
              }}
            >
              Descargar PERSONAL ficticio
            </button>
          )}
        </div>
        {trialMode && (
          <p className="muted">
            Para probar la importación, descarga PERSONAL ficticio y cárgalo
            desde Trabajadores → Importar PERSONAL. Puedes volver a tus
            registros desde el aviso superior; tus pruebas quedan conservadas.
          </p>
        )}
      </Section>
      <Section title="Fuente compartida y sincronización">
        <p>
          {configured
            ? syncStatus.message
            : "No hay proyecto Firebase configurado. Los registros se guardan en este navegador."}
        </p>
        <button
          className="quiet"
          onClick={() =>
            void action.run(async () => {
              await synchronize();
              setQueue(await store.queue());
            })
          }
        >
          Revisar cola de operaciones
        </button>
        {queue.map((op) => (
          <div className="inset" key={op.id}>
            <strong>
              {op.state === "conflict" ? "Requiere conciliación" : "Pendiente"}
            </strong>
            <p>
              {op.changes.length} cambios · {op.id}
            </p>
            <small>{op.error || "Reintento idempotente conservado"}</small>
            {op.state === "conflict" && (
              <button
                className="quiet"
                onClick={() =>
                  download(
                    "DANPER_CONFLICTO_" + op.id + ".json",
                    JSON.stringify(op, null, 2),
                  )
                }
              >
                Exportar conflicto para revisión
              </button>
            )}
          </div>
        ))}
        <p className="muted">
          Los conflictos detienen los cambios dependientes y conservan los datos
          locales. El adaptador nativo permanece desactivado hasta validar
          migración y pruebas en iPhone.
        </p>
      </Section>
      <Section title="Respaldo cifrado y migración local">
        <Text
          label="Contraseña del respaldo (no se almacena)"
          type="password"
          value={pass}
          onChange={setPass}
        />
        <button
          onClick={() =>
            void action.run(async () => {
              download(
                "DANPER_RESPALDO_CIFRADO.json",
                await encryptPortableBackup(await store.snapshot(), pass),
              );
              setMessage("Respaldo cifrado generado localmente.");
            })
          }
        >
          Exportar respaldo cifrado
        </button>
        <p className="muted">
          Importa un respaldo portátil cifrado autorizado. Primero se descifra y
          valida en este dispositivo; no modifica la bóveda del iPhone.
        </p>
        <input
          type="file"
          accept=".json,.danper"
          aria-label="Respaldo cifrado"
          onChange={(e) =>
            void action.run(async () => {
              const file = e.target.files?.[0];
              if (!file) return;
              if (file.size > 42 * 1024 * 1024)
                throw Error("Respaldo mayor a 42 MB");
              const raw = await decryptPortableBackup(await file.text(), pass);
              const result = inspectMigration(raw);
              await store.setMeta("migrationStaging", result.snapshot);
              setPreview(result);
              setConfirm(false);
              if(result.errors.length)throw new FieldError(result.errors.join("\n"), ["Respaldo cifrado"]);
            })
          }
        />
        {preview && (
          <>
            <div className="grid">
              {Object.entries(preview.counts).map(([k, n]) => (
                <p key={k}>
                  {k}: <strong>{n}</strong>
                </p>
              ))}
            </div>
            {preview.errors.map((e) => (
              <p className="error" key={e}>
                {e}
              </p>
            ))}
            <p className="warning">
              La validación de referencias no acredita paridad completa del
              respaldo nativo. La importación se conserva en staging hasta
              verificar el contrato completo; las escrituras cloud de migración
              están desactivadas.
            </p>
            <Check
              label="Confirmo guardar únicamente el staging local para revisión"
              value={confirm}
              onChange={setConfirm}
            />
            <button
              disabled={!confirm || preview.errors.length > 0}
              onClick={() =>
                void action.run(async () => {
                  await store.setMeta("migrationReviewedAt", Date.now());
                  notifySuccess(
                    "Staging local revisado. No se crearon ni sobrescribieron datos cloud.",
                  );
                  setMessage(
                    "Staging local revisado. No se crearon ni sobrescribieron datos cloud.",
                  );
                })
              }
            >
              Conservar staging revisado
            </button>
          </>
        )}
        {message && (
          <p role="status" className="success">
            {message}
          </p>
        )}
        {action.error && <p role="alert">{action.error}</p>}
      </Section>
    </>
  );
}
