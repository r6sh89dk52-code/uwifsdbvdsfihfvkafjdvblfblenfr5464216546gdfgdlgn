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
node scripts/prepare-n1s-ios-demo-resources.cjs
COUNT="$(grep -c 'N2OfficialArea(site:' native-ios/App/N2GeneratedOfficialAreas.swift || true)"
if [ "$COUNT" != "155" ]; then
  echo "ERROR: catálogo organizativo incompleto ($COUNT / 155)" >&2
  exit 1
fi
cd native-ios
xcodegen generate --spec project.yml
xcodebuild -resolvePackageDependencies -project DANPERNative.xcodeproj -scheme DANPERNative
LOG="$ROOT/DANPER_B11_SIMULATOR_BUILD.log"
echo "Compilando iOS Simulator · log: $LOG"
set +e
xcodebuild -project DANPERNative.xcodeproj -scheme DANPERNative \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/.build-b11-simulator" \
  CODE_SIGNING_ALLOWED=NO build >"$LOG" 2>&1
CODE=$?
set -e
if [ "$CODE" -ne 0 ]; then
  echo "ERROR: la compilación falló. Últimas 100 líneas:" >&2
  tail -n 100 "$LOG" >&2
  exit "$CODE"
fi
echo "PASS: compilación Debug de B11 para iOS Simulator."
echo "Aviso: este PASS no certifica los Excel, Face ID ni pruebas en iPhone físico."
