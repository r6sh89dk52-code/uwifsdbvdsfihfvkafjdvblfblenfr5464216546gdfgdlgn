import fs from "node:fs";
import path from "node:path";
export function chromiumPath() {
  if (process.env.DANPER_CHROMIUM) return process.env.DANPER_CHROMIUM;
  if (process.platform !== "win32" || !process.env.LOCALAPPDATA)
    return undefined;
  const root = path.join(process.env.LOCALAPPDATA, "ms-playwright");
  if (!fs.existsSync(root)) return undefined;
  const candidates = fs
    .readdirSync(root)
    .filter((n) => /^chromium-\d+$/.test(n))
    .sort((a, b) => Number(b.split("-")[1]) - Number(a.split("-")[1]));
  for (const folder of candidates)
    for (const sub of ["chrome-win64", "chrome-win"]) {
      const file = path.join(root, folder, sub, "chrome.exe");
      if (fs.existsSync(file)) return file;
    }
  return undefined;
}
