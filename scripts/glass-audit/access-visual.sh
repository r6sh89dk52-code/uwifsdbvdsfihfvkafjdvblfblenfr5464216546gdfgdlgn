#!/usr/bin/env bash
# Visual-only regression: one existing UI method, two phone sizes. No authentication events.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DANPER_AUDIT_OUT:?}"
OUT="$DANPER_AUDIT_OUT"; DD="$OUT/DerivedData"
mkdir -p "$OUT"
git rev-parse HEAD > "$OUT/SOURCE_SHA.txt"
xcodebuild -version > "$OUT/xcode-version.txt"
test "$(uname -m)" = arm64
npm ci --ignore-scripts --no-audit --no-fund > "$OUT/npm.log" 2>&1
node scripts/prepare-n1s-ios-demo-resources.cjs > "$OUT/resources.log" 2>&1
node scripts/glass-audit/identity.cjs
node scripts/test-n2-premium-redesign.cjs
node scripts/test-n2-glass-clinical.cjs
node scripts/test-n2-build222-ui-parity.cjs
if ! command -v xcodegen >/dev/null; then brew install xcodegen; fi
(cd native-ios && bash scripts/make-app-icon.sh && xcodegen generate --spec project.yml) > "$OUT/xcodegen.log" 2>&1
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
 -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" \
 ONLY_ACTIVE_ARCH=NO ARCHS=arm64 build-for-testing > "$OUT/build.log" 2>&1
xcrun simctl list runtimes -j > "$OUT/runtimes.json"
SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
RUNTIME=$(python3 - "$OUT/runtimes.json" "$SDK_VERSION" <<'PY'
import json,sys
rows=[r for r in json.load(open(sys.argv[1]))['runtimes'] if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-') and r['version'].split('.')[:2]==sys.argv[2].split('.')[:2]]
assert rows
print(rows[0]['identifier'])
PY
)
SIM_ID=''
cleanup(){
 if test -n "$SIM_ID"; then xcrun simctl shutdown "$SIM_ID" || true; xcrun simctl delete "$SIM_ID" || true; fi
}
trap cleanup EXIT
for PHONE in iPhone-16 iPhone-SE-3rd-generation; do
 SIM_ID=$(xcrun simctl create "DANPER-ACCESS-VISUAL-$PHONE" "com.apple.CoreSimulator.SimDeviceType.$PHONE" "$RUNTIME")
 echo "$PHONE $SIM_ID" >> "$OUT/simulators.txt"
 xcrun simctl boot "$SIM_ID"
 xcrun simctl bootstatus "$SIM_ID" -b
 xcrun simctl status_bar "$SIM_ID" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
 status=0
 xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -derivedDataPath "$DD" \
  -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 360 \
  -resultBundlePath "$OUT/$PHONE.xcresult" \
  -only-testing:DANPERInteractionTests/N2PremiumRedesignTests/testAccessLightAndDark \
  test-without-building > "$OUT/$PHONE.log" 2>&1 || status=$?
 python3 scripts/glass-audit/check-xcresult.py "$OUT/$PHONE.xcresult" 1 || status=1
 xcrun xcresulttool export attachments --path "$OUT/$PHONE.xcresult" --output-path "$OUT/$PHONE-attachments" > "$OUT/$PHONE-export.log" 2>&1 || status=1
 test "$status" = 0
 cleanup; SIM_ID=''
done
git rev-parse HEAD > "$OUT/ACCESS_VISUAL_PASS_SHA.txt"
