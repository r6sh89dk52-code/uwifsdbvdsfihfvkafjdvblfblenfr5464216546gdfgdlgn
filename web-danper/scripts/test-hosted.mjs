import fs from "node:fs";
import { chromium } from "@playwright/test";
import { chromiumPath } from "./browser-path.mjs";
const url = "https://danper-salud-web-20261025.web.app";
const browser = await chromium.launch({
  headless: true,
  executablePath: chromiumPath(),
});
try {
  const page = await browser.newPage();
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  const response = await page.goto(url);
  await page.getByRole("button", { name: "Ingresar con Google" }).waitFor();
  if (response.status() !== 200 || errors.length)
    throw Error(JSON.stringify({ status: response.status(), errors }));
  await page.screenshot({
    path: "validation/hosting-login.png",
    fullPage: true,
  });
  fs.writeFileSync(
    "validation/hosting.json",
    JSON.stringify(
      {
        url,
        status: response.status(),
        googleLoginVisible: true,
        googleSignInEndToEndTested: false,
        errors,
      },
      null,
      2,
    ),
  );
  console.log("PASS Hosting HTTPS y pantalla de acceso Google.");
} finally {
  await browser.close();
}
