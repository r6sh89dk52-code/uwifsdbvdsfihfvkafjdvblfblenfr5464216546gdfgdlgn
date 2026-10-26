import { acknowledge } from "./feedback-helper";
import { test, expect } from "@playwright/test";
import { exportDataSheet } from "../../src/dataExport";
test("Importar PERSONAL con vista previa, paginación y operaciones auditadas de inventario", async ({
  page,
}, info) => {
  await page.goto("/");
  async function open(name: string) {
    if (info.project.name === "mobile") {
      await page
        .getByRole("navigation", { name: "Navegación principal" })
        .getByRole("button", { name: "Inicio" })
        .click();
      await page.getByRole("button", { name: new RegExp("^" + name) }).click();
    } else
      await page
        .getByRole("navigation", { name: "Módulos" })
        .getByRole("button", { name, exact: true })
        .click();
  }
  await open("Trabajadores");
  const data = exportDataSheet(
    "PERSONAL",
    ["DNI", "NOMBRES", "AREA", "LABOR", "SEXO", "FECHA NACIMIENTO", "SEDE"],
    Array.from({ length: 101 }, (_, i) => [
      String(i + 1).padStart(8, "0"),
      "PERSONA FICTICIA " + i,
      "AREA FICTICIA",
      "LABOR FICTICIA",
      "F",
      "1990-01-01",
      "LA VENTUROSA",
    ]),
  );
  await page.getByLabel("Importar PERSONAL").setInputFiles({
    name: "PERSONAL_FICTICIO.xlsx",
    mimeType:
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    buffer: Buffer.from(data),
  });
  await page
    .getByLabel("Revisé las discrepancias y confirmo incorporar el padrón")
    .check();
  await page
    .getByRole("button", { name: "Confirmar importación", exact: true })
    .click();
  await acknowledge(page);
  await expect(page.getByRole("status")).toContainText("101 fichas");
  await expect(page.getByRole("row")).toHaveCount(26);
  await page.getByRole("button", { name: "Siguiente", exact: true }).click();
  await expect(
    page.getByRole("cell", { name: "00000026", exact: true }),
  ).toBeVisible();
  await page.getByLabel("Buscar trabajadores").fill("00000101");
  await expect(
    page.getByRole("cell", { name: "PERSONA FICTICIA 100", exact: true }),
  ).toBeVisible();
  await open("Kardex e inventario");
  await page
    .getByRole("combobox", { name: "Producto oficial de enfermería" })
    .fill("ALCOHOL 120");
  await page.getByRole("option", { name: /ALCOHOL 120 ML/ }).click();
  await expect(
    page.getByText("Presentación: FCO", { exact: true }),
  ).toBeVisible();
  await page.getByLabel("Lote", { exact: true }).fill("LOTE-FICTICIO");
  await page.getByLabel("Vencimiento", { exact: true }).fill("2027-12-31");
  await page.getByLabel("Cantidad inicial (FCO)", { exact: true }).fill("2");
  await page.getByRole("button", { name: "Guardar lote", exact: true }).click();
  await acknowledge(page);
  await expect(
    page.getByRole("cell", { name: "LOTE-FICTICIO", exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Operar", exact: true }).click();
  await page.getByLabel("Ingreso de cerrados / unidades").fill("3");
  await expect(page.getByLabel("Responsable", { exact: true })).toHaveValue(
    "Felipe Azcárate Silva",
  );
  await page
    .getByLabel("Motivo / documento")
    .fill("Ingreso mediante documento ficticio");
  await page
    .getByRole("button", { name: "Confirmar operación física" })
    .click();
  await acknowledge(page);
  await expect(
    page.getByRole("cell", { name: "5", exact: true }),
  ).toBeVisible();
  await page.reload();
  await open("Kardex e inventario");
  await expect(
    page.getByRole("cell", { name: "5", exact: true }),
  ).toBeVisible();
  await expect(
    page.getByRole("cell", { name: "Ingreso mediante documento ficticio" }),
  ).toBeVisible();
});
