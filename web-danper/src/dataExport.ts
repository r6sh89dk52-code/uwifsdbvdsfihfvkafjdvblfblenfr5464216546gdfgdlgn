import { zipSync, strToU8 } from "fflate";
import native from "./generated/vigilance.json" with { type: "json" };
const esc = (v: unknown) =>
  String(v ?? "")
    .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "")
    .slice(0, 32767)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
function column(n: number) {
  let s = "";
  for (n++; n; n = Math.floor((n - 1) / 26))
    s = String.fromCharCode(65 + ((n - 1) % 26)) + s;
  return s;
}
/** Explicit data export, not a substitute for an unknown official template. */
export function exportDataSheet(
  name: string,
  headers: string[],
  rows: (string | number | boolean)[][],
) {
  if (!headers.length || headers.length > 100 || rows.length > 100000)
    throw Error("Exportación fuera de límites");
  const all = [headers, ...rows];
  const cells = all
    .map(
      (row, i) =>
        `<row r="${i + 1}">` +
        row
          .map(
            (v, j) =>
              `<c r="${column(j)}${i + 1}" s="${i === 0 ? 1 : typeof v === "number" ? 3 : 6}"${typeof v === "number" ? "" : ' t="inlineStr"'}>${typeof v === "number" && Number.isFinite(v) ? "<v>" + v + "</v>" : '<is><t xml:space="preserve">' + esc(v) + "</t></is>"}</c>`,
          )
          .join("") +
        "</row>",
    )
    .join("");
  const sheet = `<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><dimension ref="A1:${column(headers.length - 1)}${all.length}"/><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><cols>${headers.map((_, i) => `<col min="${i + 1}" max="${i + 1}" width="24" customWidth="1"/>`).join("")}</cols><sheetData>${cells}</sheetData><autoFilter ref="A1:${column(headers.length - 1)}${all.length}"/></worksheet>`;
  return zipSync(
    Object.fromEntries(
      Object.entries({
        "[Content_Types].xml": native.types,
        "_rels/.rels": native.relationships,
        "xl/workbook.xml": native.workbook.replace(
          "VIGILACIA OCUPACIONAL",
          esc(name).slice(0, 31),
        ),
        "xl/_rels/workbook.xml.rels": native.workbookRels,
        "xl/styles.xml": native.styles,
        "xl/worksheets/sheet1.xml": sheet,
      }).map(([k, v]) => [k, strToU8(v)]),
    ),
    { level: 6 },
  );
}
