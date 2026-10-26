import { FieldError } from "./feedback";
import { useMemo, useState } from "react";
import {
  useRecords,
  Section,
  Text,
  Select,
  Check,
  Empty,
  Field,
  useAction,
  atomic,
  changed,
} from "./main";
import { store, put } from "./storage";
import { exportDataSheet } from "./dataExport";
import {
  limaDay,
  normalize,
  type Exam,
  type Worker,
  type Leave,
} from "./model";
import {
  inspectWorkbook,
  previewExams,
  patchTemplateDates,
  download,
  parseDate,
  type Sheet,
  type ExamMapping,
} from "./workbooks";
const blankMapping: ExamMapping = {
  dni: "",
  name: "",
  date: "",
  result: "",
  type: "",
  profile: "",
  area: "",
  labor: "",
  nextDate: "",
  campaign: "",
};
export default function Occupational({
  kind,
}: {
  kind: "emo" | "cholinesterase" | "leaves";
}) {
  return kind === "leaves" ? <Leaves /> : <Exams key={kind} kind={kind} />;
}
function Exams({ kind }: { kind: "emo" | "cholinesterase" }) {
  const exams = useRecords<Exam>(kind),
    workers = useRecords<Worker>("workers");
  const [q, setQ] = useState(""),
    [page, setPage] = useState(0),
    [filter, setFilter] = useState("Todos"),
    [site, setSite] = useState(""),
    [area, setArea] = useState(""),
    [from, setFrom] = useState(""),
    [through, setThrough] = useState(""),
    [sheets, setSheets] = useState<Sheet[]>([]),
    [sheetName, setSheetName] = useState(""),
    [header, setHeader] = useState("1"),
    [importMode, setImportMode] = useState<"results" | "campaign">("results"),
    [mapping, setMapping] = useState<ExamMapping>(blankMapping),
    [preview, setPreview] = useState<Awaited<
      ReturnType<typeof previewExams>
    > | null>(null),
    [edit, setEdit] = useState<Exam | null>(null),
    [message, setMessage] = useState("");
  const action = useAction();
  const roster = useMemo(
    () => new Map(workers.map((w) => [w.dni, w])),
    [workers],
  );
  const matches = exams
    .filter((e) => {
      const w = roster.get(e.dni);
      return (
        normalize(
          e.dni + " " + (w?.name || e.name) + " " + e.campaign,
        ).includes(normalize(q)) &&
        (!site || w?.site === site) &&
        (!area || normalize(w?.area || e.area).includes(normalize(area))) &&
        (!from || e.date >= from) &&
        (!through || e.date <= through) &&
        (filter === "Todos" ||
          (filter === "No presentes" && !w) ||
          (filter === "Pendientes" && e.selected && !e.verified) ||
          (filter === "Discrepancias" &&
            !!w &&
            ((e.name && normalize(w.name) !== normalize(e.name)) ||
              (e.area && normalize(w.area) !== normalize(e.area)) ||
              (e.labor && normalize(w.labor) !== normalize(e.labor)))))
      );
    })
    .sort((a, b) => b.date.localeCompare(a.date));
  return (
    <>
      <div className="notice">
        {kind === "emo"
          ? "La fecha próxima se importa o programa expresamente. No se aplica periodicidad anual por el título de operador."
          : "Los resultados se acreditan únicamente cuando el tipo o perfil indica colinesterasa. La selección de campaña es manual."}
      </div>
      <Section
        title={
          kind === "emo"
            ? "Exámenes Médicos Ocupacionales"
            : "Vigilancia de colinesterasa"
        }
      >
        <div className="grid">
          <Text
            label="Buscar DNI / nombre / campaña"
            value={q}
            onChange={(v) => {
              setQ(v);
              setPage(0);
            }}
          />
          <Select
            label="Estado"
            value={filter}
            options={["Todos", "Pendientes", "No presentes", "Discrepancias"]}
            empty={false}
            onChange={(v) => {
              setFilter(v);
              setPage(0);
            }}
          />
          <Select
            label="Sede"
            value={site}
            options={["LA VENTUROSA", "PLVENTUROSA"]}
            onChange={setSite}
          />
          <Text label="Área" value={area} onChange={setArea} />
          <Text label="Desde" type="date" value={from} onChange={setFrom} />
          <Text
            label="Hasta"
            type="date"
            value={through}
            onChange={setThrough}
          />
        </div>
        <div className="toolbar">
          <span className="muted">
            {matches.length} registros · {new Set(exams.map((e) => e.dni)).size}{" "}
            trabajadores vinculados
          </span>
          <button
            className="quiet"
            onClick={() =>
              download(
                "DANPER_" + kind + "_DATOS.xlsx",
                exportDataSheet(
                  kind === "emo" ? "DATOS EMO" : "DATOS COLINESTERASA",
                  [
                    "DNI",
                    "NOMBRE ACTUAL",
                    "NOMBRE ORIGEN",
                    "FECHA",
                    "RESULTADO ORIGINAL",
                    "TIPO",
                    "PERFIL",
                    "AREA ACTUAL",
                    "LABOR ACTUAL",
                    "PROGRAMACION",
                    "CAMPAÑA",
                    "VERIFICADO",
                  ],
                  matches.map((e) => {
                    const w = roster.get(e.dni);
                    return [
                      e.dni,
                      w?.name || "",
                      e.name,
                      e.date,
                      e.result,
                      e.type,
                      e.profile,
                      w?.area || e.area,
                      w?.labor || e.labor,
                      e.nextDate,
                      e.campaign,
                      e.verified,
                    ];
                  }),
                ),
              )
            }
          >
            Exportar datos a Excel
          </button>
          <button
            onClick={() =>
              setEdit({
                id: crypto.randomUUID(),
                dni: "",
                name: "",
                date: "",
                result: "PENDIENTE",
                type: kind === "cholinesterase" ? "COLINESTERASA" : "EMO",
                profile: "",
                area: "",
                labor: "",
                nextDate: "",
                campaign: "",
                selected: true,
                source: "manual",
                verified: false,
              })
            }
          >
            ＋ Programar examen
          </button>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>DNI / trabajador actual</th>
                <th>Fecha / resultado</th>
                <th>Programación</th>
                <th>Campaña</th>
                <th>Revisión</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {matches.slice(page * 25, page * 25 + 25).map((e) => {
                const w = roster.get(e.dni);
                return (
                  <tr key={e.id}>
                    <td>
                      {e.dni}
                      <strong style={{ display: "block" }}>
                        {w?.name || e.name || "Sin padrón vigente"}
                      </strong>
                      <small>
                        {w?.area || e.area} · {w?.labor || e.labor}
                      </small>
                    </td>
                    <td>
                      {e.date || "Sin resultado"}
                      <small>{e.result}</small>
                    </td>
                    <td>{e.nextDate || "Sin programar"}</td>
                    <td>{e.campaign}</td>
                    <td>
                      {!w
                        ? "No presente"
                        : e.name && normalize(e.name) !== normalize(w.name)
                          ? "Nombre discrepante"
                          : e.area && normalize(e.area) !== normalize(w.area)
                            ? "Cambio de área"
                            : e.labor &&
                                normalize(e.labor) !== normalize(w.labor)
                              ? "Cambio de puesto"
                              : e.verified
                                ? "Resultado verificado"
                                : "Pendiente"}
                    </td>
                    <td>
                      <button className="quiet" onClick={() => setEdit(e)}>
                        Historial / editar
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
        {!matches.length && (
          <Empty>No hay resultados para estos filtros.</Empty>
        )}
        <div className="pagination">
          <button disabled={!page} onClick={() => setPage(page - 1)}>
            Anterior
          </button>
          <span>{page + 1}</span>
          <button
            disabled={(page + 1) * 25 >= matches.length}
            onClick={() => setPage(page + 1)}
          >
            Siguiente
          </button>
        </div>
      </Section>
      {edit && (
        <Section title="Resultado, programación e historial">
          <div className="grid">
            <Text
              label="DNI"
              value={edit.dni}
              onChange={(v) => setEdit({ ...edit, dni: v })}
            />
            <Text
              label="Fecha de examen"
              type="date"
              value={edit.date}
              onChange={(v) => setEdit({ ...edit, date: v })}
            />
            <Text
              label="Resultado / aptitud original"
              value={edit.result}
              onChange={(v) => setEdit({ ...edit, result: v })}
            />
            <Text
              label="Tipo de examen"
              value={edit.type}
              onChange={(v) => setEdit({ ...edit, type: v })}
            />
            <Text
              label="Perfil"
              value={edit.profile}
              onChange={(v) => setEdit({ ...edit, profile: v })}
            />
            <Text
              label="Próximo examen (selección manual)"
              type="date"
              value={edit.nextDate}
              onChange={(v) => setEdit({ ...edit, nextDate: v })}
            />
            <Text
              label="Campaña"
              value={edit.campaign}
              onChange={(v) => setEdit({ ...edit, campaign: v })}
            />
          </div>
          <Check
            label="Seleccionado para la campaña"
            value={edit.selected}
            onChange={(v) => setEdit({ ...edit, selected: v })}
          />
          <Check
            label="Verifiqué el resultado original"
            value={edit.verified}
            onChange={(v) => setEdit({ ...edit, verified: v })}
          />
          <div className="actions">
            <button className="quiet" onClick={() => setEdit(null)}>
              Cancelar
            </button>
            <button
              onClick={() =>
                void action.run(async () => {
                  if (!/^\d{8}$/.test(edit.dni))
                    throw new FieldError(
                      "Introduce un DNI válido de 8 dígitos.",
                      ["DNI"],
                    );
                  if (
                    edit.verified &&
                    (!parseDate(edit.date) || !edit.result.trim())
                  )
                    throw new FieldError(
                      "Verifica la fecha y el resultado original.",
                      [
                        !parseDate(edit.date)
                          ? "Fecha de examen"
                          : "Resultado / aptitud original",
                      ],
                    );
                  if (edit.nextDate && !parseDate(edit.nextDate))
                    throw new FieldError("Verifica la fecha de programación.", [
                      "Próximo examen (selección manual)",
                    ]);
                  if (
                    edit.verified &&
                    kind === "cholinesterase" &&
                    !/COLINESTERAS[AE]/.test(
                      normalize(edit.type + " " + edit.profile),
                    )
                  )
                    throw new FieldError(
                      "El tipo o perfil no acredita colinesterasa.",
                      ["Tipo de examen", "Perfil"],
                    );
                  const w = roster.get(edit.dni);
                  await put(kind, edit.id, {
                    ...edit,
                    name: edit.name || w?.name || "",
                    area: edit.area || w?.area || "",
                    labor: edit.labor || w?.labor || "",
                  });
                  setEdit(null);
                })
              }
            >
              Guardar revisión
            </button>
          </div>
          <h3>Historial individual por DNI</h3>
          {exams
            .filter((e) => e.dni === edit.dni)
            .sort((a, b) => b.date.localeCompare(a.date))
            .map((e) => (
              <p key={e.id}>
                {e.date || "Programación"} · {e.result} · {e.type} · {e.profile}
              </p>
            ))}
        </Section>
      )}
      <Section title="Importar base o resultados originales">
        <Select
          label="Contenido a importar"
          value={importMode}
          options={["results", "campaign"]}
          empty={false}
          onChange={(v) => {
            setImportMode(v as "results" | "campaign");
            setPreview(null);
          }}
        />
        <p className="muted">
          Lectura local. Revisa la hoja y el mapeo de columnas antes de
          incorporar resultados.
        </p>
        <input
          type="file"
          accept=".xlsx"
          aria-label="Importar exámenes"
          onChange={(e) =>
            void action.run(async () => {
              const f = e.target.files?.[0];
              if (!f) return;
              if (f.size > 20 * 1024 * 1024) throw Error("Límite de 20 MB");
              const rows = inspectWorkbook(
                new Uint8Array(await f.arrayBuffer()),
              );
              setSheets(rows);
              setSheetName(rows[0]?.name || "");
              setPreview(null);
              setMapping(blankMapping);
            })
          }
        />
        {sheets.length > 0 && (
          <>
            <div className="grid">
              <Select
                label="Hoja de origen"
                value={sheetName}
                options={sheets.map((s) => s.name)}
                empty={false}
                onChange={(v) => {
                  setSheetName(v);
                  setPreview(null);
                }}
              />
              <Text
                label="Fila de encabezados"
                type="number"
                value={header}
                onChange={(v) => {
                  setHeader(v);
                  setPreview(null);
                }}
              />
            </div>
            <div className="grid">
              {(Object.keys(mapping) as (keyof ExamMapping)[]).map((k) => (
                <Field label={k} key={k}>
                  <select
                    value={mapping[k]}
                    onChange={(e) => {
                      setMapping({ ...mapping, [k]: e.target.value });
                      setPreview(null);
                    }}
                  >
                    <option value="">No mapear</option>
                    {Object.entries(
                      sheets
                        .find((s) => s.name === sheetName)
                        ?.rows.find((r) => r.row === Number(header))?.values ||
                        {},
                    ).map(([col, name]) => (
                      <option value={col} key={col}>
                        {col} · {name}
                      </option>
                    ))}
                  </select>
                </Field>
              ))}
            </div>
            <button
              onClick={() =>
                void action.run(async () =>
                  setPreview(
                    await previewExams(
                      sheets.find((s) => s.name === sheetName)!,
                      mapping,
                      workers,
                      kind,
                      Number(header),
                      importMode,
                    ),
                  ),
                )
              }
            >
              Validar y previsualizar
            </button>
          </>
        )}
        {preview && (
          <>
            <p>
              {preview.exams.length} resultados válidos ·{" "}
              {preview.issues.length} observaciones
            </p>
            <div className="preview">
              {preview.issues.map((i, n) => (
                <p className="warning" key={n}>
                  Fila {i.row}: {i.reason}
                </p>
              ))}
              <table>
                <thead>
                  <tr>
                    <th>DNI</th>
                    <th>Fecha</th>
                    <th>Resultado</th>
                  </tr>
                </thead>
                <tbody>
                  {preview.exams.slice(0, 25).map((e) => (
                    <tr key={e.id}>
                      <td>{e.dni}</td>
                      <td>{e.date}</td>
                      <td>{e.result}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <button
              onClick={() =>
                void action.run(async () => {
                  let added = 0;
                  for (let i = 0; i < preview.exams.length; i += 100) {
                    const changes = [];
                    for (const e of preview.exams.slice(i, i + 100)) {
                      if (!(await store.get(kind, e.id))) {
                        changes.push(await changed(kind, e.id, e));
                        added++;
                      }
                    }
                    if (changes.length) await atomic(changes);
                  }
                  setMessage(
                    added +
                      " resultados incorporados. Los duplicados se omitieron.",
                  );
                  setPreview(null);
                })
              }
            >
              Confirmar importación revisada
            </button>
          </>
        )}
      </Section>
      <TemplateExport kind={kind} exams={matches} />
      {message && (
        <p role="status" className="success">
          {message}
        </p>
      )}
      {action.error && (
        <p role="alert" className="error">
          {action.error}
        </p>
      )}
    </>
  );
}
function TemplateExport({ kind, exams }: { kind: string; exams: Exam[] }) {
  const [bytes, setBytes] = useState<Uint8Array | null>(null),
    [sheets, setSheets] = useState<Sheet[]>([]),
    [name, setName] = useState(""),
    [dniCol, setDniCol] = useState(""),
    [dateCol, setDateCol] = useState(""),
    [confirmed, setConfirmed] = useState(false);
  const action = useAction();
  const sheet = sheets.find((s) => s.name === name);
  const dates: Record<string, string> = {};
  if (sheet && dniCol && dateCol)
    for (const row of sheet.rows) {
      const dni = row.values[dniCol]?.trim();
      if (!/^\d{8}$/.test(dni || "")) continue;
      const last = exams
        .filter((e) => e.dni === dni && e.verified && e.date)
        .sort((a, b) => b.date.localeCompare(a.date))[0];
      if (last) dates[dateCol + row.row] = last.date;
    }
  return (
    <Section title="Actualizar plantilla Excel original">
      <p className="muted">
        Conserva hojas, estilos, fórmulas y dibujos. Actualiza únicamente las
        fechas que revises; no reemplaza la plantilla oficial por un reporte
        genérico.
      </p>
      <input
        type="file"
        accept=".xlsx"
        aria-label="Plantilla oficial de exámenes"
        onChange={(e) =>
          void action.run(async () => {
            const f = e.target.files?.[0];
            if (!f) return;
            if (f.size > 20 * 1024 * 1024)
              throw Error("Plantilla mayor a 20 MB");
            const b = new Uint8Array(await f.arrayBuffer());
            setSheets(inspectWorkbook(b));
            setBytes(b);
            setName("");
            setConfirmed(false);
          })
        }
      />
      {bytes && (
        <>
          <div className="grid">
            <Select
              label="Hoja de destino"
              value={name}
              options={sheets.map((s) => s.name)}
              onChange={(v) => {
                setName(v);
                setConfirmed(false);
              }}
            />
            <Text
              label="Columna DNI (letra)"
              value={dniCol}
              onChange={(v) => {
                setDniCol(v.toUpperCase());
                setConfirmed(false);
              }}
            />
            <Text
              label="Columna de fecha autorizada (letra)"
              value={dateCol}
              onChange={(v) => {
                setDateCol(v.toUpperCase());
                setConfirmed(false);
              }}
            />
          </div>
          <div className="preview">
            {Object.entries(dates).map(([ref, date]) => (
              <p key={ref}>
                {ref}: {date}
              </p>
            ))}
          </div>
          <Check
            label={
              "Revisé las " +
              Object.keys(dates).length +
              " celdas que se actualizarán"
            }
            value={confirmed}
            onChange={setConfirmed}
          />
          <button
            disabled={!confirmed || !Object.keys(dates).length}
            onClick={() =>
              void action.run(async () =>
                download(
                  "DANPER_" + kind + "_PLANTILLA_REVISADA.xlsx",
                  patchTemplateDates(bytes, sheet!.part, dates),
                ),
              )
            }
          >
            Exportar conservando el modelo
          </button>
        </>
      )}
      {action.error && <p role="alert">{action.error}</p>}
    </Section>
  );
}
function Leaves() {
  const leaves = useRecords<Leave>("leaves"),
    workers = useRecords<Worker>("workers");
  const [edit, setEdit] = useState<Leave>({
      id: crypto.randomUUID(),
      dni: "",
      start: limaDay(),
      end: limaDay(),
      diagnosis: "",
      document: "",
      followUp: "",
    }),
    [q, setQ] = useState("");
  const action = useAction();
  const returnDay = (d: string) =>
    limaDay(Date.parse(d + "T12:00:00-05:00") + 86400000);
  return (
    <>
      <Section title="Registrar descanso médico">
        <div className="grid">
          <Text
            label="DNI del trabajador"
            value={edit.dni}
            onChange={(v) => setEdit({ ...edit, dni: v })}
          />
          <Text
            label="Fecha de inicio"
            type="date"
            value={edit.start}
            onChange={(v) => setEdit({ ...edit, start: v })}
          />
          <Text
            label="Fecha de término"
            type="date"
            value={edit.end}
            onChange={(v) => setEdit({ ...edit, end: v })}
          />
          <Text
            label="Diagnóstico"
            value={edit.diagnosis}
            onChange={(v) => setEdit({ ...edit, diagnosis: v })}
          />
          <Text
            label="Documento / referencia"
            value={edit.document}
            onChange={(v) => setEdit({ ...edit, document: v })}
          />
          <Text
            label="Seguimiento"
            value={edit.followUp}
            onChange={(v) => setEdit({ ...edit, followUp: v })}
          />
        </div>
        <button
          onClick={() =>
            void action.run(async () => {
              if (!workers.some((w) => w.dni === edit.dni))
                throw new FieldError("Selecciona un trabajador del padrón.", [
                  "DNI del trabajador",
                ]);
              if (!parseDate(edit.start))
                throw new FieldError(
                  "Revisa la fecha de inicio del descanso.",
                  ["Fecha de inicio"],
                );
              if (!parseDate(edit.end) || edit.end < edit.start)
                throw new FieldError(
                  "La fecha de término debe ser válida e igual o posterior al inicio.",
                  ["Fecha de término"],
                );
              await put("leaves", edit.id, edit);
              setEdit({
                ...edit,
                id: crypto.randomUUID(),
                dni: "",
                diagnosis: "",
                document: "",
                followUp: "",
              });
            })
          }
        >
          Guardar descanso
        </button>
        <p className="muted">
          La revisión asistida de documentos queda preparada como entrada manual
          verificada. No hay servicio de IA ni extracción automática activados.
        </p>
      </Section>
      <Section title="Seguimiento y reincorporación">
        <button
          className="quiet"
          onClick={() =>
            download(
              "DANPER_DESCANSOS_DATOS.xlsx",
              exportDataSheet(
                "DESCANSOS",
                [
                  "DNI",
                  "NOMBRES",
                  "INICIO",
                  "TERMINO",
                  "DIAS",
                  "REINCORPORACION PREVISTA",
                  "DIAGNOSTICO",
                  "DOCUMENTO",
                  "SEGUIMIENTO",
                ],
                leaves
                  .filter((l) => l.dni.includes(q))
                  .map((l) => [
                    l.dni,
                    workers.find((w) => w.dni === l.dni)?.name || "",
                    l.start,
                    l.end,
                    Math.round(
                      (Date.parse(l.end) - Date.parse(l.start)) / 86400000,
                    ) + 1,
                    returnDay(l.end),
                    l.diagnosis,
                    l.document,
                    l.followUp,
                  ]),
              ),
            )
          }
        >
          Exportar datos de descansos a Excel
        </button>
        <Text label="Buscar por DNI" value={q} onChange={setQ} />
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Trabajador</th>
                <th>Inicio / fin</th>
                <th>Días</th>
                <th>Reincorporación prevista</th>
                <th>Seguimiento</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {leaves
                .filter((l) => l.dni.includes(q))
                .map((l) => (
                  <tr key={l.id}>
                    <td>
                      {workers.find((w) => w.dni === l.dni)?.name || l.dni}
                      <small>{l.dni}</small>
                    </td>
                    <td>
                      {l.start} / {l.end}
                    </td>
                    <td>
                      {Math.round(
                        (Date.parse(l.end) - Date.parse(l.start)) / 86400000,
                      ) + 1}
                    </td>
                    <td>{returnDay(l.end)}</td>
                    <td>{l.followUp}</td>
                    <td>
                      <button className="quiet" onClick={() => setEdit(l)}>
                        Editar
                      </button>
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
        {!leaves.length && <Empty>No hay descansos registrados.</Empty>}
      </Section>
      {action.error && <p role="alert">{action.error}</p>}
    </>
  );
}
