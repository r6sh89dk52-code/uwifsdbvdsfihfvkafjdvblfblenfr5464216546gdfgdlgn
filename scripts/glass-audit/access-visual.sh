#!/usr/bin/env bash
# Targeted home/access regression; existing workflow, one build, no auth events.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DANPER_AUDIT_OUT:?}"
OUT="$DANPER_AUDIT_OUT"; DD="$OUT/DerivedData"
mkdir -p "$OUT"
git rev-parse HEAD > "$OUT/SOURCE_SHA.txt"
git rev-parse HEAD^{tree} > "$OUT/SOURCE_TREE.txt"
uname -m > "$OUT/architecture.txt"
xcodebuild -version > "$OUT/xcode-version.txt"
test "$(uname -m)" = x86_64
bash scripts/glass-audit/prepare.sh
node scripts/glass-audit/identity.cjs
node scripts/test-n2-premium-redesign.cjs
node scripts/test-n2-glass-clinical.cjs
node scripts/test-n2-build222-ui-parity.cjs
if ! command -v xcodegen >/dev/null; then brew install xcodegen; fi
(cd native-ios && bash scripts/make-app-icon.sh && xcodegen generate --spec project.yml) > "$OUT/xcodegen.log" 2>&1
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
 -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" \
 ONLY_ACTIVE_ARCH=NO ARCHS="$(uname -m)" build-for-testing > "$OUT/build.log" 2>&1
git rev-parse HEAD > "$OUT/BUILD_SUCCESS_SHA.txt"
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
 defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
 run_selected(){
  local label="$1" expected="$2" status=0; shift 2
  xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
   -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -derivedDataPath "$DD" \
   -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 600 \
   -resultBundlePath "$OUT/$label.xcresult" "$@" \
   test-without-building > "$OUT/$label.log" 2>&1 || status=$?
  python3 scripts/glass-audit/check-xcresult.py "$OUT/$label.xcresult" "$expected" || status=1
  xcrun xcresulttool export attachments --path "$OUT/$label.xcresult" --output-path "$OUT/$label-attachments" > "$OUT/$label-export.log" 2>&1 || status=1
  test "$status" = 0
 }
 if test "$PHONE" = iPhone-16; then
  run_selected greeting-native 3 -only-testing:DANPERNativeTests/DanperGreetingTests
 fi
 run_selected "seed-$PHONE" 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests
 if test "$PHONE" = iPhone-16; then
  run_selected "$PHONE" 4 -only-testing:DANPERInteractionTests/N2GlassClinicalTests -only-testing:DANPERInteractionTests/N2PremiumRedesignTests/testAccessLightAndDark
 else
  run_selected "$PHONE" 2 -only-testing:DANPERInteractionTests/N2GlassClinicalTests/testLocalDisplayNamePersistsWithoutChangingClinicalIdentity -only-testing:DANPERInteractionTests/N2PremiumRedesignTests/testAccessLightAndDark
 fi
 cleanup; SIM_ID=''
done
git rev-parse HEAD > "$OUT/ACCESS_VISUAL_PASS_SHA.txt"
