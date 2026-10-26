import { encryptPortableBackup } from "../../legacy/portableBackup";
import { test, expect } from "@playwright/test";
import { acknowledge } from "./feedback-helper";

test("Sin coincidencias permite crear ficha; DNI duplicado lleva al padrón sin sobrescribir", async ({
  page,
}) => {
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Cuidamos la salud de nuestro equipo" }),
  ).toBeVisible();
  await page.evaluate(async () => {
    const module = "/src/storage.ts";
    const { store } = await import(module);
    await store.commit(
      [
        {
          collection: "workers",
          id: "00000001",
          expectedRevision: 0,
          data: {
            dni: "00000001",
            name: "IDENTIDAD FICTICIA ORIGINAL",
            area: "PRODUCCION",
            labor: "LABOR FICTICIA",
            site: "LA VENTUROSA",
            sex: "F",
            age: "30",
            ubigeo: "",
          },
        },
      ],
      "test",
      false,
    );
  });
  await page.reload();
  await page
    .getByRole("navigation", { name: "Navegación principal" })
    .getByRole("button", { name: "Registrar" })
    .click();
  await page.getByRole("button", { name: /Buscar en padrón/ }).click();
  const roster = page.getByRole("dialog", {
    name: "Buscar en padrón",
    exact: true,
  });
  await roster.getByLabel("DNI o apellidos y nombres").fill("00000100");
  await expect(roster).toContainText("No encontramos esa persona");
  await roster
    .getByRole("button", { name: "Registrar nuevo trabajador", exact: true })
    .click();
  await expect(page.getByLabel("DNI", { exact: true })).toHaveValue("00000100");
  await page.getByLabel("DNI", { exact: true }).fill("00000001");
  await page
    .getByLabel("Apellidos y nombres")
    .fill("NOMBRE FICTICIO QUE NO DEBE SOBRESCRIBIR");
  await page
    .getByRole("button", { name: "Guardar ficha", exact: true })
    .click();
  const error = page.getByRole("dialog", {
    name: "No se pudo completar",
    exact: true,
  });
  await expect(error).toContainText("DNI ya existe");
  await error.getByRole("button", { name: "Corregir", exact: true }).click();
  await expect(roster.getByLabel("DNI o apellidos y nombres")).toHaveValue(
    "00000001",
  );
  await roster
    .getByRole("button", { name: /IDENTIDAD FICTICIA ORIGINAL/ })
    .click();
  await expect(page.locator(".verified-worker")).toContainText(
    "IDENTIDAD FICTICIA ORIGINAL",
  );
  expect(
    await page.evaluate(async () => {
      const module = "/src/storage.ts";
      const { store } = await import(module);
      return (await store.all("workers")).length;
    }),
  ).toBe(1);
});

