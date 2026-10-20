#!/usr/bin/env bash
# DANPER B11 — diagnostico local de Mac, SIN GitHub Actions / IPA / firma.
# Lanzar desde el worktree aislado: bash docs/B11_PROBAR_MAC_SIN_ACTIONS.command
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_BRANCH="fix/b11-personal-sedes-seguras-20261020"
LOG="${HOME}/Downloads/DANPER_B11_SEDES_MAC_$(date +%Y%m%d_%H%M%S).log"
DERIVED="${HOME}/Downloads/DANPER_B11_SEDES_DERIVED"
mkdir -p "${HOME}/Downloads"

exec > >(tee -a "${LOG}") 2>&1
FIXTURES=""
trap 'rc=$?; if [ -n "${FIXTURES:-}" ] && [ -d "$FIXTURES" ]; then rm -rf "$FIXTURES"; fi; echo ""; if [ "$rc" -ne 0 ]; then echo "ERROR de comprobación local (salida $rc)."; else echo "PRUEBA LOCAL TERMINADA: compilación Simulator OK."; fi; echo "DIAGNÓSTICO: ${LOG}"; exit "$rc"' EXIT

echo "=== DANPER B11: validación aislada sin GitHub Actions ==="
echo "Proyecto: $ROOT"
echo "Log: $LOG"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: no se encontró repositorio Git en esta carpeta."
  exit 2
fi
BRANCH="$(git branch --show-current)"
HEAD="$(git rev-parse HEAD)"
echo "Rama: ${BRANCH:-DETACHED}"
echo "Commit: $HEAD"
if [ "$BRANCH" != "$EXPECTED_BRANCH" ] && [ "$BRANCH" != "" ]; then
  echo "ERROR: rama inesperada. Debes usar el worktree de B11."
  exit 3
fi
if git status --porcelain --untracked-files=no | grep -q .; then
  echo "ERROR: hay cambios locales en archivos versionados. No se compilará sobre un árbol modificado."
  exit 4
fi

for cmd in git node npm swiftc swift xcodegen xcodebuild; do
  if ! command -v "$cmd" >/dev/null; then
    echo "ERROR: falta $cmd. Revisa Xcode, Node.js y XcodeGen."
    exit 5
  fi
done
xcodebuild -version
swift --version
node --version

echo "=== 1. Instalar dependencias de Node sin scripts de postinstalación ==="
npm ci --ignore-scripts --no-fund
echo "=== 2. Recursos DEMO sintéticos y 155 áreas oficiales ==="
node scripts/prepare-n1s-ios-demo-resources.cjs

echo "=== 3. Puertas estáticas de seguridad ==="
node scripts/audit-n2-workspace-routing.cjs
node scripts/audit-n2-personal-import.cjs
node scripts/audit-n2-build222-backup-restore.cjs
node scripts/audit-n2-joint-indicator.cjs

echo "=== 4. Generar SOLO fixtures ficticios, sin información clínica real ==="
FIXTURES="$(mktemp -d "${TMPDIR:-/tmp}/danper-b11-fixtures.XXXXXX")"
export DANPER_N1_FIXTURE_DIR="$FIXTURES"
for generator in \
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
  generate-n2-stock-commands-fixtures.cjs; do
    node "scripts/$generator"
done
node scripts/generate-n2-procedure-parity.cjs

echo "=== 5. Validación sintáctica de SwiftUI ==="
swiftc -frontend -parse native-ios/App/*.swift
echo "=== 6. Swift core y pruebas de importación PERSONAL ==="
(
  cd native-ios
  swift test --jobs 2 --filter N2PersonalWorkbookImportTests
)
echo "=== 7. Suite completa del núcleo Swift ==="
(
  cd native-ios
  swift test --jobs 2
)
echo "=== 8. Generar proyecto Xcode ==="
(
  cd native-ios
  xcodegen generate --spec project.yml
)
echo "=== 9. Compilar realmente para iOS Simulator ==="
(
  cd native-ios
  xcodebuild -project DANPERNative.xcodeproj \
    -scheme DANPERNative \
    -configuration Debug \
    -sdk iphonesimulator \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build
)
echo "=== 10. Abrir Xcode para prueba manual de simulador ==="
open "$ROOT/native-ios/DANPERNative.xcodeproj"
echo "Usa un iPhone Simulator disponible y pulsa Cmd+R en Xcode."
