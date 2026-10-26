import { useEffect, useMemo, useRef, useState } from "react";
import { normalize, type Worker } from "./model";

export function WorkerSearch({
  workers,
  initialQuery,
  onSelect,
  onNew,
  onClose,
}: {
  workers: Worker[];
  initialQuery: string;
  onSelect: (w: Worker) => void;
  onNew: (query: string) => void;
  onClose: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const results = useRef<HTMLDivElement>(null);
  const [query, setQuery] = useState(initialQuery),
    [page, setPage] = useState(0);
  const ordered = useMemo(
    () =>
      [...workers].sort(
        (a, b) =>
          a.name.localeCompare(b.name, "es") || a.dni.localeCompare(b.dni),
      ),
    [workers],
  );
  const matches = useMemo(() => {
    const terms = normalize(query).split(" ");
    return ordered.filter((w) =>
      terms.every((t) => normalize(w.name + " " + w.dni).includes(t)),
    );
  }, [ordered, query]);
  const pages = Math.max(1, Math.ceil(matches.length / 25));
  useEffect(() => {
    results.current?.scrollTo({
      top: 0,
      behavior: matchMedia("(prefers-reduced-motion: reduce)").matches
        ? "instant"
        : "smooth",
    });
  }, [page, query]);
  useEffect(() => {
    dialog.current?.showModal();
    dialog.current?.querySelector<HTMLInputElement>("input")?.focus();
    return () => dialog.current?.close();
  }, []);
  return (
    <dialog
      ref={dialog}
      className="roster-dialog"
      aria-labelledby="roster-title"
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
    >
      <div className="roster-header">
        <div>
          <span className="eyebrow">PADRÓN DE TRABAJADORES</span>
          <h2 id="roster-title">Buscar en padrón</h2>
        </div>
        <button
          className="quiet"
          aria-label="Cerrar búsqueda de padrón"
          onClick={onClose}
        >
          Cerrar ×
        </button>
      </div>
      <label className="field">
        <span>DNI o apellidos y nombres</span>
        <input
          autoFocus
          aria-label="DNI o apellidos y nombres"
          placeholder="Escribe DNI, nombres o apellidos"
          value={query}
          onChange={(e) => {
            setQuery(e.target.value);
            setPage(0);
          }}
        />
      </label>
      <p className="muted" aria-live="polite">
        {matches.length} encontrados · Página {page + 1} de {pages}
      </p>
      <div className="roster-results" ref={results}>
        {matches.slice(page * 25, page * 25 + 25).map((w) => (
          <button
            className="roster-row"
            key={w.dni}
            onClick={() => onSelect(w)}
          >
            <span className="avatar" aria-hidden="true">
              {w.name.slice(0, 1)}
            </span>
            <span>
              <strong>{w.name}</strong>
              <small>
                {w.dni} ·{" "}
                {w.site === "PLVENTUROSA"
                  ? "Planta La Venturosa"
                  : "Fundo La Venturosa"}
              </small>
              <small>
                {w.area} · {w.labor}
              </small>
            </span>
            <span aria-hidden="true">→</span>
          </button>
        ))}
        {!matches.length && (
          <div className="empty">
            <strong>
              {workers.length
                ? "No encontramos esa persona"
                : "Tu padrón está vacío"}
            </strong>
            <p>
              {workers.length
                ? "Revisa el DNI o los nombres. Si no figura, puedes registrar su ficha."
                : "Importa tu archivo PERSONAL o registra a un trabajador para continuar."}
            </p>
          </div>
        )}
      </div>
      {pages > 1 && (
        <div className="pagination">
          <button disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
            Anterior
          </button>
          <span>
            {page + 1} / {pages}
          </span>
          <button
            disabled={page + 1 >= pages}
            onClick={() => setPage((p) => p + 1)}
          >
            Siguiente
          </button>
        </div>
      )}
      <button className="full" onClick={() => onNew(query)}>
        Registrar nuevo trabajador
      </button>
    </dialog>
  );
}