test("Padrón global paginado, selección explícita y error que vuelve al campo clínico", async ({
  page,
}, info) => {
  await page.goto("/");
  await expect(
    page.getByRole("heading", { name: "Cuidamos la salud de nuestro equipo" }),
  ).toBeVisible();
  await page.evaluate(async () => {
    const module = "/src/storage.ts";
    const { store } = await import(module);
    await store.commit(
      Array.from({ length: 60 }, (_, i) => ({
        collection: "workers",
        id: String(i + 1).padStart(8, "0"),
        expectedRevision: 0,
        data: {
          dni: String(i + 1).padStart(8, "0"),
          name: "PERSONA FICTICIA " + String(i + 1).padStart(2, "0"),
          area: "PRODUCCION",
          labor: "PUESTO FICTICIO",
          site: i % 2 ? "PLVENTUROSA" : "LA VENTUROSA",
          sex: "F",
          age: "30",
          ubigeo: "",
        },
      })),
      "test",
      false,
    );
  });
  await page.reload();
  await page
    .getByRole("navigation", { name: "Navegación principal" })
    .getByRole("button", { name: "Registrar" })
    .click();
  await page
    .getByRole("button", { name: "Buscar en padrón", exact: false })
    .click();
  const roster = page.getByRole("dialog", {
    name: "Buscar en padrón",
    exact: true,
  });
  await expect(roster).toBeVisible();
  await expect(roster.getByLabel("DNI o apellidos y nombres")).toBeFocused();
  await expect(roster.locator(".roster-row")).toHaveCount(25);
  await roster.getByRole("button", { name: "Siguiente", exact: true }).click();
  await expect(roster).toContainText("Página 2 de 3");
  await roster.getByLabel("DNI o apellidos y nombres").fill("00000037");
  await expect(roster.locator(".roster-row")).toHaveCount(1);
  await page.screenshot({
    path: "test-results/" + info.project.name + "-padron.png",
    fullPage: false,
  });
  await roster.getByRole("button", { name: /PERSONA FICTICIA 37/ }).click();
  await expect(roster).not.toBeVisible();
  await expect(page.locator(".verified-worker")).toContainText("00000037");
  await page.getByRole("button", { name: "Continuar", exact: true }).click();
  await page
    .getByLabel("Diagnóstico presuntivo / comentario clínico")
    .fill("SE CONSERVA ESTE TEXTO FICTICIO");
  await page.getByRole("button", { name: "Continuar", exact: true }).click();
  const error = page.getByRole("dialog", {
    name: "No se pudo completar",
    exact: true,
  });
  await expect(error).toContainText("Selecciona una categoría");
  const viewport = page.viewportSize()!;
  await expect
    .poll(async () => {
      const bounds = await error.boundingBox();
      return Math.abs(bounds!.x + bounds!.width / 2 - viewport.width / 2);
    })
    .toBeLessThan(5);
  await expect
    .poll(async () => {
      const bounds = await error.boundingBox();
      return Math.abs(bounds!.y + bounds!.height / 2 - viewport.height / 2);
    })
    .toBeLessThan(5);
  await page.screenshot({
    path: "test-results/" + info.project.name + "-error-central.png",
    fullPage: false,
  });
  await error.getByRole("button", { name: "Corregir", exact: true }).click();
  await expect(page.getByLabel("Tipo de atención")).toBeFocused();
  await expect(page.getByLabel("Tipo de atención")).toHaveAttribute(
    "aria-invalid",
    "true",
  );
  await expect(
    page.getByLabel("Diagnóstico presuntivo / comentario clínico"),
  ).toHaveValue("SE CONSERVA ESTE TEXTO FICTICIO");
  await page.getByLabel("Tipo de atención").selectOption("OTROS");
  await expect(page.getByLabel("Tipo de atención")).not.toHaveAttribute(
    "aria-invalid",
    "true",
  );
  await page.getByLabel("Estado reportado").selectOption("none");
  await page.getByLabel("He revisado las alergias").check();
  await page.getByRole("button", { name: "Continuar", exact: true }).click();
  await expect(
    page.getByRole("heading", {
      name: "Tratamiento y procedimientos",
      exact: true,
    }),
  ).toBeVisible();
  await page.waitForTimeout(650);
  await expect(page.getByRole("dialog")).toHaveCount(0); // Autosave must remain silent.
});

