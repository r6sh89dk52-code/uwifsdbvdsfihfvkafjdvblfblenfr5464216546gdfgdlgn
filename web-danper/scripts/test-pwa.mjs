import { spawn } from "node:child_process";
import fs from "node:fs";
import { chromium } from "@playwright/test";
import { chromiumPath } from "./browser-path.mjs";
const executable = chromiumPath();
const server = spawn(
  process.execPath,
  [
    "node_modules/vite/bin/vite.js",
    "preview",
    "--host",
    "127.0.0.1",
    "--port",
    "5197",
    "--strictPort",
  ],
  { stdio: "pipe", windowsHide: true },
);
let browser;
try {
  await new Promise((resolve, reject) => {
    server.stdout.on("data", (b) => {
      if (String(b).includes("5197")) resolve();
    });
    server.on("exit", (code) => reject(Error("Preview falló: " + code)));
    setTimeout(() => reject(Error("Preview no inició")), 15000).unref();
  });
  browser = await chromium.launch({
    headless: true,
    ...(executable ? { executablePath: executable } : {}),
  });
  const context = await browser.newContext();
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("http://127.0.0.1:5197");
  await page.evaluate(() => navigator.serviceWorker.ready);
  await page.reload();
  await page.locator("main.login, .shell").waitFor();
  const signedOut = await page
    .getByRole("button", { name: "Ingresar con Google" })
    .isVisible();
  const heading = signedOut
    ? "DANPER SALUD"
    : "Cuidamos la salud de nuestro equipo";
  await page.getByRole("heading", { name: heading, exact: true }).waitFor();
  const cachedPaths = await page.evaluate(async () =>
    (
      await Promise.all(
        (await caches.keys()).map(async (key) =>
          (await (await caches.open(key)).keys()).map(
            (r) => new URL(r.url).pathname,
          ),
        ),
      )
    ).flat(),
  );
  if (!cachedPaths.some((p) => p.startsWith("/assets/") && p.endsWith(".js")))
    throw Error("No hay JavaScript precargado");
  await context.setOffline(true);
  await page.reload();
  await page.getByRole("heading", { name: heading, exact: true }).waitFor();
  if (!signedOut) {
    await page
      .getByRole("navigation", { name: "Navegación principal" })
      .getByRole("button", { name: "Ajustes" })
      .click();
    await page.getByLabel("Tema", { exact: true }).selectOption("dark");
    await page.reload();
    if ((await page.locator("html").getAttribute("data-theme")) !== "dark")
      throw Error("Preferencia no persistió offline");
  }
  if (errors.length) throw Error(errors.join("\n"));
  fs.mkdirSync("validation", { recursive: true });
  fs.writeFileSync(
    "validation/pwa.json",
    JSON.stringify(
      {
        browser: "Chromium",
        productionBuild: true,
        offlineReload: true,
        signedOut,
        staticAssetsCached: true,
        lazyModuleOffline: signedOut ? null : true,
        themePersistedOffline: signedOut ? null : true,
        errors,
      },
      null,
      2,
    ),
  );
  console.log(
    "PASS PWA producción: recarga offline y recursos estáticos; alcance detallado en validation/pwa.json.",
  );
} finally {
  await browser?.close();
  server.kill();
}
