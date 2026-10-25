#!/usr/bin/env bash
# N4 DM LAB: SOLO rama/checkout aislado, datos ficticios, iPhone 16 Simulator.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if ! grep -q 'pe.danper.saludmovil.native.n4dm.lab' native-ios/project.yml; then
  echo "ERROR: no es el proyecto N4 aislado. Se cancela."; exit 3
fi
CURRENT="$(git branch --show-current)"
if [ -n "$CURRENT" ] && [ "$CURRENT" != "feat/n4-descansos-medicos-isolated-20261025" ]; then
  echo "ERROR: rama distinta de N4: $CURRENT"; exit 4
fi
echo "=== N4 laboratorio aislado ==="
git status --short
git log -1 --oneline
for binary in xcodegen xcodebuild xcrun swift python3; do
  command -v "$binary" >/dev/null || { echo "Falta $binary"; exit 5; }
done
swift test --package-path native-ios --jobs 2 --filter DMCoreTests
swift test --package-path native-ios --jobs 2 --filter DMExcelWriterTests
cd native-ios
xcodegen generate --spec project.yml
UDID="$(xcrun simctl list -j devices available | python3 -c '
import json,sys
root=json.load(sys.stdin)
ids=[x["udid"] for arr in root["devices"].values()
     for x in arr if x.get("name")=="iPhone 16" and x.get("isAvailable",True)]
if not ids:raise SystemExit("No se encontró iPhone 16 Simulator instalado.")
print(ids[0])
')"
echo "Simulador: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator || true
xcodebuild -project DANPERNative.xcodeproj -scheme DANPERNative \
  -destination "platform=iOS Simulator,id=$UDID" \
  -parallel-testing-enabled NO \
  -only-testing:DANPERInteractionTests/DMModuleInteractionTests \
  test
echo "=== PRUEBAS N4 DE SIMULADOR EJECUTADAS ==="
echo "Para abrir manualmente el laboratorio:"
echo "xcrun simctl launch $UDID pe.danper.saludmovil.native.n4dm.lab --danper-dm-lab"
echo "No se generó IPA, ni se actualizó main, ni la rama nativa original."