test("Registro manual conserva campos al corregir y confirma una sola ficha", async ({
  page,
}, info) => {
  await page.goto("/");
  await page
    .getByRole("navigation", { name: "Navegación principal" })
    .getByRole("button", { name: "Registrar" })
    .click();
  await page
    .getByRole("button", {
      name: "Registrar trabajador sin salir",
      exact: true,
    })
    .click();
  await page.getByLabel("DNI", { exact: true }).fill("123");
  await page.getByLabel("Apellidos y nombres").fill("PERSONA MANUAL FICTICIA");
  await page
    .getByRole("button", { name: "Guardar ficha", exact: true })
    .click();
  const error = page.getByRole("dialog", {
    name: "No se pudo completar",
    exact: true,
  });
  await expect(error).toContainText("DNI válido");
  for (let i = 0; i < 5; i++) await page.keyboard.press("Tab");
  expect(
    await error.evaluate((el) => el.contains(document.activeElement)),
  ).toBe(true);
  await error.getByRole("button", { name: "Corregir", exact: true }).click();
  await expect(page.getByLabel("DNI", { exact: true })).toBeFocused();
  await expect(page.getByLabel("Apellidos y nombres")).toHaveValue(
    "PERSONA MANUAL FICTICIA",
  );
  await page.getByLabel("DNI", { exact: true }).fill("00000091");
  await page.getByLabel("Sede", { exact: true }).selectOption("PLVENTUROSA");
  await page
    .getByRole("button", { name: "Guardar ficha", exact: true })
    .click();
  const saved = page.getByRole("dialog", {
    name: "Guardado correctamente",
    exact: true,
  });
  await expect(saved).toContainText("Ficha de trabajador guardada");
  await expect(page.getByRole("dialog")).toHaveCount(1);
  await page.screenshot({
    path: "test-results/" + info.project.name + "-confirmacion.png",
    fullPage: false,
  });
  await acknowledge(page);
  await expect(page.locator(".verified-worker")).toContainText("00000091");
  const count = await page.evaluate(async () => {
    const module = "/src/storage.ts";
    return (await (await import(module)).store.all("workers")).length;
  });
  expect(count).toBe(1);
  await page.getByRole("navigation",{name:"Navegación principal"}).getByRole("button",{name:"Ajustes"}).click();
  const passphrase="CLAVE FICTICIA DE PRUEBA";
  await page.getByLabel("Contraseña del respaldo (no se almacena)").fill(passphrase);
  const invalidBackup=await encryptPortableBackup({schema:"danper-web-1",workers:[],attentions:[]},passphrase);
  await page.getByLabel("Respaldo cifrado",{exact:true}).setInputFiles({name:"RESPALDO_FICTICIO_INVALIDO.json",mimeType:"application/json",buffer:Buffer.from(invalidBackup)});
  await expect(error).toContainText("Faltan trabajadores");
  await error.getByRole("button",{name:"Corregir",exact:true}).click();
  await expect(page.getByLabel("Respaldo cifrado",{exact:true})).toBeFocused();
});

test("Stock: corregir lote y cantidad, confirmación central tras persistir", async ({
  page,
}, info) => {
  await page.goto("/");
  await page
    .getByRole("button", { name: "Kardex e inventario", exact: true })
    .filter({ visible: true })
    .first()
    .click();
  await page
    .getByRole("combobox", { name: "Producto oficial de enfermería" })
    .fill("PARACETAMOL TAB");
  await page.getByRole("option", { name: /PARACETAMOL TAB/ }).click();
  await page.getByRole("button", { name: "Guardar lote", exact: true }).click();
  const error = page.getByRole("dialog", {
    name: "No se pudo completar",
    exact: true,
  });
  await expect(error).toContainText("referencia del lote");
  await page.emulateMedia({ reducedMotion: "reduce" });
  expect(await error.evaluate((el) => getComputedStyle(el).animationName)).toBe(
    "none",
  );
  await error.getByRole("button", { name: "Corregir", exact: true }).click();
  await expect(page.getByLabel("Lote", { exact: true })).toBeFocused();
  await page.getByLabel("Lote", { exact: true }).fill("FICTICIO-CENTRAL");
  await page.getByRole("button", { name: "Guardar lote", exact: true }).click();
  await expect(error).toContainText("cantidad inicial mayor que cero");
  await error.getByRole("button", { name: "Corregir", exact: true }).click();
  await expect(
    page.getByLabel("Cantidad inicial (UND)", { exact: true }),
  ).toBeFocused();
  await page.getByLabel("Cantidad inicial (UND)", { exact: true }).fill("3");
  await page.getByRole("button", { name: "Guardar lote", exact: true }).click();
  await expect(
    page.getByRole("dialog", { name: "Guardado correctamente", exact: true }),
  ).toContainText("Stock registrado en Kardex");
  await acknowledge(page);
  await expect(
    page.getByRole("cell", { name: "FICTICIO-CENTRAL", exact: true }),
  ).toBeVisible();
  await page.reload();
  await page
    .getByRole("button", { name: "Kardex e inventario", exact: true })
    .filter({ visible: true })
    .first()
    .click();
  await expect(
    page.getByRole("cell", { name: "FICTICIO-CENTRAL", exact: true }),
  ).toBeVisible();
  if (info.project.name === "mobile")
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth - window.innerWidth,
      ),
    ).toBeLessThanOrEqual(1);
});
