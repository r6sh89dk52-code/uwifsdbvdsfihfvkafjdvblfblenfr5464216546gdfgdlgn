import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import "fake-indexeddb/auto";
import { nursingCatalog } from "../src/nursingCatalog";
import { emptyDraft } from "../src/model";
import { clinician } from "../src/clinician";
import { LocalStore } from "../src/storage";
import { loadTrial, trialData } from "../src/trial";
import {
  nursingReport,
  indicatorPlan,
  exportIndicator,
} from "../src/workbooks";
import { DOMParser, XMLSerializer } from "@xmldom/xmldom";
Object.assign(globalThis, { DOMParser, XMLSerializer });

test("Identidad heredada de Swift y presentaciones especiales del Kardex nativo", () => {
  const swift = fs.readFileSync(
    "../native-ios/Sources/DanperCore/N2NativeFormContext.swift",
    "utf8",
  );
  assert.ok(swift.includes('name="' + clinician.name + '"'));
  assert.ok(swift.includes('dni="' + clinician.dni + '"'));
  assert.equal(emptyDraft().responsible, clinician.name);
  assert.equal(emptyDraft().responsibleDni, clinician.dni);
  assert.equal(nursingCatalog.length, 98);
  assert.ok(
    nursingCatalog
      .filter((p) => p.group === "TABLETAS")
      .every((p) => p.unit === "UND"),
  );
  assert.equal(nursingCatalog.find((p) => p.id === "E-94")!.unit, "CJA");
  assert.equal(nursingCatalog.find((p) => p.id === "E-95")!.unit, "CJA");
  assert.equal(nursingCatalog.find((p) => p.id === "E-86")!.unit, "FCO");
  assert.equal(nursingCatalog.find((p) => p.id === "E-68")!.unit, "");
});

test("Datos ficticios con dispensación real del motor y aislamiento sin cola", async () => {
  const clinical = await new LocalStore().open("danper-web-v1");
  await clinical.commit(
    [
      {
        collection: "workers",
        id: "00000999",
        expectedRevision: 0,
        data: { name: "SENTINELA LOCAL" },
      },
    ],
    "test",
  );
  await loadTrial();
  const trial = await new LocalStore().open("danper-web-trial-v1");
  assert.equal((await trial.all("workers")).length, 3);
  assert.equal((await trial.all("attentions")).length, 2);
  assert.equal((await trial.all("movements")).length, 1);
  assert.equal((await trial.queue()).length, 0);
  // Even callers requesting enqueue cannot send trial records to the outbox.
  await trial.commit(
    [
      {
        collection: "alerts",
        id: "trial-test",
        expectedRevision: 0,
        data: { done: true },
      },
    ],
    "test",
    true,
  );
  assert.equal((await trial.queue()).length, 0);
  await loadTrial();
  assert.equal((await trial.all("attentions")).length, 2);
  assert.equal((await clinical.all("workers")).length, 1);
  assert.equal((await clinical.queue()).length, 1);
  assert.equal((await clinical.all("attentions")).length, 0);
  clinical.close();
  trial.close();
});

test("Kardex diario y semanal usan los mismos movimientos sin descontar dos veces", () => {
  const now = Date.parse("2026-10-25T17:00:00-05:00");
  const data = trialData(now);
  assert.equal(data.lots[0].sealedContainers, 18);
  assert.equal(data.movements.length, 1);
  assert.equal(data.movements[0].excelQuantity, 2);
  assert.equal(data.visits[0].pending?.length, 0);
  const daily = nursingReport(
    data.lots,
    data.movements,
    "2026-10-25",
    "2026-10-25",
  );
  const weekly = nursingReport(
    data.lots,
    data.movements,
    "2026-10-19",
    "2026-10-25",
  );
  assert.deepEqual(daily.rows, weekly.rows);
  assert.equal(data.lots[0].sealedContainers, 18);
});

test("Indicador sin pendientes exporta aunque esté elegida la opción provisional; frecuencia reinicia cada día", () => {
  const data = trialData(Date.parse("2026-10-25T17:00:00-05:00"));
  const plan = indicatorPlan(
    data.visits,
    data.movements,
    "2026-10-25",
    "2026-10-25",
    true,
  );
  assert.equal(plan.provisional, false);
  assert.equal(plan.pendingDeliveries, 0);
  assert.equal(plan.linkedDeliveries, 1);
  assert.ok(exportIndicator(plan).length > 1000);
  const before = {
    ...data.visits[1],
    id: "trial-day-before",
    date: "2026-10-24",
  };
  const multi = indicatorPlan(
    [before, data.visits[1]],
    [],
    "2026-10-24",
    "2026-10-25",
    true,
  );
  assert.deepEqual(
    multi.lines.map((l) => l.cells[18]),
    ["PRIMERA", "PRIMERA"],
  );
});
