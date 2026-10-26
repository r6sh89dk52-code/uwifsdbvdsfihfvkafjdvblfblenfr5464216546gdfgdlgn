import contract from "../../src/generated/contract.json" with { type: "json" };
import { test, expect } from "@playwright/test";
test("Recorrido clínico, persistencia, catálogo completo y modo oscuro", async ({
  page,
}, info) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Cuidamos la salud de nuestro equipo" }),
  ).toBeVisible();
  await page
    .getByRole("navigation", { name: "Navegación principal" })
    .getByRole("button", { name: "Registrar" })
    .click();
  await page
    .getByRole("button", { name: "Registrar trabajador sin salir" })
    .click();
  await page.getByLabel("DNI", { exact: true }).fill("00000001");
  await page.getByLabel("Apellidos y nombres").fill("TRABAJADOR FICTICIO");
  await page.getByLabel("Área", { exact: true }).fill("AREA FICTICIA");
  await page.getByLabel("Labor / puesto").fill("LABOR FICTICIA");
  await page.getByLabel("Sede", { exact: true }).selectOption("PLVENTUROSA");
  await page.getByLabel("Sexo (M/F)").selectOption("F");
  await page.getByRole("button", { name: "Guardar ficha" }).click();
  await expect(
    page.getByText("TRABAJADOR FICTICIO", { exact: true }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Continuar" }).click();
  await page.getByLabel("Tipo de atención").selectOption("OTROS");
  await expect(page.getByLabel("Sistema afectado")).toHaveCount(0);
  await page.getByLabel("Tipo de atención").selectOption("ENFERMEDAD");
  await expect(page.getByLabel("Sistema afectado")).toBeVisible();
  await page.getByLabel("Sistema afectado").selectOption("OSTEOMUSCULAR");
  await expect(page.getByLabel("Segmento osteomuscular")).toBeVisible();
  await page.getByLabel("Segmento osteomuscular").fill("ZONA LUMBAR");
  await page
    .getByLabel("Diagnóstico presuntivo / comentario clínico")
    .fill("COMENTARIO FICTICIO");
  await page.getByLabel("Estado reportado").selectOption("none");
  await page.getByLabel("He revisado las alergias").check();
  await page.getByRole("button", { name: "Continuar" }).click();
  await expect(page.getByRole("listitem")).toHaveCount(432);
  await page.getByLabel("OBSERVACION", { exact: true }).check();
  await page
    .getByRole("listitem")
    .filter({ hasText: "PARACETAMOL TABLETA 500 MG" })
    .click();
  await page.getByLabel("Confirmo el procedimiento realizado").check();
  await page.getByRole("button", { name: "Continuar" }).click();
  await expect(page.getByLabel("Responsable", { exact: true })).toHaveValue(
    contract.clinician.name,
  );
  await expect(page.getByLabel("DNI del responsable")).toHaveValue(
    contract.clinician.dni,
  );
  await expect(page.getByLabel("Responsable", { exact: true })).toHaveAttribute(
    "readonly",
    "",
  );
  await page
    .getByRole("button", { name: "Guardar atención", exact: true })
    .click();
  await expect(page.getByRole("status")).toContainText("Atención guardada");
  await page.reload();
  await page
    .getByRole("navigation", { name: "Navegación principal" })
    .getByRole("button", { name: "Historial" })
    .click();
  await expect(
    page.getByRole("cell", { name: "TRABAJADOR FICTICIO" }),
  ).toBeVisible();
  await page
    .getByRole("navigation", { name: "Navegación principal" })
    .getByRole("button", { name: "Ajustes" })
    .click();
  await page.getByLabel("Tema", { exact: true }).selectOption("dark");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  await page.screenshot({
    path: "test-results/" + info.project.name + "-dark.png",
    fullPage: true,
  });
  await page.getByLabel("Paleta", { exact: true }).selectOption("salud");
  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-palette", "salud");
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
  expect(errors).toEqual([]);
});
test("Todos los 432 productos son seleccionables desde el formulario", async ({
  page,
}, info) => {
  test.skip(
    info.project.name === "mobile",
    "El recorrido completo se verifica una vez en escritorio",
  );
  test.setTimeout(240000);
  await page.goto("/");
  await page
    .getByRole("navigation", { name: "Navegación principal" })
    .getByRole("button", { name: "Registrar" })
    .click();
  await page.evaluate(async () => {
    const a = "/src/storage.ts",
      b = "/src/model.ts";
    const { store } = await import(a),
      { emptyDraft } = await import(b);
    const d = emptyDraft();
    d.worker = { ...d.worker, dni: "00000001", name: "FICTICIO" };
    d.step = 2;
    await store.commit(
      [{ collection: "drafts", id: d.id, expectedRevision: 0, data: d }],
      "test",
      false,
    );
  });
  await page.reload();
  await page
    .getByRole("navigation", { name: "Navegación principal" })
    .getByRole("button", { name: "Registrar" })
    .click();
  await page.getByLabel("Reanudar borrador").selectOption({ index: 1 });
  const names = await page.getByRole("listitem").allTextContents();
  expect(names).toHaveLength(432);
  for (let i = 0; i < 432; i++) {
    const product = page.getByRole("listitem").nth(i);
    await product.click();
    await expect(
      page.getByRole("button", { name: "Quitar", exact: true }),
    ).toHaveCount(1);
    await page.getByRole("button", { name: "Quitar", exact: true }).click();
  }
  await expect(page.getByRole("listitem")).toHaveCount(432);
});
test("Módulos adicionales, navegación y límites responsivos", async ({
  page,
}, info) => {
  await page.goto("/");
  if (info.project.name === "mobile") {
    for (const name of [
      "EMO",
      "Colinesterasa",
      "Alertas",
      "Kardex e inventario",
    ]) {
      await page.getByRole("button", { name: new RegExp("^" + name) }).click();
      await expect(page.getByRole("heading", { level: 1, name })).toBeVisible();
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth,
        ),
      ).toBeTruthy();
      await page
        .getByRole("navigation", { name: "Navegación principal" })
        .getByRole("button", { name: "Inicio" })
        .click();
    }
  } else {
    for (const name of [
      "Trabajadores",
      "Kardex e inventario",
      "EMO",
      "Colinesterasa",
      "Descansos médicos",
      "Alertas",
      "Indicadores y exportaciones",
    ]) {
      await page
        .getByRole("navigation", { name: "Módulos" })
        .getByRole("button", { name, exact: true })
        .click();
      await expect(page.getByRole("heading", { level: 1, name })).toBeVisible();
    }
  }
  await page.screenshot({
    path: "test-results/" + info.project.name + "-light.png",
    fullPage: true,
  });
});
