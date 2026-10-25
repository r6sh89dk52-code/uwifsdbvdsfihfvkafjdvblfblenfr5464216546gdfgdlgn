import fs from "node:fs";
const project = process.env.FIREBASE_PROJECT_ID,
  uid = process.env.DANPER_AUTHORIZED_UID;
if (
  !project ||
  !/^[a-z][a-z0-9-]{4,28}[a-z0-9]$/.test(project) ||
  !uid ||
  !/^[A-Za-z0-9_-]{1,128}$/.test(uid)
)
  throw Error(
    "Define FIREBASE_PROJECT_ID real y DANPER_AUTHORIZED_UID verificado.",
  );
fs.writeFileSync(
  ".firebaserc",
  JSON.stringify({ projects: { default: project } }, null, 2),
);
fs.writeFileSync(
  "firestore.authorized.rules",
  fs
    .readFileSync("firestore.rules.template", "utf8")
    .replace("__AUTHORIZED_UID__", uid),
);
const config = JSON.parse(fs.readFileSync("firebase.json", "utf8"));
config.firestore.rules = "firestore.authorized.rules";
fs.writeFileSync("firebase.authorized.json", JSON.stringify(config, null, 2));
console.log(
  "Configuración preparada para " +
    project +
    ". Ejecutar pruebas de emulador antes de firebase deploy --config firebase.authorized.json.",
);
