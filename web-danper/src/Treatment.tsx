import { useState } from "react";
import contract from "./generated/contract.json";
import { inferProcedure } from "../legacy/procedureRules";
import { ClinicalProductPicker } from "./ClinicalProductPicker";
import { Check, Text, Select, Field } from "./main";
import { candidates, isContainer } from "./accounting";
import type { Draft, Item, Lot } from "./model";
export function Treatment({
  d,
  lots,
  update,
  patchItem,
  catalogOpen,
  setCatalogOpen,
}: {
  d: Draft;
  lots: Lot[];
  update: (patch: Partial<Draft>) => void;
  patchItem: (id: string, patch: Partial<Item>) => void;
  catalogOpen: boolean;
  setCatalogOpen: (open: boolean) => void;
}) {
  const [expandedID, setExpandedID] = useState<string | null>(null);
  const hasContainer = (item: Item) =>
    lots.some(
      (l) =>
        candidates(item).some((c) => c.kardexCode === l.code) &&
        isContainer(l.catalogUnit),
    );
  const collapseItem = (id: string) => {
    setExpandedID(null);
    requestAnimationFrame(() =>
      document
        .querySelector<HTMLElement>('[data-item-id="' + id + '"]>summary')
        ?.focus(),
    );
  };
  const otherProcedures = d.procedures.filter(
    (p) => p !== "CURACION DE HERIDA",
  );
  return (
    <div className="treatment-compact">
      <div className="independent-procedures">
        <div className="compact-heading">
          <h3>Procedimientos independientes</h3>
          <small>Opcional · sin medicamento</small>
        </div>
        <div className="procedure-options">
          <Check
            label="CURACION DE HERIDA"
            value={d.procedures.includes("CURACION DE HERIDA")}
            onChange={(v) =>
              update({
                procedures: v
                  ? [...d.procedures, "CURACION DE HERIDA"]
                  : d.procedures.filter((p) => p !== "CURACION DE HERIDA"),
              })
            }
          />
          <details className="other-procedures">
            <summary>
              Otros procedimientos{" "}
              {!!otherProcedures.length && (
                <span className="badge">{otherProcedures.length}</span>
              )}
            </summary>
            <div className="procedure-chips">
              {contract.procedures
                .filter((p) => p !== "CURACION DE HERIDA")
                .map((p) => (
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
          </details>
        </div>
        {!!otherProcedures.length && (
          <p className="procedure-summary">{otherProcedures.join(" · ")}</p>
        )}
      </div>
      <div className="medication-toolbar">
        <div>
          <h3>Medicamentos e insumos</h3>
          <small>
            {d.items.length
              ? d.items.length + " líneas seleccionadas"
              : "Sin productos · opcional"}
          </small>
        </div>
        <button
          aria-label="Añadir medicamento o insumo"
          aria-haspopup="dialog"
          onClick={() => setCatalogOpen(true)}
        >
          <span aria-hidden="true">＋ </span>
          <span className="add-product-full">Añadir medicamento o insumo</span>
          <span className="add-product-short" aria-hidden="true">
            Añadir
          </span>
        </button>
      </div>
      <div className="medication-lines">
        {d.items.map((item) => (
          <details
            className="medication-row"
            key={item.id}
            data-item-id={item.id}
            open={expandedID === item.id}
            onToggle={(e) => {
              if (e.currentTarget.open) setExpandedID(item.id);
              else setExpandedID((old) => (old === item.id ? null : old));
            }}
          >
            <summary className="medication-summary">
              <span className="medication-chevron" aria-hidden="true">
                ›
              </span>
              <span className="medication-description">
                <strong>{item.name}</strong>
                <small>
                  {item.quantity} {item.unit} ·{" "}
                  {item.procedure || "Procedimiento pendiente"}
                </small>
              </span>
              <span
                className={
                  "medication-status " +
                  (item.procedureConfirmed ? "confirmed" : "pending")
                }
              >
                {item.procedureConfirmed ? "Confirmado" : "Por confirmar"}
              </span>
              <button
                className="quiet"
                onClick={(e) => {
                  e.preventDefault();
                  update({ items: d.items.filter((i) => i.id !== item.id) });
                }}
              >
                Quitar
              </button>
            </summary>
            <div className="medication-editor">
              <div className="grid">
                <Text
                  label={"Cantidad clínica (" + item.unit + ")"}
                  type="number"
                  value={String(item.quantity)}
                  onChange={(v) => patchItem(item.id, { quantity: Number(v) })}
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
              </div>
              <details className="physical-details">
                <summary>
                  Inventario ·{" "}
                  {item.selectedLotID ? "lote seleccionado" : "FEFO automático"}
                </summary>{" "}
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
              </details>
              <Check
                label="Confirmo el procedimiento realizado"
                value={item.procedureConfirmed}
                onChange={(v) => {
                  patchItem(item.id, { procedureConfirmed: v });
                  if (v && !hasContainer(item)) collapseItem(item.id);
                }}
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
              <button
                className="quiet close-medication"
                onClick={() => collapseItem(item.id)}
              >
                Cerrar detalle
              </button>
            </div>
          </details>
        ))}
      </div>
      {catalogOpen && (
        <ClinicalProductPicker
          items={d.items}
          onClose={() => setCatalogOpen(false)}
          onSelect={(p) => {
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
          }}
        />
      )}
    </div>
  );
}
