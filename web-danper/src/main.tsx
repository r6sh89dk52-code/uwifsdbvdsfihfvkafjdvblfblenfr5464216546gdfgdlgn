import { ModuleIcon, moduleDetails } from "./ModuleIcon";
import { clinician } from "./clinician";
import { nursingCatalog } from "./nursingCatalog";
import { NursingSearch } from "./NursingSearch";
import { trialMode, switchWorkspace } from "./workspace";
import React, { Suspense, lazy, useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";
import type { User } from "firebase/auth";
import products from "../legacy/products.json";
import contract from "./generated/contract.json";
import { kardexCatalog } from "../legacy/kardexCatalog";
import {
  validateClinicalStage,
  findFirstInvalidStage,
  SYSTEM_REQUIRED_CATEGORIES,
  type ClinicalStage,
} from "../legacy/attentionStepValidation";
import { inferProcedure } from "../legacy/procedureRules";
import { readOfficialOrganization } from "./organization";
import { store, put } from "./storage";
import {
  authSetup,
  configured,
  cloudWritesEnabled,
  login,
  logout,
  synchronize,
  syncStatus,
} from "./sync";
import {
  emptyDraft,
  normalize,
  limaDay,
  cutPeriod,
  type Collection,
  type Worker,
  type Allergy,
  type Visit,
  type Draft,
  type Lot,
  type Movement,
  type Change,
  type Exam,
  type Leave,
  type Item,
} from "./model";
import {
  saveClinical,
  validateLot,
  candidates,
  isContainer,
  openCount,
  postInventory,
  closeContainer,
  reportBalance,
} from "./accounting";
import { download } from "./workbooks";
import "./style.css";
const Occupational = lazy(() => import("./occupational"));
const Tools = lazy(() => import("./tools"));
export function useRecords<T>(collection: Collection) {
  const [rows, setRows] = useState<T[]>([]);
  useEffect(() => {
    let live = true;
    const refresh = () =>
      store.all<T>(collection).then((r) => {
        if (live) setRows(r.map((e) => e.data));
      });
    const changed = (e: Event) => {
      const cs = (e as CustomEvent<string[]>).detail;
      if (!cs || cs.includes(collection)) void refresh();
    };
    void refresh();
    window.addEventListener("danper-data", changed);
    return () => {
      live = false;
      window.removeEventListener("danper-data", changed);
    };
  }, [collection]);
  return rows;
}
export function Field({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}) {
  return (
    <label className="field">
      <span>{label}</span>
      {children}
    </label>
  );
}
export function Select({
  label,
  value,
  onChange,
  options,
  empty = true,
}: {
  label: string;
  value: string;
  onChange: (s: string) => void;
  options: string[];
  empty?: boolean;
}) {
  return (
    <Field label={label}>
      <select
        aria-label={label}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      >
        {empty && <option value="">Seleccionar…</option>}
        {options.map((v) => (
          <option key={v} value={v}>
            {(
              {
                M: "Masculino",
                F: "Femenino",
                "LA VENTUROSA": "Fundo La Venturosa",
                PLVENTUROSA: "Planta La Venturosa",
                system: "Seguir el sistema",
                light: "Claro",
                dark: "Oscuro",
                danper: "DANPER rojo",
                salud: "Salud azul",
                unknown: "Sin información",
                none: "No refiere alergias",
                known: "Alergias reportadas",
                extraordinary: "Ingreso",
                adjustment: "Conteo / ajuste",
                containerState: "Estado de envase",
                results: "Resultados e historial",
                campaign: "Base seleccionada / programación de campaña",
              } as Record<string, string>
            )[v] || v}
          </option>
        ))}
      </select>
    </Field>
  );
}
export function Text({
  label,
  value,
  onChange,
  type = "text",
  list,
  readOnly = false,
}: {
  label: string;
  value: string;
  onChange: (s: string) => void;
  type?: string;
  list?: string;
  readOnly?: boolean;
}) {
  return (
    <Field label={label}>
      <input
        aria-label={label}
        type={type}
        list={list}
        readOnly={readOnly}
        value={value}
        onChange={(e) => onChange(e.target.value)}
      />
    </Field>
  );
}
export function Check({
  label,
  value,
  onChange,
}: {
  label: string;
  value: boolean;
  onChange: (b: boolean) => void;
}) {
  return (
    <label className="check">
      <input
        type="checkbox"
        checked={value}
        onChange={(e) => onChange(e.target.checked)}
      />
      {label}
    </label>
  );
}
export function Empty({ children }: { children: React.ReactNode }) {
  return <div className="empty">{children}</div>;
}
export function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="card">
      <h2>{title}</h2>
      {children}
    </section>
  );
}
export function useAction() {
  const [error, setError] = useState("");
  return {
    error,
    run: async (fn: () => Promise<unknown>) => {
      setError("");
      try {
        await fn();
      } catch (e) {
        setError(e instanceof Error ? e.message : "Operación no completada");
      }
    },
  };
}
export async function atomic(changes: Change[]) {
  const device = (await store.meta<string>("device")) || crypto.randomUUID();
  await store.setMeta("device", device);
  await store.commit(changes, device);
  window.dispatchEvent(
    new CustomEvent("danper-data", {
      detail: [...new Set(changes.map((c) => c.collection))],
    }),
  );
  void synchronize();
}
export async function changed(
  collection: Collection,
  id: string,
  data: unknown,
): Promise<Change> {
  return {
    collection,
    id,
    data,
    expectedRevision: (await store.get(collection, id))?.revision || 0,
  };
}
function App() {
  const [nav, setNav] = useState("Inicio");
  const [module, setModule] = useState("");
  const [theme, setTheme] = useState(
    localStorage.getItem("danper.theme") || "system",
  );
  const [palette, setPalette] = useState(
    localStorage.getItem("danper.palette") || "danper",
  );
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(!configured);
  const [, refresh] = useState(0);
  const action = useAction();
  useEffect(() => {
    const media = matchMedia("(prefers-color-scheme: dark)");
    const update = () => {
      document.documentElement.dataset.theme =
        theme === "system" ? (media.matches ? "dark" : "light") : theme;
      document.documentElement.dataset.palette = palette;
    };
    update();
    media.addEventListener("change", update);
    localStorage.setItem("danper.theme", theme);
    localStorage.setItem("danper.palette", palette);
    return () => media.removeEventListener("change", update);
  }, [theme, palette]);
  useEffect(
    () =>
      authSetup((u) => {
        setUser(u);
        setReady(true);
      }),
    [],
  );
  useEffect(() => {
    const f = () => refresh((n) => n + 1);
    window.addEventListener("danper-sync", f);
    window.addEventListener("online", synchronize);
    const t = setInterval(() => void synchronize(), 60000);
    return () => {
      window.removeEventListener("danper-sync", f);
      window.removeEventListener("online", synchronize);
      clearInterval(t);
    };
  }, []);
  const go = (m: string) => {
    setModule(m);
    setNav(m ? "Inicio" : "Inicio");
  };
  if (!ready) return <Empty>Verificando sesión…</Empty>;
  if (configured && !user)
    return (
      <main className="login">
        <img src="/brand.png" alt="DANPER" />
        <h1>DANPER SALUD</h1>
        <p>Acceso a tu espacio de salud ocupacional.</p>
        <button onClick={() => void action.run(login)}>
          Ingresar con Google
        </button>
        {action.error && <p role="alert">{action.error}</p>}
      </main>
    );
  return (
    <div className="shell">
      <aside>
        <div className="brand">
          <img src="/brand.png" alt="DANPER" />
          <div>
            SALUD<small>Salud ocupacional</small>
          </div>
        </div>
        <nav aria-label="Navegación principal">
          {["Inicio", "Registrar", "Historial", "Ajustes"].map((n, i) => (
            <button
              className={!module && nav === n ? "active" : ""}
              key={n}
              onClick={() => {
                setNav(n);
                setModule("");
              }}
            >
              <span aria-hidden>{["⌂", "＋", "◷", "⚙"][i]}</span>
              {n}
            </button>
          ))}
        </nav>
        <div className="aside-caption">ESPACIO DE TRABAJO</div>
        <nav aria-label="Módulos">
          {[
            "Trabajadores",
            "Kardex e inventario",
            "EMO",
            "Colinesterasa",
            "Descansos médicos",
            "Alertas",
            "Indicadores y exportaciones",
          ].map((n) => (
            <button
              className={module === n ? "active" : ""}
              key={n}
              onClick={() => go(n)}
            >
              <ModuleIcon name={n} />
              {n}
            </button>
          ))}
        </nav>
        <div className="sync">
          <span className="dot" />
          {syncStatus.message}
          <small>
            {syncStatus.pending} pendientes · {syncStatus.conflicts} conflictos
          </small>
          <button className="quiet" onClick={() => void synchronize()}>
            Sincronizar
          </button>
        </div>
      </aside>
      <div className="workspace">
        <header>
          <div>
            <span className="eyebrow">DANPER · VENTUROSA</span>
            <h1>{module || nav}</h1>
          </div>
          <div className="header-actions">
            <span className="pill">
              {configured ? "Cuenta autorizada" : "Espacio local"}
            </span>
            <button
              className="icon"
              aria-label="Cambiar tema"
              onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
            >
              {theme === "dark" ? "☀" : "☾"}
            </button>
          </div>
        </header>
        <main>
          {trialMode && (
            <div className="warning trial-banner">
              <strong>PRUEBA LOCAL · DATOS FICTICIOS</strong>
              <p>
                Este espacio está separado de tus registros y nunca se
                sincroniza.
              </p>
              <button onClick={() => switchWorkspace(false)}>
                Volver a mis registros
              </button>
            </div>
          )}
          {configured && !trialMode && !cloudWritesEnabled && (
            <p className="notice" role="status">
              Versión en validación. Los registros se guardan en este navegador;
              la sincronización clínica compartida está desactivada.
            </p>
          )}
          <Suspense fallback={<Empty>Cargando módulo…</Empty>}>
            {module === "Trabajadores" ? (
              <Workers />
            ) : module === "Kardex e inventario" ? (
              <Inventory />
            ) : module === "EMO" ? (
              <Occupational kind="emo" />
            ) : module === "Colinesterasa" ? (
              <Occupational kind="cholinesterase" />
            ) : module === "Descansos médicos" ? (
              <Occupational kind="leaves" />
            ) : module === "Alertas" ? (
              <Alerts />
            ) : module === "Indicadores y exportaciones" ? (
              <Tools mode="reports" />
            ) : nav === "Registrar" ? (
              <Clinical />
            ) : nav === "Historial" ? (
              <History />
            ) : nav === "Ajustes" ? (
              <>
                <Section title="Apariencia">
                  <div className="grid">
                    <Select
                      label="Tema"
                      value={theme}
                      onChange={setTheme}
                      options={["system", "light", "dark"]}
                      empty={false}
                    />
                    <Select
                      label="Paleta"
                      value={palette}
                      onChange={setPalette}
                      options={["danper", "salud"]}
                      empty={false}
                    />
                  </div>
                </Section>
                <Tools mode="settings" />
                {user && (
                  <button onClick={() => void logout()}>Cerrar sesión</button>
                )}
              </>
            ) : (
              <Dashboard
                go={go}
                register={() => {
                  setNav("Registrar");
                  setModule("");
                }}
              />
            )}
          </Suspense>
        </main>
        <footer>
          Inventario único · Fundo La Venturosa y PL Venturosa · America/Lima
        </footer>
      </div>
    </div>
  );
}
function Dashboard({
  go,
  register,
}: {
  go: (s: string) => void;
  register: () => void;
}) {
  const visits = useRecords<Visit>("attentions"),
    drafts = useRecords<Draft>("drafts"),
    lots = useRecords<Lot>("lots"),
    emo = useRecords<Exam>("emo");
  const day = limaDay();
  const metrics = [
    ["Atenciones de hoy", visits.filter((v) => v.date === day).length],
    ["Borradores", drafts.filter((d) => d.status === "draft").length],
    [
      "Consumos pendientes",
      visits.reduce((s, v) => s + (v.pending?.length || 0), 0),
    ],
    [
      "Stock mínimo",
      lots.filter(
        (l) => l.minimum !== undefined && reportBalance(l) <= l.minimum,
      ).length,
    ],
    [
      "Próximos EMO",
      emo.filter(
        (e) => e.nextDate && e.nextDate <= limaDay(Date.now() + 30 * 86400000),
      ).length,
    ],
  ];
  return (
    <>
      <div className="hero">
        <div>
          <span className="eyebrow">TU JORNADA, EN UN SOLO LUGAR</span>
          <h2>Cuidamos la salud de nuestro equipo</h2>
          <p>Registra, consulta y da seguimiento a cada atención.</p>
          <button onClick={register}>＋ Registrar atención</button>
        </div>
        <div className="hero-symbol" aria-hidden>
          ✚
        </div>
      </div>
      <div className="metrics">
        {metrics.map(([label, n]) => (
          <div className="card metric" key={label}>
            <span>{label}</span>
            <strong>{n}</strong>
          </div>
        ))}
      </div>
      <Section title="Accesos rápidos">
        <div className="quick">
          {[
            "Trabajadores",
            "Kardex e inventario",
            "EMO",
            "Colinesterasa",
            "Descansos médicos",
            "Alertas",
            "Indicadores y exportaciones",
          ].map((m) => (
            <button key={m} aria-label={m} onClick={() => go(m)}>
              <ModuleIcon name={m} />
              <div>
                <strong>{m}</strong>
                <small>{moduleDetails[m]}</small>
              </div>
              <span aria-hidden="true">↗</span>
            </button>
          ))}
        </div>
      </Section>
      <Section title="Actividad reciente">
        {visits.length ? (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Fecha</th>
                  <th>Trabajador</th>
                  <th>Tipo de atención</th>
                  <th>Dispensación</th>
                </tr>
              </thead>
              <tbody>
                {visits
                  .slice(-5)
                  .reverse()
                  .map((v) => (
                    <tr key={v.id}>
                      <td>
                        {v.date} {v.time}
                      </td>
                      <td>{v.worker.name}</td>
                      <td>{v.category}</td>
                      <td>
                        <span className="badge">
                          {v.pending?.length
                            ? "Pendiente de conciliación"
                            : "Confirmada"}
                        </span>
                      </td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        ) : (
          <Empty>
            Aún no hay atenciones. Las estadísticas se calcularán a partir de
            tus registros.
          </Empty>
        )}
      </Section>
    </>
  );
}
function WorkerEditor({
  worker,
  onSave,
  onCancel,
}: {
  worker: Worker;
  onSave: (w: Worker) => Promise<void>;
  onCancel: () => void;
}) {
  const [w, setW] = useState(worker);
  const action = useAction();
  const areas = useMemo(() => readOfficialOrganization(), []);
  return (
    <div className="editor">
      <h3>{worker.dni ? "Editar trabajador" : "Nuevo trabajador"}</h3>
      <div className="grid">
        {(
          [
            "dni",
            "name",
            "area",
            "labor",
            "sex",
            "birthDate",
            "site",
            "ubigeo",
          ] as const
        ).map((k, i) =>
          k === "site" || k === "sex" ? (
            <Select
              key={k}
              label={k === "site" ? "Sede" : "Sexo (M/F)"}
              value={w[k] || ""}
              options={
                k === "site"
                  ? [
                      ...new Set([
                        "LA VENTUROSA",
                        "PLVENTUROSA",
                        ...(w.site ? [w.site] : []),
                      ]),
                    ]
                  : ["M", "F"]
              }
              onChange={(v) => setW({ ...w, [k]: v })}
            />
          ) : (
            <Text
              key={k}
              label={
                [
                  "DNI",
                  "Apellidos y nombres",
                  "Área",
                  "Labor / puesto",
                  "Sexo (M/F)",
                  "Nacimiento",
                  "Sede",
                  "Ubigeo",
                ][i]
              }
              type={k === "birthDate" ? "date" : "text"}
              list={k === "area" ? "official-areas" : undefined}
              value={w[k] || ""}
              onChange={(v) => setW({ ...w, [k]: v })}
            />
          ),
        )}
      </div>
      <datalist id="official-areas">
        {areas
          .filter((a) => a.site === w.site)
          .map((a) => (
            <option key={a.site + a.code} value={a.area} />
          ))}
      </datalist>
      <div className="actions">
        <button
          onClick={() =>
            void action.run(async () => {
              if (
                !/^\d{8}$/.test(w.dni) ||
                !w.name.trim() ||
                (w.sex && !["M", "F"].includes(w.sex))
              )
                throw Error("Verifica DNI, nombre y sexo");
              if (worker.dni && w.dni !== worker.dni)
                throw Error("El DNI canónico no se cambia desde la ficha");
              await onSave({
                ...w,
                source: "manual",
                localCorrectionAt: Date.now(),
              });
            })
          }
        >
          Guardar ficha
        </button>
        <button className="quiet" onClick={onCancel}>
          Cancelar
        </button>
      </div>
      {action.error && <p role="alert">{action.error}</p>}
    </div>
  );
}
function Workers() {
  const workers = useRecords<Worker>("workers");
  const [q, setQ] = useState(""),
    [page, setPage] = useState(0),
    [edit, setEdit] = useState<Worker | null>(null);
  const result = useMemo(() => {
    const terms = normalize(q).split(" ");
    return workers.filter((w) =>
      terms.every((t) =>
        normalize(w.name + " " + w.dni + " " + w.area).includes(t),
      ),
    );
  }, [q, workers]);
  return (
    <>
      <Section title="Padrón de trabajadores">
        <div className="toolbar">
          <input
            aria-label="Buscar trabajadores"
            placeholder="Buscar por DNI, nombre o área"
            value={q}
            onChange={(e) => {
              setQ(e.target.value);
              setPage(0);
            }}
          />
          <button onClick={() => setEdit(emptyDraft().worker)}>
            ＋ Nuevo trabajador
          </button>
        </div>
        <p className="muted">
          {result.length} trabajadores · Identidad compartida por DNI
        </p>
        {edit && (
          <WorkerEditor
            key={edit.dni}
            worker={edit}
            onCancel={() => setEdit(null)}
            onSave={async (w) => {
              if (!edit.dni && workers.some((x) => x.dni === w.dni))
                throw Error("DNI existente; edita la ficha actual");
              await put("workers", w.dni, w);
              setEdit(null);
            }}
          />
        )}
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>DNI</th>
                <th>Nombres</th>
                <th>Sede</th>
                <th>Área</th>
                <th>Labor</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {result.slice(page * 25, page * 25 + 25).map((w) => (
                <tr key={w.dni}>
                  <td>{w.dni}</td>
                  <td>{w.name}</td>
                  <td>{w.site}</td>
                  <td>{w.area}</td>
                  <td>{w.labor}</td>
                  <td>
                    <button className="quiet" onClick={() => setEdit(w)}>
                      Editar
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!result.length && <Empty>No hay trabajadores que mostrar.</Empty>}
        <div className="pagination">
          <button disabled={!page} onClick={() => setPage(page - 1)}>
            Anterior
          </button>
          <span>
            {page + 1} / {Math.max(1, Math.ceil(result.length / 25))}
          </span>
          <button
            disabled={(page + 1) * 25 >= result.length}
            onClick={() => setPage(page + 1)}
          >
            Siguiente
          </button>
        </div>
      </Section>
      <Suspense>
        <Tools mode="workers" />
      </Suspense>
    </>
  );
}
function Clinical() {
  const workers = useRecords<Worker>("workers"),
    allergies = useRecords<Allergy>("allergies"),
    drafts = useRecords<Draft>("drafts"),
    lots = useRecords<Lot>("lots"),
    moves = useRecords<Movement>("movements");
  const [d, setD] = useState<Draft>(emptyDraft),
    [q, setQ] = useState(""),
    [search, setSearch] = useState(""),
    [newWorker, setNewWorker] = useState(false),
    [issues, setIssues] = useState<string[]>([]),
    [notice, setNotice] = useState(""),
    [saving, setSaving] = useState(false);
  const action = useAction();
  const update = (patch: Partial<Draft>) => {
    setD((old) => ({ ...old, ...patch }));
    setNotice("");
  };
  useEffect(() => {
    const timer = setTimeout(() => {
      if (d.worker.dni || d.diagnosis || d.items.length)
        void put("drafts", d.id, d, false).catch((e) => setIssues([e.message]));
    }, 500);
    return () => clearTimeout(timer);
  }, [d]);
  const matches = useMemo(() => {
    if (!q.trim()) return [];
    const terms = normalize(q).split(" ");
    return workers
      .filter((w) =>
        terms.every((t) => normalize(w.dni + " " + w.name).includes(t)),
      )
      .slice(0, 12);
  }, [workers, q]);
  const productsFound = useMemo(() => {
    const n = normalize(search);
    return n
      ? products.filter((p) => normalize(p.name + " " + p.code).includes(n))
      : products;
  }, [search]);
  const ctx = {
    validCategories: contract.categories,
    validSystems: contract.systems,
    rosterRequired: true,
    workerInRoster: workers.some((w) => w.dni === d.worker.dni),
    rosterException: false,
    allergiesReviewed: d.allergy.reviewed,
    allergyStatus: d.allergy.status,
    allergySubstances: d.allergy.substances,
  };
  const patchItem = (id: string, p: Partial<Item>) =>
    update({ items: d.items.map((i) => (i.id === id ? { ...i, ...p } : i)) });
  const wound = [...d.procedures, ...d.items.map((i) => i.procedure)].some(
    (p) => p.includes("HERIDA") || p.includes("SUTUR"),
  );
  const selectWorker = (w: Worker) => {
    update({
      worker: w,
      allergy: allergies.find((a) => a.dni === w.dni) || {
        dni: w.dni,
        reviewed: false,
        status: "unknown",
        substances: "",
      },
    });
    setQ("");
  };
  async function save() {
    setSaving(true);
    try {
      const errors = findFirstInvalidStage(d, ctx);
      if (errors.length) {
        setIssues(errors.map((e) => e.message));
        update({ step: errors[0].step });
        return;
      }
      if (!d.procedures.length && !d.items.length)
        throw Error("Selecciona al menos un procedimiento o producto");
      if (d.items.some((i) => !i.procedureConfirmed))
        throw Error("Confirma los procedimientos sugeridos de cada producto");
      if (!d.responsible.trim() || !/^\d{8}$/.test(d.responsibleDni))
        throw Error("Completa responsable y DNI");
      if (wound && !d.photoReviewed)
        throw Error(
          "Confirma la revisión del estado de fotografía de curación",
        );
      const current = await store.get("attentions", d.id);
      if (current) {
        setNotice("Esta atención ya está guardada.");
        return;
      }
      const currentLots = await store.all<Lot>("lots");
      const currentMoves = (await store.all<Movement>("movements")).map(
        (e) => e.data,
      );
      const worker = (await store.get<Worker>("workers", d.worker.dni))?.data;
      if (!worker) throw Error("Trabajador no disponible");
      const visit = {
        ...d,
        worker,
        status: "saved" as const,
        standaloneProcedures: d.procedures,
        workStatus: d.permission === "SI" ? "PERMISO" : "LABORANDO",
        system: SYSTEM_REQUIRED_CATEGORIES.some((c) => c === d.category)
          ? d.system
          : "",
        segment: d.system === "OSTEOMUSCULAR" ? d.segment : "",
        photoSent: wound && d.photoSent,
      };
      const result = saveClinical(
        visit,
        currentLots.map((e) => e.data),
        currentMoves,
      );
      const changes: Change[] = [
        {
          collection: "attentions",
          id: d.id,
          expectedRevision: 0,
          data: result.visit,
        },
        await changed("allergies", d.worker.dni, d.allergy),
      ];
      for (const i of d.items)
        changes.push({
          collection: "clinicalItems",
          id: d.id + ":" + i.id,
          expectedRevision: 0,
          data: { ...i, attentionId: d.id },
        });
      for (const e of currentLots) {
        const after = result.lots.find((l) => l.id === e.id)!;
        if (JSON.stringify(after) !== JSON.stringify(e.data))
          changes.push({
            collection: "lots",
            id: e.id,
            expectedRevision: e.revision,
            data: after,
          });
      }
      for (const m of result.movements)
        changes.push({
          collection: "movements",
          id: m.id,
          expectedRevision: 0,
          data: m,
        });
      await atomic(changes);
      await put("drafts", d.id, { ...d, status: "saved" }, false);
      setD(emptyDraft());
      setIssues([]);
      setNotice(
        "Atención guardada. " +
          result.movements.length +
          " movimientos confirmados; " +
          result.visit.pending.length +
          " consumos pendientes.",
      );
    } finally {
      setSaving(false);
    }
  }
  return (
    <>
      <div className="section-heading">
        <div>
          <p className="muted">
            Atención clínica · Borrador guardado automáticamente
          </p>
        </div>
        {drafts.some((x) => x.status === "draft") && (
          <select
            aria-label="Reanudar borrador"
            value=""
            onChange={(e) => {
              const found = drafts.find((x) => x.id === e.target.value);
              if (found) {
                setD({
                  ...found,
                  responsible: found.responsible || clinician.name,
                  responsibleDni:
                    found.responsibleDni ||
                    (!found.responsible || found.responsible === clinician.name
                      ? clinician.dni
                      : ""),
                });
                setIssues([]);
              }
            }}
          >
            <option value="">Reanudar borrador…</option>
            {drafts
              .filter((x) => x.status === "draft")
              .map((x) => (
                <option key={x.id} value={x.id}>
                  {x.worker.name || "Sin trabajador"} · {x.date}
                </option>
              ))}
          </select>
        )}
      </div>
      <div className="steps">
        {["Trabajador", "Evaluación", "Tratamiento", "Resultado"].map(
          (s, i) => (
            <button
              key={s}
              className={d.step === i ? "active" : ""}
              onClick={() => {
                if (i > d.step) {
                  const errs = validateClinicalStage(
                    d.step as ClinicalStage,
                    d,
                    ctx,
                  );
                  if (errs.length) {
                    setIssues(errs.map((e) => e.message));
                    return;
                  }
                }
                update({ step: i });
                setIssues([]);
              }}
            >
              <span>{i + 1}</span>
              {s}
            </button>
          ),
        )}
      </div>
      <Section
        title={
          [
            "Seleccionar trabajador",
            "Evaluación de la atención",
            "Tratamiento y procedimientos",
            "Resultado de la atención",
          ][d.step]
        }
      >
        {d.step === 0 && (
          <>
            <input
              className="full"
              aria-label="Buscar trabajador para atención"
              placeholder="Escribe DNI o nombres del trabajador"
              value={q}
              onChange={(e) => setQ(e.target.value)}
            />
            {matches.length > 0 && (
              <div className="results">
                {matches.map((w) => (
                  <button
                    className="result"
                    key={w.dni}
                    onClick={() => selectWorker(w)}
                  >
                    <b>{w.name}</b>
                    <small>
                      {w.dni} · {w.area} · {w.labor}
                    </small>
                  </button>
                ))}
              </div>
            )}
            {d.worker.dni && (
              <div className="selected-worker">
                <span className="avatar">{d.worker.name.slice(0, 1)}</span>
                <div>
                  <strong>{d.worker.name}</strong>
                  <p>
                    {d.worker.dni} · {d.worker.site}
                  </p>
                  <small>
                    {d.worker.area} · {d.worker.labor}
                  </small>
                </div>
                <button className="quiet" onClick={() => setNewWorker(true)}>
                  Editar ficha
                </button>
              </div>
            )}
            <button className="quiet" onClick={() => setNewWorker(true)}>
              ＋ Registrar trabajador sin salir
            </button>
            {newWorker && (
              <WorkerEditor
                worker={d.worker}
                onCancel={() => setNewWorker(false)}
                onSave={async (w) => {
                  const old = await store.get<Worker>("workers", w.dni);
                  if (!d.worker.dni && old)
                    throw Error(
                      "DNI existente; selecciónalo desde la búsqueda",
                    );
                  await put("workers", w.dni, w);
                  selectWorker(w);
                  setNewWorker(false);
                }}
              />
            )}
          </>
        )}
        {d.step === 1 && (
          <>
            <div className="grid">
              <Text
                label="Fecha"
                type="date"
                value={d.date}
                onChange={(v) => update({ date: v })}
              />
              <Text
                label="Hora"
                type="time"
                value={d.time}
                onChange={(v) => update({ time: v })}
              />
              <Select
                label="Tipo de atención"
                value={d.category}
                onChange={(v) =>
                  update({ category: v, system: "", segment: "" })
                }
                options={contract.categories}
              />
              {SYSTEM_REQUIRED_CATEGORIES.some((c) => c === d.category) && (
                <Select
                  label="Sistema afectado"
                  value={d.system}
                  onChange={(v) => update({ system: v, segment: "" })}
                  options={contract.systems}
                />
              )}
              {SYSTEM_REQUIRED_CATEGORIES.some((c) => c === d.category) &&
                d.system === "OSTEOMUSCULAR" && (
                  <Text
                    label="Segmento osteomuscular"
                    list="segments"
                    value={d.segment}
                    onChange={(v) => update({ segment: v })}
                  />
                )}
            </div>
            <datalist id="segments">
              {contract.segments.map((v) => (
                <option key={v}>{v}</option>
              ))}
            </datalist>
            <Text
              label="Diagnóstico presuntivo / comentario clínico"
              list="diagnoses"
              value={d.diagnosis}
              onChange={(v) => update({ diagnosis: v })}
            />
            <datalist id="diagnoses">
              {contract.diagnoses.map((v) => (
                <option key={v}>{v}</option>
              ))}
            </datalist>
            <div className="inset">
              <h3>Revisión de alergias</h3>
              <Select
                label="Estado reportado"
                value={d.allergy.status}
                options={["unknown", "none", "known"]}
                empty={false}
                onChange={(v) =>
                  update({
                    allergy: {
                      ...d.allergy,
                      status: v as Allergy["status"],
                      reviewed: false,
                    },
                  })
                }
              />
              {d.allergy.status === "known" && (
                <Text
                  label="Sustancias / medicamentos reportados"
                  value={d.allergy.substances}
                  onChange={(v) =>
                    update({ allergy: { ...d.allergy, substances: v } })
                  }
                />
              )}
              <Check
                label="He revisado las alergias con el trabajador"
                value={d.allergy.reviewed}
                onChange={(v) =>
                  update({ allergy: { ...d.allergy, reviewed: v } })
                }
              />
            </div>
          </>
        )}
        {d.step === 2 && (
          <>
            <h3>Procedimientos realizados</h3>
            <div className="checks">
              {contract.procedures.map((p) => (
                <Check
                  key={p}
                  label={p}
                  value={d.procedures.includes(p)}
                  onChange={(v) =>
                    update({
                      procedures: v
                        ? [...d.procedures, p]
                        : d.procedures.filter((x) => x !== p),
                    })
                  }
                />
              ))}
            </div>
            <h3>
              Medicamentos e insumos · {products.length} productos oficiales
            </h3>
            <input
              aria-label="Buscar producto clínico"
              placeholder="Buscar escribiendo nombre o código"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
            <div
              className="catalog-results"
              role="list"
              aria-label="Catálogo clínico"
            >
              {productsFound.map((p) => (
                <button
                  role="listitem"
                  className="result"
                  key={p.code}
                  onClick={() => {
                    const proposal = inferProcedure(
                      p,
                      d.items.filter((i) => i.procedureConfirmed),
                      d.procedures,
                    );
                    update({
                      items: [
                        ...d.items,
                        {
                          ...p,
                          id: crypto.randomUUID(),
                          quantity: 1,
                          procedure: proposal.procedure,
                          procedureConfirmed: false,
                          procedureSource: proposal.source,
                          physicalQuantity: 0,
                          newContainers: 1,
                        },
                      ],
                    });
                    setSearch("");
                  }}
                >
                  <b>{p.name}</b>
                  <small>
                    {p.unit} · {p.code} <span>＋</span>
                  </small>
                </button>
              ))}
            </div>
            {d.items.map((item) => (
              <div className="inset" key={item.id}>
                <div className="section-heading">
                  <h3>{item.name}</h3>
                  <button
                    className="quiet"
                    onClick={() =>
                      update({ items: d.items.filter((i) => i.id !== item.id) })
                    }
                  >
                    Quitar
                  </button>
                </div>
                <div className="grid">
                  <Text
                    label={"Cantidad clínica (" + item.unit + ")"}
                    type="number"
                    value={String(item.quantity)}
                    onChange={(v) =>
                      patchItem(item.id, { quantity: Number(v) })
                    }
                  />
                  <Select
                    label="Procedimiento"
                    value={item.procedure}
                    onChange={(v) =>
                      patchItem(item.id, {
                        procedure: v,
                        procedureConfirmed: false,
                        procedureSource: "manual",
                      })
                    }
                    options={contract.procedures}
                  />
                  <Field label="Lote / presentación física">
                    <select
                      value={item.selectedLotID || ""}
                      onChange={(e) =>
                        patchItem(item.id, { selectedLotID: e.target.value })
                      }
                    >
                      <option value="">
                        FEFO automático / pendiente sin existencias
                      </option>
                      {lots
                        .filter((l) =>
                          candidates(item).some((c) => c.kardexCode === l.code),
                        )
                        .map((l) => (
                          <option key={l.id} value={l.id}>
                            {l.name} · {l.lot} · {l.catalogUnit} · vence{" "}
                            {l.expires || "sin fecha"}
                          </option>
                        ))}
                    </select>
                  </Field>
                </div>
                <Check
                  label="Confirmo el procedimiento realizado"
                  value={item.procedureConfirmed}
                  onChange={(v) =>
                    patchItem(item.id, { procedureConfirmed: v })
                  }
                />
                {lots.some(
                  (l) =>
                    candidates(item).some((c) => c.kardexCode === l.code) &&
                    isContainer(l.catalogUnit),
                ) && (
                  <div className="grid">
                    <Check
                      label="Abrí nuevo envase"
                      value={!!item.approveOpening}
                      onChange={(v) =>
                        patchItem(item.id, {
                          approveOpening: v,
                          reusePreviouslyOpened: !v,
                        })
                      }
                    />
                    {item.approveOpening && (
                      <>
                        <Text
                          label="Número de envases abiertos"
                          type="number"
                          value={String(item.newContainers || 1)}
                          onChange={(v) =>
                            patchItem(item.id, { newContainers: Number(v) })
                          }
                        />
                        <Check
                          label="Confirmo agotamiento del envase anterior"
                          value={!!item.closePriorContainer}
                          onChange={(v) =>
                            patchItem(item.id, { closePriorContainer: v })
                          }
                        />
                      </>
                    )}
                    <Check
                      label="Reutilicé un envase previamente abierto"
                      value={!!item.reusePreviouslyOpened}
                      onChange={(v) =>
                        patchItem(item.id, {
                          reusePreviouslyOpened: v,
                          approveOpening: false,
                        })
                      }
                    />
                    <Text
                      label="Contenido físico usado (solo si se mide)"
                      type="number"
                      value={String(item.physicalQuantity || 0)}
                      onChange={(v) =>
                        patchItem(item.id, { physicalQuantity: Number(v) })
                      }
                    />
                  </div>
                )}
                <p className="muted">
                  {candidates(item).length
                    ? "El motor verificará el lote al guardar."
                    : "Sin asociación verificada: se conservará el consumo clínico pendiente."}
                </p>
              </div>
            ))}
          </>
        )}
        {d.step === 3 && (
          <>
            <div className="grid">
              <Select
                label="Permiso"
                value={d.permission}
                options={["NO", "SI"]}
                empty={false}
                onChange={(v) => update({ permission: v })}
              />
              {d.permission === "SI" && (
                <Text
                  label="Hora del permiso"
                  type="time"
                  value={d.permissionTime}
                  onChange={(v) => update({ permissionTime: v })}
                />
              )}
              <Text
                label="Responsable"
                readOnly
                value={d.responsible}
                onChange={(v) => update({ responsible: v })}
              />
              <Text
                label="DNI del responsable"
                readOnly
                value={d.responsibleDni}
                onChange={(v) => update({ responsibleDni: v })}
              />
              <Select
                label="Sede de atención"
                value={d.dispensingSite}
                options={["LA VENTUROSA", "PLVENTUROSA"]}
                empty={false}
                onChange={(v) => update({ dispensingSite: v })}
              />
            </div>
            <div className="checks">
              <Check
                label="Banda / curita azul"
                value={d.blueBandage}
                onChange={(v) => update({ blueBandage: v })}
              />
              <Check
                label="Devolución"
                value={d.returned}
                onChange={(v) => update({ returned: v })}
              />
              {wound && (
                <>
                  <Check
                    label="Fotografía enviada"
                    value={d.photoSent}
                    onChange={(v) => update({ photoSent: v })}
                  />
                  <Check
                    label="Revisé el estado de la fotografía de curación"
                    value={d.photoReviewed}
                    onChange={(v) => update({ photoReviewed: v })}
                  />
                </>
              )}
            </div>
            <div className="inset">
              <strong>{d.worker.name}</strong>
              <p>
                {d.category} · {d.diagnosis}
              </p>
              <p>
                {d.items.length} productos · {d.procedures.length}{" "}
                procedimientos
              </p>
              <small>
                Los consumos sin evidencia física quedarán pendientes de
                conciliación.
              </small>
            </div>
          </>
        )}
        {issues.length > 0 && (
          <div role="alert" className="error">
            {issues.map((s, i) => (
              <p key={i}>{s}</p>
            ))}
          </div>
        )}
        {action.error && (
          <p role="alert" className="error">
            {action.error}
          </p>
        )}
        <div className="actions">
          <button
            className="quiet"
            disabled={!d.step}
            onClick={() => update({ step: d.step - 1 })}
          >
            Anterior
          </button>
          {d.step < 3 ? (
            <button
              onClick={() => {
                const errs = validateClinicalStage(
                  d.step as ClinicalStage,
                  d,
                  ctx,
                );
                setIssues(errs.map((e) => e.message));
                if (!errs.length) update({ step: d.step + 1 });
              }}
            >
              Continuar
            </button>
          ) : (
            <button disabled={saving} onClick={() => void action.run(save)}>
              {saving ? "Guardando…" : "Guardar atención"}
            </button>
          )}
        </div>
      </Section>
      {notice && (
        <p role="status" className="success">
          {notice}
        </p>
      )}
      <p className="muted">
        {moves.length} eventos físicos auditables en el inventario.
      </p>
    </>
  );
}
function History() {
  const visits = useRecords<Visit>("attentions"),
    corrections = useRecords<{
      id: string;
      attentionId: string;
      field: string;
      before: string;
      after: string;
      reason: string;
      operatorName: string;
      at: number;
    }>("corrections");
  const [q, setQ] = useState(""),
    [page, setPage] = useState(0),
    [selected, setSelected] = useState<Visit | null>(null),
    [field, setField] = useState("diagnosis"),
    [value, setValue] = useState(""),
    [reason, setReason] = useState(""),
    [operator, setOperator] = useState(clinician.name);
  const action = useAction();
  const found = visits
    .filter((v) =>
      normalize(
        v.worker.dni + " " + v.worker.name + " " + v.diagnosis,
      ).includes(normalize(q)),
    )
    .sort(
      (a, b) => b.date.localeCompare(a.date) || b.time.localeCompare(a.time),
    );
  return (
    <>
      <Section title="Historial de atenciones">
        <input
          aria-label="Buscar historial"
          placeholder="DNI, trabajador o diagnóstico"
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setPage(0);
          }}
        />
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Fecha</th>
                <th>Trabajador</th>
                <th>Tipo</th>
                <th>Diagnóstico</th>
                <th>Consumos</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {found.slice(page * 25, page * 25 + 25).map((v) => (
                <tr key={v.id}>
                  <td>
                    {v.date} {v.time}
                  </td>
                  <td>
                    {v.worker.name}
                    <small>{v.worker.dni}</small>
                  </td>
                  <td>{v.category}</td>
                  <td>
                    {corrections
                      .filter(
                        (c) =>
                          c.attentionId === v.id && c.field === "diagnosis",
                      )
                      .sort((a, b) => b.at - a.at)[0]?.after || v.diagnosis}
                  </td>
                  <td>{v.pending?.length || 0} pendientes</td>
                  <td>
                    <button className="quiet" onClick={() => setSelected(v)}>
                      Ver / rectificar
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        {!found.length && <Empty>No hay atenciones.</Empty>}
        <div className="pagination">
          <button disabled={!page} onClick={() => setPage(page - 1)}>
            Anterior
          </button>
          <span>Página {page + 1}</span>
          <button
            disabled={(page + 1) * 25 >= found.length}
            onClick={() => setPage(page + 1)}
          >
            Siguiente
          </button>
        </div>
      </Section>
      {selected && (
        <Section title="Detalle y rectificación auditada">
          <h3>
            {selected.worker.name} · {selected.date}
          </h3>
          <p>{selected.diagnosis}</p>
          {selected.items.map((i) => (
            <p key={i.id}>
              {i.name} · {i.quantity} {i.unit} · {i.procedure}
            </p>
          ))}
          {selected.pending?.map((p) => (
            <p className="warning" key={p.itemId}>
              {p.reason}
            </p>
          ))}
          <h3>Rectificación</h3>
          <Select
            label="Campo"
            value={field}
            options={["diagnosis", "system", "segment", "responsible"]}
            empty={false}
            onChange={setField}
          />
          <div className="grid">
            <Text label="Valor corregido" value={value} onChange={setValue} />
            <Text label="Motivo" value={reason} onChange={setReason} />
            <Text
              label="Responsable de corrección"
              readOnly
              value={operator}
              onChange={setOperator}
            />
          </div>
          <button
            onClick={() =>
              void action.run(async () => {
                if (
                  reason.trim().length < 10 ||
                  !value.trim() ||
                  operator.trim().length < 3
                )
                  throw Error(
                    "Completa corrección, responsable y motivo (10 caracteres)",
                  );
                const id = crypto.randomUUID();
                await put("corrections", id, {
                  id,
                  attentionId: selected.id,
                  field,
                  before: String(selected[field as keyof Visit]),
                  after: value,
                  reason,
                  operatorName: operator,
                  operatorDni: clinician.dni,
                  at: Date.now(),
                });
                setValue("");
                setReason("");
              })
            }
          >
            Registrar corrección
          </button>
          {corrections
            .filter((c) => c.attentionId === selected.id)
            .map((c) => (
              <p key={c.id}>
                {c.field}: {c.before} → {c.after} · {c.reason} ·{" "}
                {c.operatorName}
              </p>
            ))}
          <button className="quiet" onClick={() => setSelected(null)}>
            Cerrar detalle
          </button>
          {action.error && <p role="alert">{action.error}</p>}
        </Section>
      )}
    </>
  );
}
function Inventory() {
  const lots = useRecords<Lot>("lots"),
    moves = useRecords<Movement>("movements");
  const [q, setQ] = useState(""),
    [selected, setSelected] = useState(""),
    [lot, setLot] = useState(""),
    [expires, setExpires] = useState(""),
    [exceptionUnit, setExceptionUnit] = useState(""),
    [sealed, setSealed] = useState("0"),
    [active, setActive] = useState<Lot | null>(null),
    [kind, setKind] = useState("extraordinary"),
    [amount, setAmount] = useState("0"),
    [loose, setLoose] = useState("0"),
    [reason, setReason] = useState(""),
    [operator, setOperator] = useState(clinician.name),
    [disposition, setDisposition] = useState("agotado");
  const selectedProduct = nursingCatalog.find((p) => p.id === selected);
  const unit = selectedProduct?.unit || exceptionUnit;
  const action = useAction();
  const commitMove = async (m: Movement, revision: number) =>
    atomic([
      {
        collection: "lots",
        id: m.lotId,
        expectedRevision: revision,
        data: m.after,
      },
      { collection: "movements", id: m.id, expectedRevision: 0, data: m },
    ]);
  return (
    <>
      <div className="notice">
        Inventario físico único para Fundo La Venturosa y PL Venturosa. Los
        envases se descuentan según aperturas declaradas.
      </div>
      <Section title="Registrar lote y stock inicial">
        <div className="grid">
          <NursingSearch
            value={selected}
            onChange={(id) => {
              setSelected(id);
              setExceptionUnit("");
            }}
          />
          <Text label="Lote" value={lot} onChange={setLot} />
          <Text
            label="Vencimiento"
            type="date"
            value={expires}
            onChange={setExpires}
          />
          {selectedProduct && (
            <div className="presentation">
              <span className="badge">
                {unit
                  ? "Presentación: " + unit
                  : "Presentación pendiente de verificar"}
              </span>
              <p>
                La presentación proviene del catálogo nativo. Registra la
                cantidad en esa unidad.
              </p>
            </div>
          )}
          {selectedProduct && !selectedProduct.unit && (
            <Select
              label="Presentación excepcional verificada"
              value={exceptionUnit}
              options={[
                ...new Set(nursingCatalog.map((p) => p.unit).filter(Boolean)),
              ].sort()}
              onChange={setExceptionUnit}
            />
          )}
          <Text
            label={"Cantidad inicial" + (unit ? " (" + unit + ")" : "")}
            type="number"
            value={sealed}
            onChange={setSealed}
          />
        </div>
        <button
          onClick={() =>
            void action.run(async () => {
              const p = nursingCatalog.find((p) => p.id === selected);
              if (!p) throw Error("Selecciona un producto");
              if (
                lots.some(
                  (l) => l.code === p.id && normalize(l.lot) === normalize(lot),
                )
              )
                throw Error("Lote existente: registra un ingreso");
              const id = crypto.randomUUID();
              const l: Lot = {
                id,
                code: p.id,
                name: p.name,
                catalogUnit: unit,
                lot,
                expires,
                container: isContainer(unit) ? "otro" : "unidad",
                unitsPerContainer: 1,
                sealedContainers: Number(sealed),
                looseUnits: 0,
                openedRemaining: 0,
                declaredOpenContainers: 0,
                volumeTrackingEnabled: false,
                updatedAt: Date.now(),
              };
              if (
                !Number.isSafeInteger(l.sealedContainers) ||
                l.sealedContainers <= 0
              )
                throw Error("Indica una cantidad inicial mayor que cero");
              validateLot(l);
              await put("lots", id, l);
              setLot("");
              setSealed("0");
            })
          }
        >
          Guardar lote
        </button>
      </Section>
      <Section title="Existencias y envases">
        <input
          aria-label="Buscar inventario"
          placeholder="Producto o lote"
          value={q}
          onChange={(e) => setQ(e.target.value)}
        />
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Producto</th>
                <th>Lote</th>
                <th>Vence</th>
                <th>Cerrados</th>
                <th>Abiertos</th>
                <th>Contenido medido</th>
                <th />
              </tr>
            </thead>
            <tbody>
              {lots
                .filter((l) =>
                  normalize(l.name + " " + l.lot).includes(normalize(q)),
                )
                .map((l) => (
                  <tr key={l.id}>
                    <td>
                      {l.name}
                      <small>{l.catalogUnit}</small>
                    </td>
                    <td>{l.lot}</td>
                    <td>{l.expires || "Sin fecha"}</td>
                    <td>{l.sealedContainers}</td>
                    <td>{openCount(l)}</td>
                    <td>
                      {l.volumeTrackingEnabled
                        ? l.openedRemaining + l.looseUnits
                        : "No medido"}
                    </td>
                    <td>
                      <button className="quiet" onClick={() => setActive(l)}>
                        Operar
                      </button>
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
        {!lots.length && (
          <Empty>
            Registra existencias físicas verificadas para habilitar
            dispensaciones.
          </Empty>
        )}
      </Section>
      {active && (
        <Section title={"Operación: " + active.name + " · " + active.lot}>
          <div className="grid">
            <Select
              label="Operación"
              value={kind}
              options={["extraordinary", "adjustment", "containerState"]}
              empty={false}
              onChange={setKind}
            />
            <Text
              label={
                kind === "containerState"
                  ? "Envases a cerrar"
                  : kind === "adjustment"
                    ? "Conteo de cerrados / unidades"
                    : "Ingreso de cerrados / unidades"
              }
              type="number"
              value={amount}
              onChange={setAmount}
            />
            {kind !== "containerState" && active.volumeTrackingEnabled && (
              <Text
                label="Unidades sueltas"
                type="number"
                value={loose}
                onChange={setLoose}
              />
            )}
            {kind === "containerState" && (
              <Select
                label="Estado declarado"
                value={disposition}
                options={["agotado", "cerrado", "descartado"]}
                empty={false}
                onChange={setDisposition}
              />
            )}
            <Text
              label="Responsable"
              readOnly
              value={operator}
              onChange={setOperator}
            />
            <Text
              label="Motivo / documento"
              value={reason}
              onChange={setReason}
            />
          </div>
          <button
            onClick={() =>
              void action.run(async () => {
                const entity = (await store.get<Lot>("lots", active.id))!;
                const current = entity.data;
                const m =
                  kind === "containerState"
                    ? closeContainer(
                        current,
                        Number(amount),
                        disposition,
                        operator,
                        reason,
                      )
                    : postInventory(
                        current,
                        kind as "extraordinary" | "adjustment",
                        Number(amount),
                        Number(loose),
                        operator,
                        reason,
                      );
                await commitMove(m, entity.revision);
                setActive(null);
                setAmount("0");
                setReason("");
              })
            }
          >
            Confirmar operación física
          </button>
          <button className="quiet" onClick={() => setActive(null)}>
            Cancelar
          </button>
        </Section>
      )}
      <Section title="Movimientos auditables">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Fecha</th>
                <th>Producto</th>
                <th>Operación</th>
                <th>R</th>
                <th>Responsable / motivo</th>
              </tr>
            </thead>
            <tbody>
              {moves
                .slice(-100)
                .reverse()
                .map((m) => (
                  <tr key={m.id}>
                    <td>{limaDay(m.at)}</td>
                    <td>{m.name}</td>
                    <td>{m.kind}</td>
                    <td>{m.excelQuantity}</td>
                    <td>
                      {m.operatorName}
                      <small>{m.description}</small>
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
        <p className="muted">
          Mostrando los últimos 100 de {moves.length} eventos.
        </p>
      </Section>
      {action.error && (
        <p role="alert" className="error">
          {action.error}
        </p>
      )}
    </>
  );
}
function Alerts() {
  const lots = useRecords<Lot>("lots"),
    visits = useRecords<Visit>("attentions"),
    emo = useRecords<Exam>("emo"),
    colin = useRecords<Exam>("cholinesterase"),
    leaves = useRecords<Leave>("leaves"),
    workers = useRecords<Worker>("workers"),
    states = useRecords<{ id: string; done: boolean }>("alerts");
  const [filter, setFilter] = useState("Pendientes");
  const today = limaDay(),
    soon = limaDay(Date.now() + 30 * 86400000);
  const alerts = [
    ...lots.flatMap((l) => [
      ...(l.minimum !== undefined && reportBalance(l) <= l.minimum
        ? [
            {
              id: "stock:" + l.id,
              title: "Stock mínimo · " + l.name,
              date: today,
              priority: "Alta",
            },
          ]
        : []),
      ...(l.expires && l.expires <= soon
        ? [
            {
              id: "expiry:" + l.id,
              title: "Vencimiento · " + l.name + " · " + l.lot,
              date: l.expires,
              priority: l.expires < today ? "Alta" : "Media",
            },
          ]
        : []),
    ]),
    ...emo
      .filter((e) => e.nextDate && e.nextDate <= soon)
      .map((e) => ({
        id: "emo:" + e.id + ":" + e.nextDate,
        title:
          "EMO programado · " +
          (workers.find((w) => w.dni === e.dni)?.name || e.dni),
        date: e.nextDate,
        priority: e.nextDate < today ? "Alta" : "Media",
      })),
    ...colin
      .filter((e) => e.selected && !e.verified)
      .map((e) => ({
        id: "colin:" + e.id,
        title: "Colinesterasa pendiente · " + e.dni,
        date: e.nextDate || today,
        priority: "Media",
      })),
    ...leaves
      .filter(
        (l) => l.end >= today && l.end <= limaDay(Date.now() + 3 * 86400000),
      )
      .map((l) => ({
        id: "leave:" + l.id,
        title: "Descanso próximo a terminar · " + l.dni,
        date: l.end,
        priority: "Media",
      })),
    ...visits.flatMap((v) =>
      (v.pending || []).map((p) => ({
        id: "pending:" + v.id + ":" + p.itemId,
        title: "Conciliación de consumo · " + v.worker.name,
        date: v.date,
        priority: "Alta",
      })),
    ),
  ].map((a) => ({ ...a, done: states.some((s) => s.id === a.id && s.done) }));
  return (
    <Section title="Centro de alertas">
      <Select
        label="Estado"
        value={filter}
        options={["Pendientes", "Atendidas", "Todas"]}
        empty={false}
        onChange={setFilter}
      />
      {alerts
        .filter(
          (a) => filter === "Todas" || a.done === (filter === "Atendidas"),
        )
        .sort((a, b) => a.date.localeCompare(b.date))
        .map((a) => (
          <div className="alert-row" key={a.id}>
            <div>
              <span className="badge">{a.priority}</span>
              <h3>{a.title}</h3>
              <small>{a.date}</small>
            </div>
            <button
              className="quiet"
              onClick={() =>
                void put("alerts", a.id, { id: a.id, done: !a.done })
              }
            >
              {a.done ? "Reabrir" : "Marcar atendida"}
            </button>
          </div>
        ))}
      {!alerts.length && (
        <Empty>
          No hay alertas con los datos actuales. Las fechas de exámenes
          provienen de programación explícita.
        </Empty>
      )}
    </Section>
  );
}
await store.open();
if ("serviceWorker" in navigator && import.meta.env.PROD)
  void navigator.serviceWorker.register("/sw.js");
createRoot(document.getElementById("root")!).render(<App />);
