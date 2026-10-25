import fs from "node:fs";
import crypto from "node:crypto";
const assets = fs
  .readdirSync("dist/assets")
  .filter((n) => /\.(js|css|png)$/.test(n))
  .map((n) => "/assets/" + n);
const names = [
  "/",
  "/index.html",
  "/brand.png",
  "/app-icon.svg",
  "/manifest.webmanifest",
  "/internal/kardex-template.bin",
  ...assets,
];
const version = crypto
  .createHash("sha256")
  .update(assets.join("|"))
  .digest("hex")
  .slice(0, 12);
fs.writeFileSync(
  "dist/sw.js",
  `const CACHE='danper-static-${version}',FILES=${JSON.stringify(names)};self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(FILES))));self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k.startsWith('danper-static-')&&k!==CACHE).map(k=>caches.delete(k))))));self.addEventListener('fetch',e=>{const u=new URL(e.request.url);if(e.request.method!=='GET'||u.origin!==self.location.origin||!(FILES.includes(u.pathname)||e.request.mode==='navigate'))return;e.respondWith(fetch(e.request).catch(()=>caches.match(e.request).then(r=>r||caches.match('/index.html'))));});`,
);
console.log(
  "Service worker: caché exclusiva de " +
    names.length +
    " recursos estáticos; sin respuestas clínicas.",
);
