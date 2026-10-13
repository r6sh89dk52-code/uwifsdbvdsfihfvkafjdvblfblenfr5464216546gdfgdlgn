#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo 'ERROR: Se necesita macOS y Xcode'; exit 2; }
[ -d ios/App/App.xcworkspace ] || { echo 'ERROR: Ejecuta npx cap add ios y npx cap sync ios'; exit 2; }
[ -f resources/icon.png ] || { echo 'ERROR: Falta icono'; exit 2; }
node scripts/apply-ios-icon.mjs
mkdir -p outputs
xcodebuild \
  -workspace ios/App/App.xcworkspace \
  -scheme App \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$PWD/outputs/DanperSalud.xcarchive" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  DEVELOPMENT_TEAM='' \
  archive
APP="$PWD/outputs/DanperSalud.xcarchive/Products/Applications/App.app"
[ -d "$APP" ] || { echo 'ERROR: Xcode no generó App.app'; exit 3; }
[ -f "$APP/Info.plist" ] || { echo 'ERROR: falta Info.plist'; exit 3; }
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/Payload"
cp -R "$APP" "$TMP/Payload/"
VERSION=$(node -p "require('./package.json').version")
# Las versiones del IPA deben coincidir con la release, sin modificar el ejecutable.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$TMP/Payload/App.app/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 140" "$TMP/Payload/App.app/Info.plist"
FILENAME="DanperSaludMovil-v${VERSION}-SIN_FIRMAR.ipa"
( cd "$TMP" && /usr/bin/zip -qry "$OLDPWD/outputs/$FILENAME" Payload )
( cd outputs && shasum -a 256 "$FILENAME" > "$FILENAME.sha256" )
/usr/bin/unzip -t "outputs/$FILENAME" | tail -1
printf '\nIPA generado: outputs/%s\n' "$FILENAME"
printf 'IMPORTANTE: Es un IPA sin firmar. SideStore deberá firmarlo al instalar. SOLO DATOS FICTICIOS.\n'
