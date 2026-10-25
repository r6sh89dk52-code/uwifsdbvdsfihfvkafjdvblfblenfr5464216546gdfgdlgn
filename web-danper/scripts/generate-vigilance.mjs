import fs from "node:fs";
const raw = fs.readFileSync(
  "../native-ios/Sources/DanperCore/N2OccupationalVigilanceWorkbook.swift",
  "utf8",
);
const names = ["styles", "types", "relationships", "workbook", "workbookRels"];
const result = Object.fromEntries(
  names.map((name) => {
    const m = raw.match(
      new RegExp("let " + name + '="""\\r?\\n([\\s\\S]*?)\\r?\\n    """'),
    );
    if (!m) throw Error("Falta recurso nativo " + name);
    return [
      name,
      m[1]
        .split(/\r?\n/)
        .map((l) => (l.startsWith("    ") ? l.slice(4) : l))
        .join("\n"),
    ];
  }),
);
result.headers = JSON.parse(raw.match(/let headers=(\[[\s\S]*?\])/)[1]);
result.widths = JSON.parse(
  raw.match(/let widths:\[Double\]=(\[[\s\S]*?\])/)[1],
);
const codes = fs.readFileSync(
  "../native-ios/Sources/DanperCore/N2VigilanceOrganizationCodes.swift",
  "utf8",
);
result.codes = codes
  .match(/let officialRows="""\r?\n([\s\S]*?)\r?\n\s*"""/)[1]
  .trim()
  .split(/\r?\n/)
  .map((l) => {
    const [society, area, code] = l.trim().split("|");
    return { society, area, code };
  });
if (
  result.headers.length !== 17 ||
  result.widths.length !== 17 ||
  result.codes.length !== 155
)
  throw Error("Cambió el contrato de vigilancia; revisar Swift.");
fs.mkdirSync("src/generated", { recursive: true });
fs.writeFileSync(
  "src/generated/vigilance.json",
  JSON.stringify(result, null, 2) + "\n",
);
console.log(
  "Vigilancia: 17 columnas, estilos Swift y 155 códigos organizativos originales.",
);
