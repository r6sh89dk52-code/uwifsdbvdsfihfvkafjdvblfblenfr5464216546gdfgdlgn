import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import { DOMParser, XMLSerializer } from "@xmldom/xmldom";
import { unzipSync, strFromU8 } from "fflate";
import "fake-indexeddb/auto";
import products from "../legacy/products.json";
import { kardexCatalog } from "../legacy/kardexCatalog";
import contract from "../src/generated/contract.json";
import { reviewedAssociations } from "../legacy/reviewedKardexAssociations";
import { compileWorkers, reconcileWorkers } from "../legacy/workerRules";
import { validateClinicalStage } from "../legacy/attentionStepValidation";
import { LocalStore } from "../src/storage";
import {
  planContainer,
  saveClinical,
  closeContainer,
  postInventory,
} from "../src/accounting";
import {
  emptyDraft,
  cutPeriod,
  limaDay,
  type Lot,
  type Visit,
} from "../src/model";
import {
  indicatorPlan,
  exportIndicator,
  nursingReport,
  patchTemplateDates,
  previewExams,
  projectedConsumption,
  inspectWorkbook,
} from "../src/workbooks";
import { exportOfficialKardex } from "../legacy/kardexExcelTemplate";
import template from "../legacy/ambulatoryTemplate.json";
import { exportVigilance } from "../src/vigilance";
import { exportDataSheet } from "../src/dataExport";
import vigilance from "../src/generated/vigilance.json";
import {encryptPortableBackup,decryptPortableBackup} from '../legacy/portableBackup';
Object.assign(globalThis, { DOMParser, XMLSerializer });
test('Base de campaña: selección explícita sin fabricar resultado ni periodicidad',async()=>{
 const sheet={name:'BASE',part:'xl/worksheets/sheet1.xml',rows:[{row:2,values:{A:'00000001',B:'CAMPAÑA FICTICIA',C:'2026-11-15'}}]};
 const mapping={dni:'A',name:'',date:'',result:'',type:'',profile:'',area:'',labor:'',nextDate:'C',campaign:'B'};
 const result=await previewExams(sheet,mapping,[visit().worker],'cholinesterase',1,'campaign');
 assert.equal(result.exams.length,1);assert.equal(result.exams[0].verified,false);assert.equal(result.exams[0].selected,true);assert.equal(result.exams[0].result,'PENDIENTE');assert.equal(result.exams[0].date,'');assert.equal(result.exams[0].nextDate,'2026-11-15');
});
test('Respaldo portátil cifrado: round-trip local, contraseña errónea y manipulación rechazadas',async()=>{
 const snapshot={workers:[visit().worker],attentions:[visit()],stockLots:[lot()],stockMovements:[]};const pass='CONTRASEÑA FICTICIA PARA PRUEBAS';
 const encrypted=await encryptPortableBackup(snapshot,pass);assert(!encrypted.includes('PERSONA FICTICIA'));assert.deepEqual(await decryptPortableBackup(encrypted,pass),snapshot);await assert.rejects(decryptPortableBackup(encrypted,'OTRA CONTRASEÑA FICTICIA'));const damaged=JSON.parse(encrypted);damaged.data=(damaged.data[0]==='A'?'B':'A')+damaged.data.slice(1);await assert.rejects(decryptPortableBackup(JSON.stringify(damaged),pass));
});
test("Vigilancia osteomuscular: encabezados y estilos Swift originales, DNI texto y códigos sin inferencia", () => {
  const v = visit();
  v.system = "OSTEOMUSCULAR";
  v.worker.area = "AREA NO REGISTRADA";
  const out = exportVigilance([v], "2026-11-01", "2026-11-30");
  assert.equal(out.rows, 1);
  assert.equal(out.unresolved, 1);
  const zip = unzipSync(out.bytes);
  assert.equal(strFromU8(zip["xl/styles.xml"]), vigilance.styles);
  const sheets = inspectWorkbook(out.bytes);
  assert.equal(sheets[0].name, "VIGILACIA OCUPACIONAL");
  assert.deepEqual(Object.values(sheets[0].rows[0].values), vigilance.headers);
  const row = sheets[0].rows[1].values;
  assert.equal(row.I, "00000001");
  assert.equal(row.C, "A071");
  assert.equal(row.D, "");
  assert.equal(row.M, "DISERGONOMICO");
  assert.equal(row.N, "Posturas inadecuadas");
  assert.equal(
    exportVigilance(
      [{ ...v, system: "RESPIRATORIO" }],
      "2026-11-01",
      "2026-11-30",
    ).rows,
    0,
  );
});
test("Exportación de datos explicita no interpreta texto como fórmula y conserva DNI", () => {
  const bytes = exportDataSheet(
    "DESCANSOS",
    ["DNI", "OBSERVACION"],
    [["00000001", "=1+1"]],
  );
  const sheet = inspectWorkbook(bytes)[0];
  assert.equal(sheet.name, "DESCANSOS");
  assert.equal(sheet.rows[1].values.A, "00000001");
  assert.equal(sheet.rows[1].values.B, "=1+1");
  assert(
    !strFromU8(unzipSync(bytes)["xl/worksheets/sheet1.xml"]).includes("<f>"),
  );
});
const at = Date.parse("2026-11-08T18:00:00Z");
function lot(overrides: Partial<Lot> = {}): Lot {
  return {
    id: "declared-bottles",
    code: "E-87",
    name: "ALCOHOL 120 ML",
    catalogUnit: "FCO",
    lot: "SYNTHETIC-DECLARATION",
    expires: "2027-12-31",
    container: "frasco",
    unitsPerContainer: 1,
    sealedContainers: 2,
    looseUnits: 0,
    openedRemaining: 0,
    declaredOpenContainers: 0,
    volumeTrackingEnabled: false,
    updatedAt: at - 86400000,
    ...overrides,
  };
}
function visit(
  id = "v",
  code = "E-87",
  openings = 1,
  day = "2026-11-08",
): Visit {
  const map = reviewedAssociations.find((m) => m.kardexCode === code)!;
  return {
    ...emptyDraft(),
    id,
    status: "saved",
    date: day,
    time: "13:00",
    category: "OTROS",
    diagnosis: "COMENTARIO FICTICIO",
    worker: {
      dni: "00000001",
      name: "PERSONA FICTICIA",
      area: "",
      labor: "",
      sex: "F",
      age: "30",
      ubigeo: "",
      site: "LA VENTUROSA",
    },
    responsible: "OPERADOR FICTICIO",
    responsibleDni: "00000002",
    procedures: ["OBSERVACION"],
    standaloneProcedures: ["OBSERVACION"],
    items: [
      {
        id: id + "-item",
        code: map.clinicalCode,
        name: map.clinicalName,
        unit: map.clinicalUnit,
        quantity: 1,
        procedure: "OBSERVACION",
        procedureConfirmed: true,
        procedureSource: "manual",
        approveOpening: openings > 0,
        newContainers: openings,
        physicalQuantity: 0,
      },
    ],
  };
}
test("Catálogos completos y opciones extraídas del Swift vigente", () => {
  assert.equal(products.length, 432);
  assert.equal(new Set(products.map((p) => p.code)).size, 432);
  assert.equal(kardexCatalog.length, 98);
  assert.equal(reviewedAssociations.length, 86);
  assert.equal(contract.additional.length, 6);
  assert.equal(contract.procedures.length, 12);
  assert.equal(contract.categories.length, 6);
  assert.equal(contract.systems.length, 13);
  assert.equal(
    new Set(
      [...reviewedAssociations, ...contract.additional].map(
        (m) => m.kardexCode,
      ),
    ).size,
    92,
  );
});
test("Validador nativo: sistemas condicionales, segmento y alergias", () => {
  const d = visit();
  const ctx = {
    validCategories: contract.categories,
    validSystems: contract.systems,
    rosterRequired: true,
    workerInRoster: true,
    rosterException: false,
    allergiesReviewed: true,
    allergyStatus: "none" as const,
    allergySubstances: "",
  };
  for (const category of contract.categories) {
    const errors = validateClinicalStage(1, { ...d, category }, ctx);
    assert.equal(
      errors.some((e) => e.field === "clinical-system"),
      [
        "ENFERMEDAD",
        "ACCIDENTE COMUN",
        "ACCIDENTE DE TRABAJO",
        "MATERNIDAD",
      ].includes(category),
    );
  }
  assert(
    validateClinicalStage(
      1,
      { ...d, category: "ENFERMEDAD", system: "OSTEOMUSCULAR" },
      ctx,
    ).some((e) => e.field === "clinical-segment"),
  );
  assert(
    validateClinicalStage(1, d, { ...ctx, allergiesReviewed: false }).some(
      (e) => e.field === "allergy-status",
    ),
  );
});
test("Fixture N3DeclaredContainerTests: R=1,0,0,1,0; dos envases declarados abiertos", () => {
  let lots = [lot()];
  let moves: ReturnType<typeof saveClinical>["movements"] = [];
  for (const [index, r] of [1, 0, 0, 1, 0].entries()) {
    const day = "2026-11-" + String(8 + index).padStart(2, "0");
    const result = saveClinical(
      visit("declared-" + index, "E-87", r, day),
      lots,
      moves,
      at + index * 86400000,
    );
    assert.equal(result.visit.pending.length, 0);
    assert.equal(
      result.movements.reduce((s, m) => s + m.excelQuantity, 0),
      r,
    );
    lots = result.lots;
    moves = [...moves, ...result.movements];
  }
  assert.equal(lots[0].sealedContainers, 0);
  assert.equal(lots[0].declaredOpenContainers, 2);
  assert.deepEqual(
    moves.map((m) => m.excelQuantity),
    [1, 0, 0, 1, 0],
  );
  assert.equal(
    nursingReport(lots, moves, "2026-11-08", "2026-11-12").rows.find(
      (r) => r.code === "E-87",
    )!.consumed,
    2,
  );
});
test("Apertura múltiple declarada, sin inferir cierre por volumen cero", () => {
  const before = lot({
    unitsPerContainer: 100,
    volumeTrackingEnabled: true,
    sealedContainers: 4,
  });
  const next = planContainer(before, 2, 200, at)!;
  assert.equal(next.sealedContainers, 2);
  assert.equal(next.openedRemaining, 0);
  assert.equal(next.declaredOpenContainers, 2);
  assert.equal(planContainer(next, 0, 0, at + 1)!.declaredOpenContainers, 2);
  assert.equal(planContainer(before, 5, 0, at), null);
});
test("R=0 atestado actual sin apertura registrada no inventa un movimiento físico", () => {
  const v = visit("reuse", "E-87", 0);
  v.items[0].reusePreviouslyOpened = true;
  const result = saveClinical(v, [lot()], [], at);
  assert.equal(result.movements.length, 1);
  assert.equal(result.movements[0].physicalChange, 0);
  assert.equal(result.lots[0].sealedContainers, 2);
  assert.equal(result.lots[0].declaredOpenContainers, 0);
});
test("Cierre de envase explícito auditado conserva R=0", () => {
  const l = lot({ declaredOpenContainers: 1 });
  const m = closeContainer(
    l,
    1,
    "agotado",
    "OPERADOR FICTICIO",
    "Agotamiento confirmado en prueba",
    at,
  );
  assert.equal(m.excelQuantity, 0);
  assert.equal(m.after.declaredOpenContainers, 0);
  assert.equal(m.after.sealedContainers, 2);
  assert.throws(() =>
    closeContainer(
      l,
      2,
      "agotado",
      "OPERADOR FICTICIO",
      "Motivo suficiente",
      at,
    ),
  );
});
test("FEFO multilote y stock insuficiente conservan la atención", () => {
  const map = reviewedAssociations.find((m) => m.kardexCode === "E-22")!;
  const l = lot({
    id: "b",
    code: "E-22",
    name: map.kardexName,
    catalogUnit: "UND",
    container: "unidad",
    sealedContainers: 3,
  });
  const earlier = { ...l, id: "a", sealedContainers: 1, expires: "2027-01-01" };
  const v = visit("fefo", "E-22", 0);
  v.items[0].quantity = 3;
  const result = saveClinical(v, [l, earlier], [], at);
  assert.deepEqual(
    result.movements.map((m) => m.lotId),
    ["a", "b"],
  );
  assert.equal(result.lots.find((l) => l.id === "b")!.sealedContainers, 1);
  v.items[0].quantity = 10;
  const insufficient = saveClinical(v, [l, earlier], [], at);
  assert.equal(insufficient.movements.length, 0);
  assert.equal(insufficient.visit.status, "saved");
  assert.equal(insufficient.visit.pending.length, 1);
});
test("Reintento persistente no duplica la salida", () => {
  const v = visit();
  const one = saveClinical(v, [lot()], [], at);
  const two = saveClinical(v, one.lots, one.movements, at + 1000);
  assert.equal(two.movements.length, 0);
  assert.deepEqual(two.lots, one.lots);
});
test("Lote posterior a atención histórica no altera stock actual; corte Lima 9–8", () => {
  const v = visit("old", "E-22", 0, "2026-11-01");
  const l = lot({
    code: "E-22",
    catalogUnit: "UND",
    sealedContainers: 10,
    updatedAt: at,
  });
  const r = saveClinical(v, [l], [], at);
  assert.equal(r.movements.length, 0);
  assert.equal(r.lots[0].sealedContainers, 10);
  assert.equal(r.visit.pending.length, 1);
  assert.deepEqual(cutPeriod("2026-11-08"), {
    start: "2026-10-09",
    end: "2026-11-08",
  });
  assert.deepEqual(cutPeriod("2026-11-09"), {
    start: "2026-11-09",
    end: "2026-12-08",
  });
  assert.equal(limaDay(Date.parse("2026-11-09T04:59:00Z")), "2026-11-08");
  const p = projectedConsumption(
    [r.visit],
    [l],
    [],
    "2026-10-09",
    "2026-11-08",
  );
  assert.equal(p[0].physicalDebit, false);
  assert.equal(p[0].reportedUse, 1);
});
test("Ingreso y ajuste auditados no modifican el objeto de entrada", () => {
  const l = lot();
  const m = postInventory(
    l,
    "extraordinary",
    3,
    0,
    "OPERADOR FICTICIO",
    "Ingreso documento ficticio",
    at,
  );
  assert.equal(l.sealedContainers, 2);
  assert.equal(m.after.sealedContainers, 5);
  assert.equal(m.sealedAdded, 3);
  assert.throws(() =>
    postInventory(
      l,
      "extraordinary",
      -1,
      0,
      "OPERADOR FICTICIO",
      "Motivo de prueba",
      at,
    ),
  );
});
test("IndexedDB: atomicidad, revisiones simultáneas, recarga y cola", async () => {
  const name = "test-" + crypto.randomUUID();
  const a = await new LocalStore().open(name);
  await a.commit(
    [
      {
        collection: "workers",
        id: "00000001",
        expectedRevision: 0,
        data: { dni: "00000001", name: "FICTICIO" },
      },
    ],
    "A",
  );
  const b = await new LocalStore().open(name);
  const outcomes = await Promise.allSettled([
    a.commit(
      [
        {
          collection: "workers",
          id: "00000001",
          expectedRevision: 1,
          data: { name: "A" },
        },
      ],
      "A",
    ),
    b.commit(
      [
        {
          collection: "workers",
          id: "00000001",
          expectedRevision: 1,
          data: { name: "B" },
        },
      ],
      "B",
    ),
  ]);
  assert.equal(outcomes.filter((o) => o.status === "fulfilled").length, 1);
  assert.equal((await a.get("workers", "00000001"))!.revision, 2);
  await assert.rejects(
    a.commit(
      [
        { collection: "workers", id: "new", expectedRevision: 0, data: {} },
        {
          collection: "workers",
          id: "00000001",
          expectedRevision: 0,
          data: {},
        },
      ],
      "A",
    ),
  );
  assert.equal(await a.get("workers", "new"), undefined);
  assert.equal((await a.queue()).length, 2);
  a.close();
  b.close();
  const c = await new LocalStore().open(name);
  assert.equal((await c.get("workers", "00000001"))!.revision, 2);
  assert.equal((await c.queue()).length, 2);
  c.close();
});
test("10 000 trabajadores, deduplicación y corrección canónica preservada", () => {
  const rows = [
    ["DNI", "NOMBRES", "AREA", "LABOR", "SEXO"],
    ...Array.from({ length: 10000 }, (_, i) => [
      String(i + 1).padStart(8, "0"),
      "FICTICIO " + i,
      "AREA",
      "LABOR",
      "M",
    ]),
  ];
  rows.push(["00000001", "OTRO NOMBRE", "AREA", "LABOR", "M"]);
  const parsed = compileWorkers(rows);
  assert.equal(parsed.workers.length, 10000);
  assert.equal(parsed.stats.duplicates, 1);
  const old = {
    ...parsed.workers[0],
    name: "CORRECCIÓN MANUAL",
    source: "manual" as const,
  };
  assert.equal(
    reconcileWorkers([old], parsed.workers).workers.find(
      (w) => w.dni === old.dni,
    )!.name,
    "CORRECCIÓN MANUAL",
  );
});
test("Colinesterasa: rechaza EMO general, vincula por DNI y preserva discrepancia", async () => {
  const sheet = {
    name: "HISTORIA",
    part: "xl/worksheets/sheet1.xml",
    rows: [
      {
        row: 2,
        values: {
          A: "00000001",
          B: "2026-11-01",
          C: "VERIFICADO",
          D: "EMO",
          E: "NOMBRE DISTINTO",
        },
      },
      {
        row: 3,
        values: {
          A: "00000001",
          B: "2026-11-02",
          C: "RESULTADO ORIGINAL",
          D: "COLINESTERASA",
          E: "NOMBRE DISTINTO",
        },
      },
    ],
  };
  const m = {
    dni: "A",
    name: "E",
    date: "B",
    result: "C",
    type: "D",
    profile: "",
    area: "",
    labor: "",
    nextDate: "",
    campaign: "",
  };
  const p = await previewExams(sheet, m, [visit().worker], "cholinesterase", 1);
  assert.equal(p.exams.length, 1);
  assert.equal(p.exams[0].dni, "00000001");
  assert(p.issues.some((i) => i.reason.includes("no acredita")));
  assert(p.issues.some((i) => i.reason.includes("discrepante")));
  assert.equal(p.exams[0].nextDate, "");
});
test("Indicador: 10 hojas, 19 tablas, 432 materiales, estilos y fórmulas originales", () => {
  const plan = indicatorPlan(
    [visit("empty")],
    [],
    "2026-11-01",
    "2026-11-30",
    true,
  );
  const bytes = exportIndicator(plan);
  const zip = unzipSync(bytes);
  assert.equal(
    Object.keys(zip).filter((p) => /^xl\/tables\/table\d+\.xml$/.test(p))
      .length,
    19,
  );
  const sheets = inspectWorkbook(bytes);
  assert.equal(sheets.length, 10);
  assert.deepEqual(
    sheets.map((s) => s.name),
    [
      "BD MATERIALES",
      "CONTEO",
      "INGRESOS",
      "RESU",
      "CONSUMOS",
      "JUSTIFICACIONES",
      "GUIA",
      "@subuo",
      "BASE TRU",
      "@uo",
    ],
  );
  assert.equal(
    sheets[0].rows.filter((r) => products.some((p) => p.code === r.values.A))
      .length,
    432,
  );
  assert.equal(Object.keys(sheets[4].rows[0].values).length, 30);
  assert.match(strFromU8(zip["xl/worksheets/sheet4.xml"]), /SUMIF/);
  assert.match(strFromU8(zip["xl/styles.xml"]), /cellXfs/);
  const original = unzipSync(
    Uint8Array.from(Buffer.from(template.zipBase64, "base64")),
  );
  assert(strFromU8(zip["xl/styles.xml"]).includes("numFmts"));
  assert.equal(
    strFromU8(zip["xl/theme/theme1.xml"]),
    strFromU8(original["xl/theme/theme1.xml"]),
  );
  assert.throws(() =>
    exportIndicator(
      indicatorPlan([visit()], [], "2026-11-01", "2026-11-30", false),
    ),
  );
});
test("Kardex oficial: 98 productos, R y saldo en plantilla preservada", () => {
  const v = visit();
  const r = saveClinical(v, [lot()], [], at);
  const report = nursingReport(r.lots, r.movements, "2026-11-08", "2026-11-08");
  const bytes = exportOfficialKardex(
    new Uint8Array(fs.readFileSync("public/internal/kardex-template.bin")),
    report,
    "CONSOLIDADO",
    "OPERADOR FICTICIO",
  );
  const sheets = inspectWorkbook(bytes);
  assert.equal(sheets.length, 1);
  assert.equal(sheets[0].name, "KARDEX ENFERMERAS");
  const row = sheets[0].rows.find((r) => r.row === 93)!;
  assert.equal(Number(row.values.G), 1);
  assert.equal(Number(row.values.H), 1);
  const zip = unzipSync(bytes);
  assert.match(strFromU8(zip["xl/worksheets/sheet2.xml"]), /mergeCells/);
});
test("Exportación EMO/colinesterasa solo cambia las celdas autorizadas", () => {
  const source = new Uint8Array(
    fs.readFileSync("public/internal/kardex-template.bin"),
  );
  const before = unzipSync(source);
  const result = patchTemplateDates(source, "xl/worksheets/sheet2.xml", {
    I93: "2026-11-08",
  });
  const after = unzipSync(result);
  assert.deepEqual(Object.keys(after), Object.keys(before));
  for (const k of Object.keys(before))
    if (k !== "xl/worksheets/sheet2.xml") assert.deepEqual(after[k], before[k]);
  assert.throws(() =>
    patchTemplateDates(source, "xl/worksheets/sheet2.xml", {
      XFD100000: "2026-11-08",
    }),
  );
});
