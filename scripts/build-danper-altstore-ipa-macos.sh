#!/bin/bash
# DANPER Salud Móvil — UNSIGNED iPhoneOS Release IPA for AltStore Classic.
# AltStore/AltServer handles signing when the user installs the IPA.
# Never touches the installed Build 222 app, its vault, or an iPhone device.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BRANCH="feat/build222-native-ui-parity-20261020"
BUNDLE_ID="pe.danper.saludmovil.native"
SCHEME="DANPERNative"

if [[ "$(git branch --show-current)" != "$BRANCH" ]]; then
  echo "ERROR: cambia a la rama $BRANCH antes de generar el IPA." >&2
  exit 2
fi

for tool in git node xcodegen xcodebuild ditto unzip shasum lipo; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: falta $tool. Instala/configura Xcode completo en el Mac." >&2
    exit 2
  fi
done

STAMP="$(date +%Y%m%d_%H%M%S)"
SHA="$(git rev-parse --short HEAD)"
OUT="$HOME/Downloads/DANPER_ALTSTORE_IPA_${STAMP}_${SHA}"
DERIVED="$OUT/DerivedData"
APP="$DERIVED/Build/Products/Release-iphoneos/DANPERNative.app"
IPA="$OUT/DANPER_Salud_Movil_SwiftUI_AltStore_${SHA}.ipa"
mkdir -p "$OUT"

echo "=== DANPER SALUD MÓVIL · IPA SIN FIRMAR PARA ALTSTORE ==="
echo "Rama: $BRANCH  |  Commit: $SHA"
echo "Bundle ID independiente: $BUNDLE_ID"
echo "Destino: $OUT"
echo "No se necesita Apple Team ID ni perfil de aprovisionamiento."
echo "La firma y la instalación las realizará AltStore."

echo "=== COMPROBACIONES DE PARIDAD JAVASCRIPT ==="
if ! node scripts/test-n2-build222-ui-parity.cjs >"$OUT/paridad.log" 2>&1; then
  tail -n 65 "$OUT/paridad.log" >&2
  echo "ERROR: paridad fallida. Log: $OUT/paridad.log" >&2
  exit 1
fi

echo "=== REGENERANDO PROYECTO XCODE ==="
if ! xcodegen generate --spec native-ios/project.yml >"$OUT/xcodegen.log" 2>&1; then
  tail -n 65 "$OUT/xcodegen.log" >&2
  exit 1
fi

echo "=== COMPILANDO RELEASE PARA IPHONE FÍSICO (SIN FIRMA) ==="
if ! xcodebuild \
  -project native-ios/DANPERNative.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED" \
  -jobs 2 \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  build >"$OUT/build.log" 2>&1; then
  echo "ERROR: falló la compilación para iPhone." >&2
  grep -nE 'error:|\\*\\* BUILD FAILED \\*\\*' "$OUT/build.log" | tail -n 55 >&2 || true
  echo "Log completo: $OUT/build.log"
  exit 1
fi

if [[ ! -d "$APP" || ! -f "$APP/Info.plist" || ! -f "$APP/DANPERNative" ]]; then
  echo "ERROR: no se encontró la app compilada dentro de Release-iphoneos." >&2
  exit 1
fi

ACTUAL="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")"
if [[ "$ACTUAL" != "$BUNDLE_ID" ]]; then
  echo "ERROR: bundle ID incorrecto ($ACTUAL). No se empaqueta." >&2
  exit 1
fi

if ! lipo -archs "$APP/DANPERNative" | tr ' ' '\\n' | grep -qx arm64; then
  echo "ERROR: el ejecutable no contiene la arquitectura arm64 para iPhone." >&2
  exit 1
fi

echo "=== EMPAQUETANDO PAYLOAD/DANPERNative.app ==="
mkdir -p "$OUT/package/Payload"
ditto "$APP" "$OUT/package/Payload/DANPERNative.app"
(
  cd "$OUT/package"
  ditto -c -k --keepParent Payload "$IPA"
)
unzip -tq "$IPA" >"$OUT/zip-test.log"
if ! unzip -Z -1 "$IPA" | grep '^Payload/DANPERNative.app/' >/dev/null; then
  echo "ERROR: el IPA no contiene Payload/DANPERNative.app." >&2
  exit 1
fi

shasum -a 256 "$IPA" >"$OUT/SHA256.txt"
rm -rf "$OUT/package"

echo "=== IPA SIN FIRMAR GENERADO CORRECTAMENTE ==="
echo "$IPA"
echo "Archivo SHA256: $OUT/SHA256.txt"
echo "NOTA: AltStore Classic firmará este IPA al instalarlo."
echo "No desinstales Build 222 y no importes datos reales sin respaldo."
open "$OUT"
