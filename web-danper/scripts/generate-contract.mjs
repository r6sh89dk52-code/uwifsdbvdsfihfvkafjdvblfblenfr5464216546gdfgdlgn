import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
const root = path.resolve("..");
const source = (p) => fs.readFileSync(path.join(root, p), "utf8");
const swift = source(
  "native-ios/Sources/DanperCore/N2ClinicalFormOptions.swift",
);
function array(text, name) {
  const m = text.match(
    new RegExp(
      "(?:let|var) " +
        name +
        "(?:\\s*:\\s*\\[String\\])?\\s*=\\s*(\\[[\\s\\S]*?\\])",
    ),
  );
  if (!m) throw Error("Contrato Swift ausente: " + name);
  return JSON.parse(m[1]);
}
const segments = source(
  "native-ios/Sources/DanperCore/N2OsteomuscularSegments.swift",
);
const links = source(
  "native-ios/Sources/DanperCore/N2UserReviewedKardexLinks.swift",
);
const additional = [
  ...links.matchAll(
    /Link\(kardexID:"([^"]+)",kardexName:"([^"]+)",\s*clinicalCode:"([^"]+)",clinicalName:"([^"]+)",\s*clinicalUnit:"([^"]+)",requiresPhysicalReview:(true|false)\)/g,
  ),
].map((m) => ({
  kardexCode: m[1],
  kardexName: m[2],
  clinicalCode: m[3],
  clinicalName: m[4],
  clinicalUnit: m[5],
  requiresPhysicalReview: m[6] === "true",
}));
const products = JSON.parse(source("src/products.json"));
const pairs = source("src/reviewedKardexAssociations.ts")
  .match(/const authorizedPairs="([^"]+)"/)[1]
  .split(";")
  .map((x) => {
    const [id, code] = x.split(":");
    return { kardexCode: "E-" + id, clinicalCode: code };
  });
if (
  products.length !== 432 ||
  new Set(products.map((p) => p.code)).size !== 432 ||
  pairs.length !== 86 ||
  additional.length !== 6
)
  throw Error(
    "Diferencia de catálogos: revisar el HEAD nativo antes de generar.",
  );
for (const link of additional)
  if (
    !products.some(
      (p) =>
        p.code === link.clinicalCode &&
        p.name === link.clinicalName &&
        p.unit === link.clinicalUnit,
    )
  )
    throw Error("Asociación adicional incompatible");
const paths = [
  "src/products.json",
  "src/kardexCatalog.ts",
  "src/reviewedKardexAssociations.ts",
  "native-ios/Sources/DanperCore/N2ClinicalFormOptions.swift",
  "native-ios/Sources/DanperCore/N2OsteomuscularSegments.swift",
  "native-ios/Sources/DanperCore/N2ProcedureRules.swift",
  "native-ios/Sources/DanperCore/N2UserReviewedKardexLinks.swift",
];
const contract = {
  sourceHead: "9bec8e01ccbb3f1a674372cf6e48df049dc4f014",
  categories: array(swift, "categories"),
  systems: array(swift, "systems"),
  diagnoses: array(swift, "diagnoses"),
  segments: [
    ...new Set([
      ...array(segments, "specific"),
      ...array(segments, "historical"),
    ]),
  ],
  procedures: array(
    source("native-ios/Sources/DanperCore/N2ProcedureRules.swift"),
    "procedures",
  ),
  additional,
  pairs,
  hashes: Object.fromEntries(
    paths.map((p) => [
      p,
      crypto.createHash("sha256").update(source(p)).digest("hex"),
    ]),
  ),
};
fs.mkdirSync("src/generated", { recursive: true });
fs.writeFileSync(
  "src/generated/contract.json",
  JSON.stringify(contract, null, 2) + "\n",
);
fs.copyFileSync(path.join(root, "src/products.json"), "legacy/products.json");
console.log(
  "Contrato generado: 432 productos; 86 asociaciones originales + 6 adicionales; " +
    contract.procedures.length +
    " procedimientos.",
);
