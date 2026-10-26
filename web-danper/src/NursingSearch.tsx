import { useState } from "react";
import { nursingCatalog } from "./nursingCatalog";
import { normalize } from "./model";

export function NursingSearch({
  value,
  onChange,
}: {
  value: string;
  onChange: (id: string) => void;
}) {
  const [query, setQuery] = useState(
    nursingCatalog.find((p) => p.id === value)?.name || "",
  );
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(-1);
  const terms = normalize(query).split(" ");
  const matches = query.trim()
    ? nursingCatalog
        .filter((p) => terms.every((t) => normalize(p.name).includes(t)))
        .slice(0, 15)
    : [];
  const choose = (p: (typeof nursingCatalog)[number]) => {
    setQuery(p.name);
    onChange(p.id);
    setOpen(false);
    setActive(-1);
  };
  return (
    <div className="nursing-search">
      <label className="field">
        <span>Producto oficial de enfermería</span>
        <input
          role="combobox"
          aria-label="Producto oficial de enfermería"
          aria-autocomplete="list"
          aria-expanded={open && matches.length > 0}
          aria-controls="nursing-suggestions"
          aria-activedescendant={
            active >= 0 ? "nursing-option-" + active : undefined
          }
          autoComplete="off"
          placeholder="Escribe o pega el nombre del producto"
          value={query}
          onFocus={() => setOpen(true)}
          onBlur={(e) => {
            if (
              !e.currentTarget.parentElement?.parentElement?.contains(
                e.relatedTarget,
              )
            )
              setOpen(false);
          }}
          onChange={(e) => {
            setQuery(e.target.value);
            onChange("");
            setActive(-1);
            setOpen(true);
          }}
          onKeyDown={(e) => {
            if (e.key === "Escape") {
              setOpen(false);
              setActive(-1);
            }
            if (["ArrowDown", "ArrowUp"].includes(e.key)) {
              e.preventDefault();
              setOpen(true);
              setActive((i) =>
                e.key === "ArrowDown"
                  ? Math.min(matches.length - 1, i + 1)
                  : Math.max(0, i - 1),
              );
            }
            if (e.key === "Enter" && open && active >= 0 && matches[active]) {
              e.preventDefault();
              choose(matches[active]);
            }
          }}
        />
      </label>
      {open && !!query.trim() && (
        <div
          id="nursing-suggestions"
          role="listbox"
          aria-label="Sugerencias de enfermería"
          className="catalog-results"
        >
          {matches.map((p, i) => (
            <button
              type="button"
              role="option"
              aria-selected={i === active}
              id={"nursing-option-" + i}
              className="result"
              key={p.id}
              onMouseDown={(e) => e.preventDefault()}
              onClick={() => choose(p)}
            >
              <b>{p.name}</b>
              <small>
                {p.unit
                  ? "Presentación: " + p.unit
                  : "Presentación por verificar"}
              </small>
            </button>
          ))}
          {!matches.length && (
            <p className="muted">
              Sin coincidencias en los 98 productos oficiales.
            </p>
          )}
        </div>
      )}
    </div>
  );
}
