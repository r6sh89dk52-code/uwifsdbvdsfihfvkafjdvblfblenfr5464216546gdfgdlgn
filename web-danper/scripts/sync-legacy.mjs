import fs from "node:fs";
import path from "node:path";
const root = path.resolve(".."),
  target = path.resolve("legacy");
const wanted = new Set();
function resolve(p) {
  for (const suffix of ["", ".ts", ".tsx", ".json"])
    if (fs.existsSync(p + suffix) && fs.statSync(p + suffix).isFile())
      return p + suffix;
  throw Error("Dependencia oficial ausente: " + p);
}
function add(p) {
  p = resolve(p);
  if (!p.startsWith(path.join(root, "src") + path.sep))
    throw Error("Dependencia fuera de src oficial");
  if (wanted.has(p)) return;
  wanted.add(p);
  if (/\.tsx?$/.test(p)) {
    const text = fs.readFileSync(p, "utf8");
    for (const m of text.matchAll(/(?:from\s*|import\s*)['"](\.[^'"]+)['"]/g))
      add(path.resolve(path.dirname(p), m[1]));
  }
}
function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p);
    else if (/\.tsx?$/.test(p)) {
      const text = fs.readFileSync(p, "utf8");
      for (const m of text.matchAll(/['"](?:\.\.\/)+legacy\/([^'"]+)['"]/g))
        add(path.join(root, "src", m[1]));
    }
  }
}
walk("src");
walk("tests");
fs.mkdirSync(target, { recursive: true });
for (const p of wanted) {
  const rel = path.relative(path.join(root, "src"), p),
    dest = path.resolve(target, rel);
  if (!dest.startsWith(target + path.sep)) throw Error("Destino inválido");
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.copyFileSync(p, dest);
}
// Remove only unused files in the copy created for this web project, never root src.
function prune(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.resolve(dir, e.name);
    if (!p.startsWith(target + path.sep)) throw Error("Ruta fuera de legacy");
    if (e.isDirectory()) prune(p);
    else if (!wanted.has(path.join(root, "src", path.relative(target, p))))
      fs.unlinkSync(p);
  }
}
prune(target);
console.log(
  wanted.size +
    " módulos/recursos oficiales sincronizados sin duplicar listas maestras.",
);
