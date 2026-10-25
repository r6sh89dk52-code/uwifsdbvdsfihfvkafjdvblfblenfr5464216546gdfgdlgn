#!/bin/bash
# DANPER Salud Móvil — signed device IPA from a local macOS Xcode installation.
# Signs with the Apple Development team configured in Xcode/Keychain.
# Does not touch an installed iPhone app, its local vault or the Build 222 bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
BRANCH="feat/build222-native-ui-parity-20261020"
EXPECTED_BUNDLE="pe.danper.saludmovil.native"

if [[ "$(git branch --show-current)" != "$BRANCH" ]]; then
  echo "ERROR: este ejecutor requiere la rama $BRANCH." >&2
  exit 2
fi
for tool in git node xcodegen xcodebuild codesign security ditto unzip; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: falta $tool. Selecciona Xcode completo con xcode-select." >&2
    exit 2
  }
done

TEAM="${DANPER_APPLE_TEAM:-}"
if [[ -z "$TEAM" ]]; then
  # Use the only available Apple Development identity, if unambiguous.
  teams="$(security find-identity -v -p codesigning 2>/dev/null |
    sed -nE 's/.*Apple Development:.*\(([A-Z0-9]{10})\).*/\1/p' |
    sort -u || true)"
  if [[ "$(printf '%s\n' "$teams" | sed '/^$/d' | wc -l | tr -d ' ')" == "1" ]]; then
    TEAM="$teams"
  fi
fi
if [[ -z "$TEAM" ]]; then
  if [[ -t 0 ]]; then
    echo "Consulta tu Team ID en Xcode → Settings → Accounts → tu equipo."
    read -r -p "Apple Development Team ID (10 caracteres): " TEAM
  else
    echo "ERROR: falta el Team ID. Ejecuta DANPER_APPLE_TEAM=XXXXXXXXXX bash scripts/build-danper-iphone-ipa-macos.sh" >&2
    exit 2
  fi
fi
if [[ ! "$TEAM" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "ERROR: formato incorrecto del Team ID." >&2
  exit 2
fi

STAMP="$(date +%Y%m%d_%H%M%S)"
SHORT="$(git rev-parse --short HEAD)"
OUT="$HOME/Downloads/DANPER_IPHONE_IPA_${STAMP}_${SHORT}"
ARCHIVE="$OUT/DANPERNative.xcarchive"
LOG="$OUT/archive.log"
IPA="$OUT/DANPER_Salud_Movil_Nativa_${SHORT}.ipa"
mkdir -p "$OUT"

echo "=== DANPER SALUD MÓVIL · IPHONE REAL ==="
echo "Rama: $BRANCH"
echo "Commit: $SHORT"
echo "Bundle: $EXPECTED_BUNDLE (NO sustituye a Build 222)"
echo "Destino: $OUT"
echo "Certificados personales y claves permanecen en el Keychain de este Mac."
echo "Conecta y desbloquea el iPhone, confía en el Mac y verifica tu cuenta Apple en Xcode."

# Fail closed if baseline parity checks fail; don't sign a known-broken app.
echo "=== VALIDANDO PARIDAD NATIVA ANTES DE FIRMAR ==="
if ! node scripts/test-n2-build222-ui-parity.cjs >"$OUT/native-parity.log" 2>&1; then
  tail -n 65 "$OUT/native-parity.log" >&2
  echo "ERROR: paridad N2 fallida, no se crea IPA. Log: $OUT/native-parity.log" >&2
  exit 1
fi

# Generate the Xcode project with the checked-in spec.
xcodegen generate --spec native-ios/project.yml >"$OUT/xcodegen.log" 2>&1 || {
  cat "$OUT/xcodegen.log" >&2
  exit 1
}

echo "=== COMPILANDO Y FIRMANDO ARCHIVO RELEASE ==="
if ! xcodebuild \
    -project native-ios/DANPERNative.xcodeproj \
    -scheme DANPERNative \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates \
    CODE_SIGN_STYLE=Automatic \
    CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM="$TEAM" \
    PRODUCT_BUNDLE_IDENTIFIER="$EXPECTED_BUNDLE" \
    archive >"$LOG" 2>&1; then
  echo "ERROR: Xcode no pudo archivar/firmar. Primeros errores:" >&2
  grep -nE 'error:|\*\* ARCHIVE FAILED \*\*|No signing certificate|provisioning' "$LOG" | tail -n 45 >&2 || true
  echo "Log completo: $LOG"
  exit 1
fi

APP="$ARCHIVE/Products/Applications/DANPERNative.app"
if [[ ! -d "$APP" || ! -f "$APP/embedded.mobileprovision" ]]; then
  echo "ERROR: el archivo no contiene una app con perfil para iPhone." >&2
  exit 1
fi
ACTUAL=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
if [[ "$ACTUAL" != "$EXPECTED_BUNDLE" ]]; then
  echo "ERROR: bundle ID inesperado $ACTUAL; se rechaza el IPA." >&2
  exit 1
fi
if ! codesign --verify --deep --strict --verbose=2 "$APP" >"$OUT/signature-check.log" 2>&1; then
  echo "ERROR: fallo de firma; no se empaqueta un IPA inválido." >&2
  cat "$OUT/signature-check.log" >&2
  exit 1
fi
codesign -dv --verbose=4 "$APP" >"$OUT/signature-info.log" 2>&1 || true
if ! grep -Fq "TeamIdentifier=$TEAM" "$OUT/signature-info.log"; then
  echo "ERROR: la firma no corresponde al Team seleccionado." >&2
  exit 1
fi

echo "=== CREANDO IPA FIRMADO ==="
mkdir -p "$OUT/package/Payload"
ditto "$APP" "$OUT/package/Payload/DANPERNative.app"
(cd "$OUT/package" && ditto -c -k --keepParent Payload "$IPA")
unzip -tq "$IPA" >"$OUT/ipa-zip-test.log"
if ! unzip -Z -1 "$IPA" | grep '^Payload/DANPERNative.app/' >/dev/null; then
  echo "ERROR: contenido de IPA inesperado." >&2
  exit 1
fi
rm -rf "$OUT/package"

echo "=== IPA GENERADO ==="
echo "$IPA"
echo "IMPORTANTE: firmar no certifica paridad clínica ni migración real."
echo "Conserva Build 222 y su respaldo; instala este bundle en paralelo."
open "$OUT"
