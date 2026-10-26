import { LocalStore } from "./storage";
import {
  emptyDraft,
  limaDay,
  type Change,
  type Lot,
  type Visit,
  type Worker,
} from "./model";
import { nursingCatalog } from "./nursingCatalog";
import products from "../legacy/products.json";
import { saveClinical } from "./accounting";

// Synthetic records only. No imported patient data or production storage access.
export function trialData(now = Date.now()) {
  const workers: Worker[] = [
    "ANA PRUEBA FICTICIA",
    "LUIS PRUEBA FICTICIA",
    "MARIA PRUEBA FICTICIA",
  ].map((name, i) => ({
    dni: "0000000" + (i + 1),
    name,
    area: i === 1 ? "ADMINISTRACION DE PRODUCCION" : "PRODUCCION",
    labor: "PUESTO FICTICIO",
    sex: i === 1 ? "M" : "F",
    age: "30",
    birthDate: "1996-01-01",
    site: i === 1 ? "PLVENTUROSA" : "LA VENTUROSA",
    ubigeo: "",
    source: "manual",
  }));
  const product = nursingCatalog.find((p) => p.id === "E-22")!;
  const lot: Lot = {
    id: "trial-lot-paracetamol",
    code: product.id,
    name: product.name,
    catalogUnit: product.unit,
    lot: "FICTICIO-001",
    expires: "2035-12-31",
    container: "unidad",
    unitsPerContainer: 1,
    sealedContainers: 20,
    looseUnits: 0,
    openedRemaining: 0,
    declaredOpenContainers: 0,
    volumeTrackingEnabled: false,
    updatedAt: now - 10000,
  };
  const clinical = products.find((p) => p.code === "16000182")!;
  const first: Visit = {
    ...emptyDraft(),
    id: "trial-attention-1",
    worker: workers[0],
    date: limaDay(now),
    time: "08:00",
    category: "ENFERMEDAD",
    system: "OSTEOMUSCULAR",
    segment: "ZONA LUMBAR",
    diagnosis: "REGISTRO FICTICIO PARA PROBAR HISTORIAL Y EXPORTACIONES",
    items: [
      {
        id: "trial-item-1",
        code: clinical.code,
        name: clinical.name,
        unit: clinical.unit,
        quantity: 2,
        procedure: "OBSERVACION",
        procedureConfirmed: true,
        procedureSource: "manual",
      },
    ],
    procedures: ["OBSERVACION"],
  };
  const result = saveClinical(first, [lot], [], now);
  const second: Visit = {
    ...emptyDraft(),
    id: "trial-attention-2",
    worker: workers[1],
    date: limaDay(now),
    time: "09:00",
    category: "OTROS",
    diagnosis: "ATENCION FICTICIA SIN PRODUCTOS",
    items: [],
    status: "saved",
    pending: [],
    procedures: ["OBSERVACION"],
  };
  const changes: Change[] = [
    ...workers.map((w) => ({
      collection: "workers" as const,
      id: w.dni,
      expectedRevision: 0,
      data: w,
    })),
    ...result.lots.map((l) => ({
      collection: "lots" as const,
      id: l.id,
      expectedRevision: 0,
      data: l,
    })),
    ...[result.visit, second].map((v) => ({
      collection: "attentions" as const,
      id: v.id,
      expectedRevision: 0,
      data: v,
    })),
    ...result.movements.map((m) => ({
      collection: "movements" as const,
      id: m.id,
      expectedRevision: 0,
      data: m,
    })),
  ];
  return {
    schema: "danper-synthetic-trial-1",
    workers,
    visits: [result.visit, second],
    lots: result.lots,
    movements: result.movements,
    changes,
  };
}

export async function loadTrial() {
  const target = await new LocalStore().open("danper-web-trial-v1");
  try {
    if (
      (await target.all("workers")).length ||
      (await target.all("attentions")).length ||
      (await target.all("lots")).length
    )
      return; // Re-enter the existing trial without overwriting the user's experiments.
    await target.commit(trialData().changes, "synthetic-local-trial", false);
  } finally {
    target.close();
  }
}
