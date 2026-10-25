import contract from "./generated/contract.json";
import { reviewedAssociations } from "../legacy/reviewedKardexAssociations";
import {
  limaDay,
  type Lot,
  type Movement,
  type Visit,
  type Item,
} from "./model";
export const isContainer = (unit: string) =>
  !!unit && !["UND", "TBL", "PAR", "ML", "LT"].includes(unit.toUpperCase());
export const openCount = (lot: Lot) =>
  lot.declaredOpenContainers ?? (lot.openedRemaining > 0 ? 1 : 0);
export const physical = (l: Lot) =>
  l.sealedContainers * l.unitsPerContainer + l.openedRemaining + l.looseUnits;
export const reportBalance = (l: Lot) =>
  !["UND", "TBL", "PAR"].includes(l.catalogUnit.toUpperCase())
    ? l.sealedContainers
    : physical(l);
const round = (n: number) => Math.round(n * 1000) / 1000;
export function validateLot(l: Lot) {
  if (!l.id || !l.code || !l.name || !l.catalogUnit || !l.lot)
    throw Error("Lote sin identidad o presentación");
  for (const v of [
    l.sealedContainers,
    l.declaredOpenContainers,
    l.unitsPerContainer,
  ])
    if (!Number.isSafeInteger(v) || v < 0 || v > 10_000_000)
      throw Error("Cantidad de envases inválida");
  for (const v of [l.openedRemaining, l.looseUnits])
    if (!Number.isFinite(v) || v < 0 || v > 10_000_000)
      throw Error("Contenido físico inválido");
  if (l.unitsPerContainer < 1) throw Error("Verifica la capacidad física");
  if (
    !Number.isSafeInteger(l.updatedAt) ||
    l.updatedAt < 0 ||
    l.openedRemaining > l.unitsPerContainer
  )
    throw Error("Estado del lote inválido");
  if (
    l.expires &&
    (!/^\d{4}-\d{2}-\d{2}$/.test(l.expires) ||
      new Date(l.expires + "T12:00:00Z").toISOString().slice(0, 10) !==
        l.expires)
  )
    throw Error("Vencimiento inválido");
  return l;
}
export function planContainer(
  before: Lot,
  openings: number,
  volume: number,
  at: number,
): Lot | null {
  if (
    !isContainer(before.catalogUnit) ||
    !Number.isInteger(openings) ||
    openings < 0 ||
    openings > 10000 ||
    !Number.isFinite(volume) ||
    volume < 0 ||
    before.sealedContainers < openings ||
    openCount(before) + openings <= 0 ||
    at < before.updatedAt
  )
    return null;
  if (!before.volumeTrackingEnabled && volume > 0) return null;
  const available =
    before.openedRemaining +
    before.looseUnits +
    openings * before.unitsPerContainer;
  if (volume > available) return null;
  const remaining = available - volume;
  return {
    ...before,
    sealedContainers: before.sealedContainers - openings,
    openedRemaining: Math.min(before.unitsPerContainer, remaining),
    looseUnits: Math.max(0, remaining - before.unitsPerContainer),
    declaredOpenContainers: openCount(before) + openings,
    updatedAt: at,
  };
}
export function closeContainer(
  lot: Lot,
  count: number,
  disposition: string,
  operatorName: string,
  reason: string,
  at = Date.now(),
  id: string = crypto.randomUUID(),
): Movement {
  if (
    !isContainer(lot.catalogUnit) ||
    !Number.isInteger(count) ||
    count < 1 ||
    count > openCount(lot) ||
    !["agotado", "cerrado", "descartado"].includes(disposition) ||
    reason.trim().length < 10 ||
    operatorName.trim().length < 3 ||
    at < lot.updatedAt
  )
    throw Error(
      "Revisa cantidad, estado, responsable y motivo (10 caracteres)",
    );
  return {
    id,
    lotId: lot.id,
    code: lot.code,
    name: lot.name,
    unit: lot.catalogUnit,
    kind: "containerState",
    at,
    quantity: 0,
    excelQuantity: 0,
    physicalChange: 0,
    openedNewContainer: false,
    sealedAdded: 0,
    looseAdded: 0,
    before: lot,
    after: {
      ...lot,
      declaredOpenContainers: openCount(lot) - count,
      volumeTrackingEnabled: false,
      updatedAt: at,
    },
    description: reason,
    operatorName,
    closedContainers: count,
    containerDisposition: disposition,
    containerAccountingVersion: 1,
  };
}
export type OperationalLink = {
  clinicalCode: string;
  clinicalName: string;
  clinicalUnit: string;
  inventoryID: string;
  inventoryName: string;
  confirmedAt: number;
  id: string;
  version: number;
};
export function candidates(item: Item, operational: OperationalLink[] = []) {
  const op = operational.find(
    (x) =>
      x.clinicalCode === item.code &&
      x.clinicalName === item.name &&
      x.clinicalUnit === item.unit,
  );
  return op
    ? [
        {
          kardexCode: op.inventoryID,
          kardexName: op.inventoryName,
          requiresPhysicalReview: false,
        },
      ]
    : [...reviewedAssociations, ...contract.additional].filter(
        (x) =>
          x.clinicalCode === item.code &&
          x.clinicalName === item.name &&
          x.clinicalUnit === item.unit,
      );
}
export function saveClinical(
  visit: Visit,
  lots: Lot[],
  existing: Movement[],
  now = Date.now(),
  operational: OperationalLink[] = [],
) {
  lots.forEach(validateLot);
  let stock = structuredClone(lots);
  const movements: Movement[] = [];
  const pending: { itemId: string; reason: string }[] = [];
  const historical = visit.date !== limaDay(now),
    eventAt = historical
      ? Date.parse(visit.date + "T" + visit.time + ":00-05:00")
      : now;
  for (const item of visit.items) {
    const prefix = "ATT:" + visit.id + ":ITEM:" + item.id;
    if (
      existing.some(
        (m) =>
          m.dispenseRef?.attentionId === visit.id &&
          m.dispenseRef.itemId === item.id,
      )
    )
      continue;
    const fail = (reason: string) => pending.push({ itemId: item.id, reason });
    const links = candidates(item, operational);
    const codes = new Set(links.map((c) => c.kardexCode));
    if (!links.length) {
      fail("Sin correspondencia verificada");
      continue;
    }
    const selected = item.selectedLotID || item.physicalUse?.lotId;
    if (!selected && codes.size > 1) {
      fail("Selecciona la presentación física");
      continue;
    }
    let eligible = stock.filter(
      (l) => codes.has(l.code) && (!l.expires || l.expires >= visit.date),
    );
    if (historical) {
      eligible = eligible.filter(
        (l) =>
          l.updatedAt <= eventAt &&
          !existing.some((m) => m.lotId === l.id && m.at > eventAt),
      );
    }
    if (!Number.isFinite(eventAt) || eventAt > now || !eligible.length) {
      fail(
        historical
          ? "Lote posterior a la atención o con eventos posteriores; requiere conciliación histórica"
          : "Sin existencias verificables",
      );
      continue;
    }
    const chosen = eligible.find((l) => l.id === selected);
    if (selected && !chosen) {
      fail("Lote seleccionado no verificable");
      continue;
    }
    if (
      links.some(
        (l) => "requiresPhysicalReview" in l && l.requiresPhysicalReview,
      ) &&
      !chosen
    ) {
      fail("Presentación adicional: selecciona el lote físico verificado");
      continue;
    }
    const code = chosen?.code || links[0].kardexCode;
    eligible = eligible
      .filter((l) => l.code === code)
      .sort(
        (a, b) =>
          (a.expires || "9999-12-31").localeCompare(
            b.expires || "9999-12-31",
          ) || a.id.localeCompare(b.id),
      );
    const unit = chosen?.catalogUnit || eligible[0]?.catalogUnit;
    if (
      !unit ||
      (new Set(eligible.map((l) => l.catalogUnit)).size > 1 && !chosen)
    ) {
      fail("Presentaciones incompatibles: selecciona lote");
      continue;
    }
    const container = isContainer(unit),
      individual = ["UND", "TBL", "PAR"].includes(item.unit.toUpperCase());
    if (individual && !container)
      eligible = eligible.filter((l) =>
        item.unit === "PAR"
          ? l.catalogUnit === "PAR"
          : ["UND", "TBL"].includes(l.catalogUnit),
      );
    let quantity = container
      ? (item.physicalQuantity ?? item.physicalUse?.quantity ?? 0)
      : individual
        ? item.quantity
        : (item.physicalQuantity ?? item.physicalUse?.quantity ?? 0);
    if (
      !Number.isFinite(quantity) ||
      quantity < 0 ||
      (!container && quantity <= 0)
    ) {
      fail("Cantidad física no verificada");
      continue;
    }
    let probe = structuredClone(eligible),
      closures: Movement[] = [];
    const parts: {
      before: Lot;
      after: Lot;
      quantity: number;
      r: number;
      opened: boolean;
      reuse?: boolean;
    }[] = [];
    if (container) {
      let openings = item.approveOpening ? (item.newContainers ?? 0) : 0;
      if (
        !Number.isInteger(openings) ||
        openings < 0 ||
        openings > 10000 ||
        (item.approveOpening && openings === 0)
      ) {
        fail("Confirma los envases abiertos");
        continue;
      }
      if (openings > 0 && item.closePriorContainer) {
        const active = stock.filter((l) => l.code === code && openCount(l) > 0);
        if (
          historical ||
          active.length !== 1 ||
          openCount(active[0]) !== 1 ||
          active[0].volumeTrackingEnabled ||
          active[0].looseUnits !== 0
        ) {
          fail("Agotamiento anterior no verificable");
          continue;
        }
        const before = active[0];
        const event = closeContainer(
          before,
          1,
          "agotado",
          visit.responsible,
          "Agotamiento del envase anterior confirmado al abrir uno nuevo",
          eventAt,
          prefix + ":PREVIOUS-EXHAUSTED:" + before.id,
        );
        event.after = { ...event.after, openedRemaining: 0, looseUnits: 0 };
        event.physicalChange = -before.openedRemaining;
        event.declaredExhaustedByNewOpening = true;
        closures = [event];
        probe = probe.map((l) => (l.id === before.id ? event.after : l));
      }
      const active = probe.find((l) => openCount(l) > 0);
      if (
        openings === 0 &&
        item.reusePreviouslyOpened &&
        !active &&
        !historical
      ) {
        const before = probe.find((l) => l.sealedContainers > 0);
        if (before)
          parts.push({
            before,
            after: { ...before, updatedAt: eventAt },
            quantity: 0,
            r: 0,
            opened: false,
            reuse: true,
          });
      } else if (openings === 0) {
        const before =
          (item.reusePreviouslyOpened
            ? active
            : probe.find((l) => l.id === selected)) || active;
        const after = before && planContainer(before, 0, quantity, eventAt);
        if (before && after)
          parts.push({ before, after, quantity, r: 0, opened: false });
      } else {
        let remaining = openings,
          vol = quantity;
        for (const before of probe.filter(
          (l) => !selected || l.id === selected,
        )) {
          const n = Math.min(remaining, before.sealedContainers);
          if (!n) continue;
          const use = before.volumeTrackingEnabled
            ? Math.min(
                vol,
                before.openedRemaining +
                  before.looseUnits +
                  n * before.unitsPerContainer,
              )
            : 0;
          const after = planContainer(before, n, use, eventAt);
          if (!after) break;
          parts.push({ before, after, quantity: use, r: n, opened: true });
          remaining -= n;
          vol -= use;
          if (!remaining) break;
        }
        if (remaining || Math.abs(vol) > 0.000001) parts.length = 0;
      }
    } else {
      if (eligible.reduce((s, l) => s + physical(l), 0) + 0.00001 < quantity) {
        fail("Stock FEFO insuficiente");
        continue;
      }
      let remaining = quantity;
      for (const before of eligible) {
        if (remaining <= 0) break;
        const take = round(Math.min(remaining, physical(before)));
        if (!take) continue;
        const after = { ...before, updatedAt: eventAt };
        let left = take;
        let n = Math.min(left, after.looseUnits);
        after.looseUnits = round(after.looseUnits - n);
        left = round(left - n);
        n = Math.min(left, after.openedRemaining);
        after.openedRemaining = round(after.openedRemaining - n);
        left = round(left - n);
        let opened = false;
        if (left > 0) {
          const needed = Math.ceil(left / after.unitsPerContainer);
          if (needed > after.sealedContainers) {
            parts.length = 0;
            break;
          }
          after.sealedContainers -= needed;
          after.openedRemaining = round(
            needed * after.unitsPerContainer - left,
          );
          opened = after.unitsPerContainer > 1;
        }
        parts.push({
          before,
          after,
          quantity: take,
          r: individual ? take : 0,
          opened,
        });
        remaining = round(remaining - take);
      }
    }
    if (!parts.length || parts.length > 150) {
      fail("Apertura o cantidad física pendiente de verificar");
      continue;
    }
    for (const m of closures) {
      stock = stock.map((l) => (l.id === m.lotId ? m.after : l));
      movements.push(m);
    }
    parts.forEach((p, i) => {
      const ref = {
        attentionId: visit.id,
        itemId: item.id,
        clinicalCode: item.code,
        clinicalName: item.name,
        clinicalUnit: item.unit,
        clinicalQuantity: item.quantity,
        confirmedAt: eventAt,
        ...(parts.length > 1
          ? { partIndex: i + 1, partCount: parts.length }
          : {}),
        ...(p.reuse ? { reusePreviouslyOpened: true } : {}),
      };
      const m: Movement = {
        id: prefix + (parts.length > 1 ? ":PART:" + (i + 1) : ""),
        lotId: p.before.id,
        code: p.before.code,
        name: p.before.name,
        unit: p.before.catalogUnit,
        kind: "use",
        at: eventAt,
        quantity: p.quantity,
        excelQuantity: p.r,
        physicalChange: p.quantity === 0 ? 0 : -p.quantity,
        openedNewContainer: p.opened,
        sealedAdded: 0,
        looseAdded: 0,
        before: p.before,
        after: p.after,
        description: container
          ? "Apertura declarada / uso de envase abierto"
          : "Dispensación clínica FEFO",
        operatorName: visit.responsible,
        dispenseRef: ref,
        ...(container
          ? { containerAccountingVersion: 1, declaredOpenings: p.r }
          : {}),
        ...(p.reuse ? { reuseWithoutRecordedOpening: true } : {}),
      };
      stock = stock.map((l) => (l.id === p.before.id ? p.after : l));
      movements.push(m);
    });
  }
  return {
    visit: { ...visit, status: "saved" as const, pending },
    lots: stock,
    movements,
  };
}
export function postInventory(
  before: Lot,
  kind: "extraordinary" | "adjustment",
  sealed: number,
  loose: number,
  operatorName: string,
  reason: string,
  at = Date.now(),
): Movement {
  if (
    operatorName.trim().length < 3 ||
    reason.trim().length < 10 ||
    at < before.updatedAt
  )
    throw Error("Indica responsable y motivo de al menos 10 caracteres");
  const after = validateLot({
    ...before,
    sealedContainers:
      kind === "extraordinary" ? before.sealedContainers + sealed : sealed,
    looseUnits: kind === "extraordinary" ? before.looseUnits + loose : loose,
    updatedAt: at,
  });
  if (
    kind === "extraordinary" &&
    (sealed < 0 || loose < 0 || sealed + loose <= 0)
  )
    throw Error("Ingreso inválido");
  return {
    id: crypto.randomUUID(),
    lotId: before.id,
    code: before.code,
    name: before.name,
    unit: before.catalogUnit,
    kind,
    at,
    quantity: 0,
    excelQuantity: 0,
    physicalChange: round(physical(after) - physical(before)),
    openedNewContainer: false,
    sealedAdded: kind === "extraordinary" ? sealed : 0,
    looseAdded: kind === "extraordinary" ? loose : 0,
    before,
    after,
    description: reason,
    operatorName,
  };
}
