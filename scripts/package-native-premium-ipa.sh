#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
: "${BUILD_DIR:?Set BUILD_DIR to the isolated workflow output directory}"
APP="$BUILD_DIR/device/Build/Products/Release-iphoneos/DANPERNative.app"
test -s "$APP/DANPERNative"
test "$(xcrun lipo -archs "$APP/DANPERNative")" = arm64
if codesign -dv "$APP" > "$BUILD_DIR/logs/signing.txt" 2>&1; then
  echo 'Unexpected code signature in device Release build' >&2
  exit 1
fi
test ! -e "$APP/embedded.mobileprovision"
test ! -d "$APP/_CodeSignature"
mkdir -p "$BUILD_DIR/staging/Payload" "$BUILD_DIR/deliverables"
cp -R "$APP" "$BUILD_DIR/staging/Payload/"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")
NUMBER=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")
SOURCE_SHA=$(git rev-parse HEAD)
test "$VERSION" = 0.4.1
test "$NUMBER" = 11
IPA_NAME="DANPER_NATIVE_${VERSION}_${NUMBER}_${SOURCE_SHA:0:12}_CANDIDATE_UNSIGNED_NOT_CLINICALLY_VALIDATED.ipa"
IPA="$BUILD_DIR/deliverables/$IPA_NAME"
(cd "$BUILD_DIR/staging" && /usr/bin/zip -qry "$IPA" Payload)
unzip -t "$IPA" > "$BUILD_DIR/logs/zip-integrity.txt"
python3 scripts/verify-native-ipa.py "$IPA" \
  --resources native-ios/App/N1sDemoResources \
  --version "$VERSION" --build "$NUMBER" \
  --commit "$SOURCE_SHA" --output "$BUILD_DIR/deliverables/BUILD_PROVENANCE.json"
(cd "$BUILD_DIR/deliverables" && shasum -a 256 "$IPA_NAME" > SHA256SUMS.txt)
cat "$BUILD_DIR/deliverables/BUILD_PROVENANCE.json"
