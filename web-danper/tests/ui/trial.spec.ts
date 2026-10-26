import { test, expect } from "@playwright/test";
import { unzipSync, strFromU8 } from "fflate";
import fs from "node:fs/promises";
test("Prueba ficticia aislada, importación PERSONAL y descargas por período", async ({
  page,
}, info) => {
  await page.goto("/");
  const nav = page.getByRole("navigation", { name: "Navegación principal" });
  await nav.getByRole("button", { name: "Ajustes" }).click();
  await page
    .getByRole("button", { name: "Probar con datos ficticios", exact: true })
    .click();
  await expect(
    page.getByText("PRUEBA LOCAL · DATOS FICTICIOS", { exact: true }),
  ).toBeVisible();
  await nav.getByRole("button", { name: "Historial" }).click();
  await expect(
    page.getByRole("cell", { name: /ANA PRUEBA FICTICIA/ }),
  ).toBeVisible();
  await expect(
    page.getByRole("cell", { name: /LUIS PRUEBA FICTICIA/ }),
  ).toBeVisible();
  await nav.getByRole("button", { name: "Ajustes" }).click();
  const samplePromise = page.waitForEvent("download");
  await page
    .getByRole("button", { name: "Descargar PERSONAL ficticio", exact: true })
    .click();
  const sample = await samplePromise;
  await nav.getByRole("button", { name: "Inicio" }).click();
  await page
    .getByRole("button", { name: "Trabajadores", exact: true })
    .filter({ visible: true })
    .first()
    .click();
  await page
    .getByLabel("Importar PERSONAL")
    .setInputFiles((await sample.path())!);
  await page
    .getByLabel("Revisé las discrepancias y confirmo incorporar el padrón")
    .check();
  await page
    .getByRole("button", { name: "Confirmar importación", exact: true })
    .click();
  await expect(
    page.getByText("2 fichas incorporadas por DNI.", { exact: true }),
  ).toBeVisible();
  await nav.getByRole("button", { name: "Inicio" }).click();
  await page
    .getByRole("button", { name: "Indicadores y exportaciones", exact: true })
    .filter({ visible: true })
    .first()
    .click();
  const date = await page.getByLabel("Hasta", { exact: true }).inputValue();
  await page.getByLabel("Desde", { exact: true }).fill(date);
  for (const name of [
    "Exportar Indicador (10 hojas)",
    "Exportar Kardex (98 productos)",
    "Exportar vigilancia osteomuscular",
  ]) {
    const pending = page.waitForEvent("download");
    await page.getByRole("button", { name, exact: true }).click();
    const file = await pending;
    const archive = unzipSync(
      new Uint8Array(await fs.readFile((await file.path())!)),
    );
    expect(archive["xl/workbook.xml"]).toBeDefined();
    if (name.includes("Indicador"))
      expect(
        (strFromU8(archive["xl/workbook.xml"]).match(/<sheet /g) || []).length,
      ).toBe(10);
  }
  const queue = await page.evaluate(async () => {
    const module = "/src/storage.ts";
    return (await import(module)).store.queue();
  });
  expect(queue).toEqual([]);
  expect(await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)).toBeLessThanOrEqual(1);
  await page.screenshot({
    path: "test-results/" + info.project.name + "-trial.png",
    fullPage: true,
  });
  await page
    .getByRole("button", { name: "Volver a mis registros", exact: true })
    .click();
  await nav.getByRole("button", { name: "Historial" }).click();
  await expect(
    page.getByRole("cell", { name: /ANA PRUEBA FICTICIA/ }),
  ).toHaveCount(0);
  await expect(
    page.getByText("No hay atenciones.", { exact: true }),
  ).toBeVisible();
});
