#!/usr/bin/env bash
# DANPER N2 — reproducible synthetic-only local validation on macOS.
# Never reads an iPhone backup or clinical roster; never erases simulator data.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for cmd in node npm swift xcodegen xcodebuild; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Falta el comando: $cmd" >&2; exit 1; }
done

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$HOME/Downloads/DANPER_N2_VALIDACION_$STAMP"
export DANPER_N1_FIXTURE_DIR="$OUT/fixtures"
mkdir -p "$DANPER_N1_FIXTURE_DIR"
echo "DANPER N2 · pruebas solamente con datos SINTÉTICOS"
echo "Informe y fixtures: $OUT"
echo "Rama: $(git branch --show-current)"
echo "Commit: $(git rev-parse --short HEAD)"

echo "=== DEPENDENCIAS JAVASCRIPT (fijadas por lockfile) ==="
npm ci --no-audit --no-fund >"$OUT/npm.log" 2>&1 || {
  tail -n 55 "$OUT/npm.log"
  echo "Error de dependencias; log: $OUT/npm.log"
  exit 1
}

echo "=== COMPROBACIONES JAVASCRIPT ==="
node --check scripts/test-n2-build222-ui-parity.cjs
node scripts/test-n2-build222-ui-parity.cjs 2>&1 | tee "$OUT/paridad-n2.log"

echo "=== GENERACIÓN ORDENADA DE FIXTURES FICTICIAS ==="
for name in \
  generate-native-compat-fixtures.cjs \
  generate-n1e-clinical-fixtures.cjs \
  generate-n1f-lossless-fixtures.cjs \
  generate-n1h-clinical-parity.cjs \
  generate-n1p-excel-parity.cjs \
  generate-n1q-reconciliation-fixtures.cjs \
  generate-n1r-stored-xlsx-template.cjs \
  generate-n1s-official-excel-fixtures.cjs \
  generate-n2-approved-fixture.cjs \
  generate-n2-nursing-parity.cjs \
  generate-n2-procedure-parity.cjs \
  generate-n2-stock-commands-fixtures.cjs
do
  echo "Generando: $name"
  node "scripts/$name" >>"$OUT/fixtures.log" 2>&1 || {
    tail -n 65 "$OUT/fixtures.log"
    echo "Falló la generación: $name. Log: $OUT/fixtures.log"
    exit 1
  }
done

for file in \
  synthetic.danperbackup \
  tampered.danperbackup \
  downgraded.danperbackup \
  n1e-clinical-stock.json \
  n1f-source.json \
  n1s-indicator-plan.json \
  n1s-indicator-template-store.zip \
  n1q-reviewed-expected.json \
  n2-reviewed-approved.json
do
  test -s "$DANPER_N1_FIXTURE_DIR/$file" || {
    echo "Falta una fixture requerida: $file" >&2
    exit 1
  }
done

echo "=== PRUEBAS SWIFT COMPLETAS ==="
if swift test --package-path native-ios --jobs 2 >"$OUT/swift-test.log" 2>&1; then
  grep -E "Executed [0-9]+ tests|Test Suite 'All tests'" "$OUT/swift-test.log" | tail -n 8 || true
else
  echo "FALLÓ Swift Test. Últimas incidencias:"
  grep -nE 'error:|failed|Executed [0-9]+ tests' "$OUT/swift-test.log" | tail -n 65 || true
  echo "Adjunta este log: $OUT/swift-test.log"
  exit 1
fi

echo "=== XCODEGEN ==="
xcodegen generate --spec native-ios/project.yml >"$OUT/xcodegen.log" 2>&1 || {
  cat "$OUT/xcodegen.log"; exit 1;
}

echo "=== COMPILACIÓN IOS SIMULATOR ==="
if xcodebuild \
  -project native-ios/DANPERNative.xcodeproj \
  -scheme DANPERNative \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -jobs 2 \
  CODE_SIGNING_ALLOWED=NO \
  build >"$OUT/xcodebuild.log" 2>&1; then
  grep -E '\*\* BUILD SUCCEEDED \*\*' "$OUT/xcodebuild.log" | tail -n 1
else
  echo "FALLÓ la compilación iOS:"
  grep -nE 'error:|\*\* BUILD FAILED \*\*' "$OUT/xcodebuild.log" | tail -n 45 || true
  echo "Adjunta este log: $OUT/xcodebuild.log"
  exit 1
fi

echo "=== VALIDACIÓN APROBADA ==="
echo "Logs y fixtures sintéticas: $OUT"
open native-ios/DANPERNative.xcodeproj
