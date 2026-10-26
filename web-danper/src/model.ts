import { clinician } from "./clinician";
import type { WorkerRecord } from "../legacy/workerRules";
import type { ExportVisit } from "../legacy/ambulatoryRows";
export type Worker = WorkerRecord & { birthDate?: string; active?: boolean };
export type Allergy = {
  dni: string;
  reviewed: boolean;
  status: "unknown" | "none" | "known";
  substances: string;
};
export type Item = ExportVisit["items"][number] & {
  procedureConfirmed: boolean;
  procedureSource: string;
  inventoryCode?: string;
  selectedLotID?: string;
  physicalQuantity?: number;
  newContainers?: number;
  approveOpening?: boolean;
  closePriorContainer?: boolean;
  physicalReview?: boolean;
  reusePreviouslyOpened?: boolean;
};
export type Visit = Omit<ExportVisit, "items" | "worker"> & {
  worker: Worker;
  items: Item[];
  photoReviewed: boolean;
  dispensingSite: string;
  procedures: string[];
  pending?: { itemId: string; reason: string }[];
};
export type Draft = Visit & { step: number; allergy: Allergy };
export type Lot = {
  id: string;
  code: string;
  name: string;
  catalogUnit: string;
  lot: string;
  expires: string;
  container: string;
  unitsPerContainer: number;
  sealedContainers: number;
  looseUnits: number;
  openedRemaining: number;
  declaredOpenContainers: number;
  volumeTrackingEnabled: boolean;
  updatedAt: number;
  minimum?: number;
};
export type Movement = {
  id: string;
  lotId: string;
  code: string;
  name: string;
  unit: string;
  kind: "use" | "extraordinary" | "adjustment" | "containerState";
  at: number;
  quantity: number;
  excelQuantity: number;
  physicalChange: number;
  openedNewContainer: boolean;
  sealedAdded: number;
  looseAdded: number;
  before: Lot;
  after: Lot;
  description: string;
  operatorName: string;
  operatorDni?: string;
  declaredOpenings?: number;
  containerAccountingVersion?: number;
  closedContainers?: number;
  containerDisposition?: string;
  declaredExhaustedByNewOpening?: boolean;
  dispenseRef?: {
    attentionId: string;
    itemId: string;
    clinicalCode: string;
    clinicalName: string;
    clinicalUnit: string;
    clinicalQuantity: number;
    confirmedAt: number;
    partIndex?: number;
    partCount?: number;
    reusePreviouslyOpened?: boolean;
  };
};
export type Exam = {
  id: string;
  dni: string;
  name: string;
  date: string;
  result: string;
  type: string;
  profile: string;
  area: string;
  labor: string;
  nextDate: string;
  campaign: string;
  selected: boolean;
  source: string;
  verified: boolean;
  templateRow?: number;
};
export type Leave = {
  id: string;
  dni: string;
  start: string;
  end: string;
  diagnosis: string;
  document: string;
  followUp: string;
};
export type AlertState = { id: string; done: boolean };
export const collections = [
  "workers",
  "allergies",
  "attentions",
  "clinicalItems",
  "drafts",
  "lots",
  "movements",
  "mappings",
  "reconciliations",
  "emo",
  "cholinesterase",
  "leaves",
  "alerts",
  "corrections",
  "syncMeta",
] as const;
export type Collection = (typeof collections)[number];
export type Entity<T = unknown> = {
  key: string;
  collection: Collection;
  id: string;
  revision: number;
  data: T;
  operationId: string;
};
export type Change = {
  collection: Collection;
  id: string;
  expectedRevision: number;
  data: unknown;
};
export type Operation = {
  id: string;
  deviceId: string;
  createdAt: number;
  changes: Change[];
  state: "pending" | "conflict";
  error?: string;
};
export const key = (collection: Collection, id: string) =>
  collection + ":" + id;
export const normalize = (s: string) =>
  s
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .trim()
    .replace(/\s+/g, " ")
    .toUpperCase();
export function limaDay(ms = Date.now()) {
  const p = new Intl.DateTimeFormat("en-CA", {
    timeZone: "America/Lima",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(ms);
  return ["year", "month", "day"]
    .map((k) => p.find((x) => x.type === k)!.value)
    .join("-");
}
export function cutPeriod(day: string) {
  if (
    !/^\d{4}-\d{2}-\d{2}$/.test(day) ||
    new Date(day + "T12:00:00Z").toISOString().slice(0, 10) !== day
  )
    throw Error("Fecha de corte inválida");
  const [y, m, d] = day.split("-").map(Number);
  const start = new Date(Date.UTC(y, m - 1 - (d < 9 ? 1 : 0), 9));
  const end = new Date(
    Date.UTC(start.getUTCFullYear(), start.getUTCMonth() + 1, 8),
  );
  return {
    start: start.toISOString().slice(0, 10),
    end: end.toISOString().slice(0, 10),
  };
}
export function emptyDraft(): Draft {
  const worker: Worker = {
    dni: "",
    name: "",
    area: "",
    labor: "",
    sex: "",
    age: "",
    ubigeo: "",
    site: "LA VENTUROSA",
  };
  return {
    id: crypto.randomUUID(),
    status: "draft",
    date: limaDay(),
    time: new Intl.DateTimeFormat("en-GB", {
      timeZone: "America/Lima",
      hour: "2-digit",
      minute: "2-digit",
    }).format(Date.now()),
    worker,
    category: "",
    system: "",
    segment: "",
    diagnosis: "",
    items: [],
    permission: "NO",
    workStatus: "LABORANDO",
    permissionTime: "",
    blueBandage: false,
    returned: false,
    photoSent: false,
    photoReviewed: false,
    responsible: clinician.name,
    responsibleDni: clinician.dni,
    standaloneProcedures: [],
    procedures: [],
    dispensingSite: "LA VENTUROSA",
    step: 0,
    allergy: { dni: "", reviewed: false, status: "unknown", substances: "" },
  };
}
