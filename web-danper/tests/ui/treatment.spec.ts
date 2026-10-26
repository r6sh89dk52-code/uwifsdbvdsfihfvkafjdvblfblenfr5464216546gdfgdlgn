import { test, expect, type Page } from "@playwright/test";

async function openTreatment(page: Page, invalid = false) {
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Cuidamos la salud de nuestro equipo" }),
  ).toBeVisible();
  await page.evaluate(async (bad) => {
    const sm = "/src/storage.ts",
      mm = "/src/model.ts";
    const { store } = await import(sm),
      { emptyDraft } = await import(mm);
    const draft = emptyDraft();
    draft.worker = {
      ...draft.worker,
      dni: "00000099",
      name: "PERSONA FICTICIA COMPACTA",
    };
    draft.category = "OTROS";
    draft.diagnosis = "COMENTARIO FICTICIO";
    draft.allergy = {
      dni: draft.worker.dni,
      status: "none",
      reviewed: true,
      substances: "",
    };
    draft.step = 2;
    draft.procedures = ["OBSERVACION"];
    draft.items = [
      {
        id: "compact-item-1",
        code: "16000182",
        name: "PARACETAMOL TABLETA 500 MG",
        unit: "UND",
        quantity: 1,
        procedure: "TRATAMIENTO ORAL",
        procedureConfirmed: true,
        procedureSource: "manual",
      },
      {
        id: "compact-item-2",
        code: "16000137",
        name: "IBUPROFENO TABLETA 400 MG",
        unit: "UND",
        quantity: bad ? 0 : 2,
        procedure: "TRATAMIENTO ORAL",
        procedureConfirmed: true,
        procedureSource: "manual",
      },
    ];
    await store.commit(
      [
        {
          collection: "workers",
          id: draft.worker.dni,
          expectedRevision: 0,
          data: draft.worker,
        },
        {
          collection: "drafts",
          id: draft.id,
          expectedRevision: 0,
          data: draft,
        },
      ],
      "test",
      false,
    );
  }, invalid);
  await page.reload();
  await page
    .getByRole("navigation", { name: "Navegación principal" })
    .getByRole("button", { name: "Registrar" })
    .click();
  await page.getByLabel("Reanudar borrador").selectOption({ index: 1 });
  await expect(
    page.getByRole("heading", {
      name: "Tratamiento y procedimientos",
      exact: true,
    }),
  ).toBeVisible();
}

test("Tratamiento compacto: dos líneas, catálogo aislado y Continuar sin desplazar la página", async ({
  page,
}, info) => {
  if (info.project.name === "desktop")
    await page.setViewportSize({ width: 1366, height: 768 });
  await openTreatment(page);
  await expect(page.getByRole("listitem")).toHaveCount(0);
  await expect(page.locator(".other-procedures")).not.toHaveAttribute("open");
  await expect(page.locator(".medication-row")).toHaveCount(2);
  await expect(page.locator(".medication-row[open]")).toHaveCount(0);
  await page.evaluate(() => window.scrollTo(0, 0));
  const viewport = page.viewportSize()!;
  await expect
    .poll(() =>
      page
        .locator(".treatment-view>.card")
        .evaluate((el) => getComputedStyle(el).opacity),
    )
    .toBe("1");
  await page.screenshot({
    path: "test-results/" + info.project.name + "-tratamiento-compacto.png",
    fullPage: false,
  });
  const card = await page.locator(".treatment-view>.card").boundingBox();
  expect(card!.y + card!.height).toBeLessThanOrEqual(
    viewport.height - (info.project.name === "mobile" ? 68 : 12),
  );
  await expect(
    page.getByRole("button", { name: "Continuar", exact: true }),
  ).toBeInViewport();
  await page.screenshot({
    path: "test-results/" + info.project.name + "-tratamiento-compacto.png",
    fullPage: false,
  });
  if(info.project.name==='desktop'){
    await page.getByRole('button',{name:'Cambiar tema',exact:true}).click();
    await expect(page.locator('html')).toHaveAttribute('data-theme','dark');
    await page.screenshot({path:'test-results/desktop-tratamiento-compacto-oscuro.png',fullPage:false});
  }
  await page
    .getByRole("button", { name: "Añadir medicamento o insumo", exact: true })
    .click();
  const picker = page.getByRole("dialog", {
    name: "Añadir medicamentos e insumos",
    exact: true,
  });
  await expect(picker.getByLabel("Buscar producto clínico")).toBeFocused();
  await expect(picker.getByRole("listitem")).toHaveCount(432);
  await picker
    .getByLabel("Buscar producto clínico")
    .fill("PARACETAMOL TABLETA 500 MG");
  await picker.getByRole("listitem").first().click();
  await expect(picker).toContainText("1 añadidos en esta selección");
  await page.screenshot({
    path: "test-results/" + info.project.name + "-catalogo-emergente.png",
    fullPage: false,
  });
  await picker
    .getByRole("button", { name: "Listo · volver al tratamiento", exact: true })
    .click();
  await expect(page.locator(".medication-row")).toHaveCount(3);
  await expect(page.locator(".medication-row[open]")).toHaveCount(0);
  await page
    .locator(".medication-row")
    .last()
    .locator("summary")
    .first()
    .click();
  await expect(page.locator(".medication-row[open]")).toHaveCount(1);
  await page
    .locator(".medication-row")
    .last()
    .getByLabel("Cantidad clínica (UND)")
    .fill("3");
  await page
    .locator(".medication-row")
    .last()
    .getByLabel("Confirmo el procedimiento realizado")
    .check();
  await expect(page.locator(".medication-row[open]")).toHaveCount(0);
  await expect(page.locator(".medication-row").last()).toContainText("3 UND");
  await page.getByRole("button", { name: "Continuar", exact: true }).click();
  await expect(
    page.getByRole("heading", {
      name: "Resultado de la atención",
      exact: true,
    }),
  ).toBeVisible();
});

test("Corregir abre el medicamento con cantidad inválida sin desplegar las demás líneas", async ({
  page,
}) => {
  await openTreatment(page, true);
  await page.getByRole("button", { name: "Continuar", exact: true }).click();
  const error = page.getByRole("dialog", {
    name: "No se pudo completar",
    exact: true,
  });
  await expect(error).toContainText("producto 2");
  await error.getByRole("button", { name: "Corregir", exact: true }).click();
  const second = page.locator('[data-item-id="compact-item-2"]');
  await expect(second).toHaveAttribute("open");
  await expect(
    page.locator('[data-item-id="compact-item-1"]'),
  ).not.toHaveAttribute("open");
  await expect(second.getByLabel("Cantidad clínica (UND)")).toBeFocused();
  await second.getByLabel("Cantidad clínica (UND)").fill("2");
  await page.getByRole("button", { name: "Continuar", exact: true }).click();
  await expect(
    page.getByRole("heading", {
      name: "Resultado de la atención",
      exact: true,
    }),
  ).toBeVisible();
});
