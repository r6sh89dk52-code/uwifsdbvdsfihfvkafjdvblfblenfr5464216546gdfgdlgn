import fs from "node:fs";
const p = JSON.parse(fs.readFileSync("firebase-project.public.json", "utf8"));
if (!p.projectId || !p.appId || !p.apiKey || !p.authorizedUid)
  throw Error("Configuración pública incompleta");
const content = [
  "VITE_FIREBASE_API_KEY=" + p.apiKey,
  "VITE_FIREBASE_AUTH_DOMAIN=" + p.authDomain,
  "VITE_FIREBASE_PROJECT_ID=" + p.projectId,
  "VITE_FIREBASE_APP_ID=" + p.appId,
  "VITE_AUTHORIZED_UID=" + p.authorizedUid,
  "VITE_CLOUD_WRITES_ENABLED=false",
  "",
].join("\n");
if (fs.existsSync(".env.local") && !process.argv.includes("--replace"))
  throw Error(
    ".env.local ya existe. No se sobrescribió. Usa --replace únicamente si deseas reponer la configuración pública verificada.",
  );
fs.writeFileSync(".env.local", content);
fs.writeFileSync(
  ".firebaserc",
  JSON.stringify({ projects: { default: p.projectId } }, null, 2) + "\n",
);
console.log(
  "Configuración del proyecto " +
    p.projectId +
    " preparada; escrituras cloud desactivadas.",
);
