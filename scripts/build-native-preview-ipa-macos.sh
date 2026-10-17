#!/usr/bin/env bash
# Evaluation only: NEVER overwrite operational build222 or use for patient care.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: este IPA solo puede construirse en macOS con Xcode." >&2; exit 1
fi
if [[ "$(printenv DANPER_PREVIEW_ACK || true)" != "ACEPTO_SOLO_EVALUACION" ]]; then
  echo "BLOQUEADO: aun no hay paridad operativa con build222." >&2
  echo "Uso exclusivo para pruebas con datos ficticios:"
  echo "DANPER_PREVIEW_ACK=ACEPTO_SOLO_EVALUACION bash scripts/build-native-preview-ipa-macos.sh"
  exit 1
fi
for command in xcodebuild xcodegen node npm ditto unzip git; do
  command -v "$command" >/dev/null || { echo "Falta: $command" >&2; exit 1; }
done
cd "$ROOT"
if [[ "$(git branch --show-current)" != "feat/build222-native-parity-20261017" ]]; then
  echo "ERROR: abre primero la rama N2. No empaquetar main." >&2; exit 1
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
npm ci --no-fund --ignore-scripts
node scripts/prepare-n1s-ios-demo-resources.cjs
(
 cd native-ios
 bash scripts/make-app-icon.sh
 xcodegen generate --spec project.yml
 xcodebuild -project DANPERNative.xcodeproj -scheme DANPERNative \
   -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
   -derivedDataPath "$WORK/Derived" CODE_SIGNING_ALLOWED=NO \
   CODE_SIGNING_REQUIRED=NO \
   MARKETING_VERSION=0.4.0 CURRENT_PROJECT_VERSION=9 build
)
APP="$WORK/Derived/Build/Products/Release-iphoneos/DANPERNative.app"
test -d "$APP"
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
if [[ "$BUNDLE" != "pe.danper.saludmovil.native.preview" ]]; then
  echo "ERROR: identificador inesperado; detenido." >&2; exit 1
fi
mkdir -p "$WORK/Payload" "$ROOT/native-preview-artifacts"
cp -R "$APP" "$WORK/Payload/"
OUTPUT="$ROOT/native-preview-artifacts/DANPER_N2_EVALUACION_UNSIGNED.ipa"
ditto -c -k --sequesterRsrc --keepParent "$WORK/Payload" "$OUTPUT"
unzip -t "$OUTPUT" >/dev/null
echo "IPA DE EVALUACION SIN FIRMAR: $OUTPUT"
shasum -a 256 "$OUTPUT"
echo "NO EQUIVALE A BUILD222. No usar con pacientes ni reemplazar build222."
echo "SideStore/AltStore debe firmar el paquete al instalar; pendiente de validar."

