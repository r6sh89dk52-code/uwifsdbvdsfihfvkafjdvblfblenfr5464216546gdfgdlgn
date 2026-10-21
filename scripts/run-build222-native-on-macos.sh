#!/usr/bin/env bash
# One-command Build 222-inspired native beta runner for a LOCAL iPhone simulator.
# Never erases/uninstalls an existing simulator, clinical vault, or physical device.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="feat/build222-native-ui-parity-20261020"
WORK="$HOME/Downloads/DANPER_B222_NATIVE_RUN"
DERIVED="$WORK/DerivedData"
SIM_FILE="$WORK/simulator-udid.txt"
LOG="$WORK/xcodebuild.log"
APP_ID="pe.danper.saludmovil.native.preview"
FRESH=0
if [ "${1:-}" = "--fresh" ]; then FRESH=1; elif [ "$#" -ne 0 ]; then
  echo "Uso: bash scripts/run-build222-native-on-macos.sh [--fresh]" >&2
  exit 2
fi

fail() { echo "ERROR: $*" >&2; exit 1; }
step() { echo ""; echo "===== $* ====="; }
for cmd in git node npm python3 xcrun xcodebuild xcodegen sips codesign; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Falta $cmd. Comprueba Xcode, Node.js y XcodeGen."
done
[ -d "$ROOT/.git" ] || fail "No se detectó un checkout Git de DANPER."
cd "$ROOT"
CURRENT="$(git branch --show-current)"
[ "$CURRENT" = "$BRANCH" ] || fail "Rama actual $CURRENT; se requiere $BRANCH. No se cambió de rama."
[ -f native-ios/project.yml ] || fail "No existe native-ios/project.yml."
mkdir -p "$WORK"

step "1/7 Dependencias y recursos de demostración"
npm ci
node scripts/test-n2-build222-ui-parity.cjs
node scripts/prepare-n1s-ios-demo-resources.cjs
bash native-ios/scripts/make-app-icon.sh
[ -s native-ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon.png ] || fail "No se generó el icono."

step "2/7 Generación del proyecto Xcode"
( cd native-ios && xcodegen generate --spec project.yml )
echo "===== Pruebas críticas de borrado y arranque realmente vacío ====="
( cd native-ios && swift test --filter N2EmptyDemoSnapshotTests )


step "3/7 Selección de iPhone virtual independiente"
DEVICE_TYPE="$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; a=json.load(sys.stdin)["devicetypes"]; print(next((x["identifier"] for x in a if x["name"]=="iPhone 16"),""))')"
RUNTIME="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; a=[x for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable",False) and x.get("name","").startswith("iOS")]; print(a[-1]["identifier"] if a else "")')"
[ -n "$DEVICE_TYPE" ] && [ -n "$RUNTIME" ] || fail "No se encontró iPhone 16 con runtime iOS disponible."
SIM_ID=""
if [ "$FRESH" -eq 0 ] && [ -s "$SIM_FILE" ]; then
  CANDIDATE="$(cat "$SIM_FILE")"
  if xcrun simctl list devices -j | python3 -c 'import json,sys; wanted=sys.argv[1]; devices=json.load(sys.stdin)["devices"]; sys.exit(0 if any(d.get("udid")==wanted and d.get("isAvailable",True) for group in devices.values() for d in group) else 1)' "$CANDIDATE"; then
    SIM_ID="$CANDIDATE"
    echo "Reutilizando el simulador beta aislado: $SIM_ID (sin borrar sus datos)."
  fi
fi
if [ -z "$SIM_ID" ]; then
  NAME="DANPER B222 Nativa - Auto $(date +%Y%m%d-%H%M%S)"
  SIM_ID="$(xcrun simctl create "$NAME" "$DEVICE_TYPE" "$RUNTIME")"
  printf "%s\n" "$SIM_ID" > "$SIM_FILE"
  echo "Simulador NUEVO: $NAME ($SIM_ID)"
fi

step "4/7 Compilación nativa y firma ad hoc para el simulador"
echo "Guardando registro de Xcode: $LOG"
if ! xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative \
  -configuration Debug -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$SIM_ID" -destination-timeout 180 \
  -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual AD_HOC_CODE_SIGNING_ALLOWED=YES \
  build > "$LOG" 2>&1; then
  grep -nE "error:|BUILD FAILED|Signing|CodeSign" "$LOG" | tail -55 || true
  echo "Registro completo: $LOG" >&2
  fail "Falló la compilación en Xcode. No se instaló nada."
fi
grep -q "\*\* BUILD SUCCEEDED \*\*" "$LOG" || fail "Xcode no confirmó BUILD SUCCEEDED. Consulta $LOG"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/DANPERNative.app"
[ -d "$APP" ] || fail "Xcode compiló, pero no se encontró el paquete DANPERNative.app."
ACTUAL_ID="$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")"
[ "$ACTUAL_ID" = "$APP_ID" ] || fail "ID inesperado ($ACTUAL_ID); se bloqueó la instalación para proteger Build 222."
codesign --verify "$APP" || fail "La firma de la aplicación no se pudo verificar."
echo "BUILD SUCCEEDED — aplicación firmada con ID beta independiente."

step "5/7 Inicio del simulador"
STATE="$(xcrun simctl list devices -j | python3 -c 'import json,sys; wanted=sys.argv[1]; data=json.load(sys.stdin)["devices"]; print(next((d.get("state","") for group in data.values() for d in group if d.get("udid")==wanted),""))' "$SIM_ID")"
if [ "$STATE" != "Booted" ]; then xcrun simctl boot "$SIM_ID"; fi
open -a Simulator --args -CurrentDeviceUDID "$SIM_ID"
xcrun simctl bootstatus "$SIM_ID" -b

step "6/7 Instalación y apertura automática de DANPER"
xcrun simctl terminate "$SIM_ID" "$APP_ID" >/dev/null 2>&1 || true
xcrun simctl install "$SIM_ID" "$APP"
xcrun simctl launch "$SIM_ID" "$APP_ID"
# Optional evidence of the actual installed simulator UI, after launch.
sleep 2
xcrun simctl io "$SIM_ID" screenshot "$WORK/DANPER_B222_NATIVE_INICIO.png" >/dev/null 2>&1 || true

step "7/7 Abrir proyecto en Xcode (sin necesitar pulsar Cmd+R)"
open "$ROOT/native-ios/DANPERNative.xcodeproj"
echo ""
echo "LISTO: DANPER beta nativa iniciada automáticamente en el iPhone virtual."
echo "Simulador: $SIM_ID"
echo "Log de compilación: $LOG"
echo "Captura de pantalla: $WORK/DANPER_B222_NATIVE_INICIO.png"
echo "Esta ejecución no valida todas las funciones ni habilita uso con datos clínicos reales."
echo "Para crear OTRO simulador sin borrar el antiguo: bash scripts/run-build222-native-on-macos.sh --fresh"
