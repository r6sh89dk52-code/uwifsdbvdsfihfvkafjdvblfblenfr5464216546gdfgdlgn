#!/usr/bin/env bash
# Every method gets a new ephemeral device. Only setup and relaunch within
# that method share state. Test failures accumulate and keep a failing exit.
set -euo pipefail
: "${BUILD_DIR:?}"
mkdir -p "$BUILD_DIR/results"
xcrun simctl list runtimes -j > "$BUILD_DIR/logs/runtimes.json"
RUNTIME=$(python3 - <<'PY'
import json,os
from pathlib import Path
r=json.loads((Path(os.environ['BUILD_DIR'])/'logs/runtimes.json').read_text())['runtimes']
candidates=[x for x in r if x.get('isAvailable') and x['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
if not candidates: raise SystemExit('No compatible iOS runtime')
print(max(candidates,key=lambda x:tuple(map(int,x['version'].split('.'))))['identifier'])
PY
)
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$BUILD_DIR/simulator" -disableAutomaticPackageResolution \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing \
  2>&1 | tee "$BUILD_DIR/logs/build-for-testing.log"
SIM_ID=''
cleanup() {
  if [[ -n "$SIM_ID" ]]; then
    xcrun simctl shutdown "$SIM_ID" || true
    xcrun simctl delete "$SIM_ID"
    SIM_ID=''
  fi
}
trap cleanup EXIT
new_simulator() {
  cleanup
  SIM_ID=$(xcrun simctl create "DANPER-CI-$GITHUB_RUN_ID-$1" com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$RUNTIME")
  xcrun simctl boot "$SIM_ID"
  xcrun simctl bootstatus "$SIM_ID" -b
  defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
  xcrun simctl spawn "$SIM_ID" notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
  xcrun simctl spawn "$SIM_ID" notifyutil -p com.apple.BiometricKit.enrollmentChanged
  # Record enrollment rather than silently assuming it succeeded.
  xcrun simctl spawn "$SIM_ID" notifyutil -g com.apple.BiometricKit.enrollmentChanged
}
run_test() {
  local selector="$1" label="$2"
  xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative \
    -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" \
    -destination-timeout 180 -parallel-testing-enabled NO \
    -derivedDataPath "$BUILD_DIR/simulator" -resultBundlePath "$BUILD_DIR/results/$label.xcresult" \
    -only-testing:"$selector" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test-without-building \
    2>&1 | tee "$BUILD_DIR/logs/$label.log"
}
failed=0
new_simulator native
if run_test DANPERNativeTests native; then echo 'native PASS'; else failed=1; echo 'native FAIL'; fi
# Enumerate every UI method from source so additions cannot silently escape CI.
python3 - <<'PY' > "$BUILD_DIR/ui-methods.txt"
from pathlib import Path
import re
for p in sorted(Path('native-ios/InteractionTests').glob('*.swift')):
    s=p.read_text();cls=re.search(r'final class (\w+)\s*:',s)
    if cls:
        for method in re.findall(r'func (test\w+)\s*\(',s):
            print(f'DANPERInteractionTests/{cls[1]}/{method}')
PY
test -s "$BUILD_DIR/ui-methods.txt"
while IFS= read -r selector; do
  label=${selector//\//-}
  new_simulator "$label"
  if [[ "$selector" == */testDemoNavigationAttentionAndVersion ]]; then
    # This is an explicit synthetic fixture setup, not another test's residue.
    if ! run_test DANPERNativeTests/N2PremiumDemoFixtureTests "$label-fixture"; then
      failed=1
      echo "$selector BLOCKED (fixture failed)"
      continue
    fi
  fi
  if run_test "$selector" "$label"; then echo "$selector PASS"; else failed=1; echo "$selector FAIL"; fi
  xcrun simctl spawn "$SIM_ID" log collect --last 10m --output "$BUILD_DIR/results/$label.logarchive" || true
done < "$BUILD_DIR/ui-methods.txt"
# Export viewable attachments from all result bundles while xcresulttool exists.
for result in "$BUILD_DIR/results/"*.xcresult; do
  xcrun xcresulttool export attachments --path "$result" --output-path "${result%.xcresult}-attachments" \
    > "${result%.xcresult}-attachments.log" 2>&1 || echo "Attachment export BLOCKED: $result"
done
exit "$failed"
