#!/bin/bash
# B11 SwiftUI verification. No install, reset, signing or change to an iPhone.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "DANPER B11 · Validación reproducible (simulador; datos ficticios)"
echo "Git revision: $(git rev-parse --short HEAD)"
for cmd in node xcodegen xcodebuild; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: falta $cmd" >&2
    exit 1
  fi
done
node scripts/audit-n2-swift-string-concatenations.cjs
node scripts/audit-n2-workspace-routing.cjs
node scripts/audit-n2-personal-import.cjs
node scripts/audit-n2-build222-backup-restore.cjs
node scripts/audit-n2-joint-indicator.cjs
node scripts/prepare-n1s-ios-demo-resources.cjs
COUNT="$(grep -c 'N2OfficialArea(site:' native-ios/App/N2GeneratedOfficialAreas.swift || true)"
if [ "$COUNT" != "155" ]; then
  echo "ERROR: catálogo organizativo incompleto ($COUNT / 155)" >&2
  exit 1
fi
cd native-ios
xcodegen generate --spec project.yml
xcodebuild -resolvePackageDependencies -project DANPERNative.xcodeproj -scheme DANPERNative
BUILD_OUTPUT="${DANPER_B11_BUILD_OUTPUT:-$HOME/Downloads/DANPER_B11_SIM_BUILDS}"
mkdir -p "$BUILD_OUTPUT"
LOG="$BUILD_OUTPUT/DANPER_B11_SIMULATOR_BUILD.log"
echo "Compilando iOS Simulator · log: $LOG"
set +e
xcodebuild -project DANPERNative.xcodeproj -scheme DANPERNative \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$BUILD_OUTPUT/DerivedData" \
  CODE_SIGNING_ALLOWED=NO build >"$LOG" 2>&1
CODE=$?
set -e
if [ "$CODE" -ne 0 ]; then
  echo "ERROR: compilación fallida. Diagnósticos Swift/Xcode:" >&2
  grep -n -E 'error:|fatal error:|BUILD FAILED' "$LOG" | tail -n 45 >&2 || true
  echo "Log completo: $LOG" >&2
  exit "$CODE"
fi
echo "PASS: compilación Debug de B11 para iOS Simulator."
echo "Ejecutando XCTest nativo del importador PERSONAL (solo datos sintéticos)…"
cd "$ROOT/native-ios"
if ! swift test --filter N2PersonalWorkbookImportTests; then
  echo "ERROR: fallaron las pruebas de lectura PERSONAL o conciliación." >&2
  exit 1
fi
if ! swift test --filter N2SyntheticResetScopeTests; then
  echo "ERROR: fallaron las pruebas de aislamiento del borrado ficticio." >&2
  exit 1
fi
echo "PASS: pruebas específicas de importación PERSONAL y borrado DEMO."
echo "Aviso: este PASS no certifica los Excel, Face ID ni pruebas en iPhone físico."
