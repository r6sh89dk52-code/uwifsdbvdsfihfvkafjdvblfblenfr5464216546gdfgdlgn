import { useEffect, useMemo, useRef, useState } from "react";
import products from "../legacy/products.json";
import { normalize, type Item } from "./model";

export function ClinicalProductPicker({
  items,
  onSelect,
  onClose,
}: {
  items: Item[];
  onSelect: (product: (typeof products)[number]) => void;
  onClose: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const results = useRef<HTMLDivElement>(null);
  const [query, setQuery] = useState("");
  const [added, setAdded] = useState(0);
  const matches = useMemo(() => {
    const terms = normalize(query).split(" ");
    return products.filter((p) =>
      terms.every((t) => normalize(p.name + " " + p.code).includes(t)),
    );
  }, [query]);
  const counts = useMemo(() => {
    const map = new Map<string, number>();
    for (const i of items) map.set(i.code, (map.get(i.code) || 0) + 1);
    return map;
  }, [items]);
  useEffect(() => {
    dialog.current?.showModal();
    dialog.current?.querySelector<HTMLInputElement>("input")?.focus();
    return () => dialog.current?.close();
  }, []);
  useEffect(() => {
    results.current?.scrollTo({ top: 0 });
  }, [query]);
  return (
    <dialog
      ref={dialog}
      className="roster-dialog clinical-product-dialog"
      aria-labelledby="clinical-picker-title"
      onCancel={(e) => {
        e.preventDefault();
        onClose();
      }}
    >
      <div className="roster-header">
        <div>
          <span className="eyebrow">
            CATÁLOGO OFICIAL · {products.length} PRODUCTOS
          </span>
          <h2 id="clinical-picker-title">Añadir medicamentos e insumos</h2>
        </div>
        <button
          className="quiet"
          aria-label="Cerrar catálogo clínico"
          onClick={onClose}
        >
          Cerrar ×
        </button>
      </div>
      <label className="field">
        <span>Nombre o código</span>
        <input
          aria-label="Buscar producto clínico"
          placeholder="Escribe o pega un nombre o código"
          autoComplete="off"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </label>
      <p className="picker-count" aria-live="polite">
        {matches.length} coincidencias ·{" "}
        {added
          ? added + " añadidos en esta selección"
          : "Puedes añadir varios productos"}
      </p>
      <div
        className="clinical-picker-results"
        role="list"
        aria-label="Catálogo clínico"
        ref={results}
      >
        {matches.map((p) => (
          <button
            role="listitem"
            className="result"
            key={p.code}
            onClick={() => {
              onSelect(p);
              setAdded((n) => n + 1);
            }}
          >
            <span>
              <b>{p.name}</b>
              <small>
                {p.unit} · {p.code}
              </small>
            </span>
            <span className="picker-add" aria-hidden="true">
              {counts.has(p.code) ? "×" + counts.get(p.code) + " ＋" : "＋"}
            </span>
          </button>
        ))}
        {!matches.length && (
          <div className="empty">
            Sin coincidencias. Prueba otra parte del nombre o el código.
          </div>
        )}
      </div>
      <div className="picker-footer">
        <small aria-live="polite">{items.length} líneas en esta atención</small>
        <button onClick={onClose}>Listo · volver al tratamiento</button>
      </div>
    </dialog>
  );
}
