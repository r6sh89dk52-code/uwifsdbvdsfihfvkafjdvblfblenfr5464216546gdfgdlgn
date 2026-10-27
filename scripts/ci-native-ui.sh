#!/usr/bin/env bash
# Clone only our pristine, migrated baseline. Test methods never share app data.
set -euo pipefail
: "${BUILD_DIR:?}"
RECIPE_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
mkdir -p "$BUILD_DIR/results" "$BUILD_DIR/logs"
test "$(git rev-parse HEAD)" = "${DANPER_SOURCE_SHA:-$GITHUB_SHA}"
xcrun simctl list runtimes -j > "$BUILD_DIR/logs/runtimes.json"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-version)
python3 "$RECIPE_DIR/select-native-simulator-runtime.py" --runtimes "$BUILD_DIR/logs/runtimes.json" --sdk "$SDK" > "$BUILD_DIR/logs/selected-runtime.json"
cat "$BUILD_DIR/logs/selected-runtime.json"
RUNTIME=$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["identifier"])' "$BUILD_DIR/logs/selected-runtime.json")
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative \
  -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$BUILD_DIR/simulator" -disableAutomaticPackageResolution \
  ARCHS="$(uname -m)" ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing \
  2>&1 | tee "$BUILD_DIR/logs/build-for-testing.log"
SIM_ID=''
BASE_ID=''
remove_active() {
  if [[ -n "$SIM_ID" ]]; then
    xcrun simctl shutdown "$SIM_ID" || true
    xcrun simctl delete "$SIM_ID"
    SIM_ID=''
  fi
}
cleanup() {
  remove_active
  if [[ -n "$BASE_ID" ]]; then
    xcrun simctl shutdown "$BASE_ID" || true
    xcrun simctl delete "$BASE_ID"
    BASE_ID=''
  fi
}
trap cleanup EXIT
boot_ready() {
  xcrun simctl boot "$1"
  python3 - "$1" <<'PY'
import subprocess,sys
subprocess.run(['xcrun','simctl','bootstatus',sys.argv[1],'-b'],check=True,timeout=360)
PY
  open -a "$DEVELOPER_DIR/Applications/Simulator.app"
  # Give SpringBoard and authentication UI services time to settle in CI.
  sleep 10
}
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
BASE_ID=$(xcrun simctl create "DANPER-CI-$GITHUB_RUN_ID-PRISTINE" com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$RUNTIME")
boot_ready "$BASE_ID"
xcrun simctl listapps "$BASE_ID" > "$BUILD_DIR/logs/pristine-apps.plist"
python3 - "$BUILD_DIR/logs/pristine-apps.plist" <<'PY'
from pathlib import Path
import sys
assert "pe.danper.saludmovil.native.preview" not in Path(sys.argv[1]).read_text(), "Pristine baseline contains DANPER"
PY
xcrun simctl shutdown "$BASE_ID"
new_simulator() {
  remove_active
  SIM_ID=$(xcrun simctl clone "$BASE_ID" "DANPER-CI-$GITHUB_RUN_ID-$1")
  boot_ready "$SIM_ID"
  defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
  # Existing xcresult diagnostics show CoreAuthUI cold startup exceeding the
  # system's fixed five-second activation watchdog. Initialize Apple's service
  # before launching DANPER; no app permission, policy or authentication result
  # is granted here. The unchanged tests must still drive real LocalAuthentication.
  xcrun simctl launch "$SIM_ID" com.apple.CoreAuthUI \
    2>&1 | tee "$BUILD_DIR/logs/$1-coreauth-prewarm.log"
  sleep 10
  xcrun simctl spawn "$SIM_ID" notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
  xcrun simctl spawn "$SIM_ID" notifyutil -p com.apple.BiometricKit.enrollmentChanged
  xcrun simctl spawn "$SIM_ID" notifyutil -g com.apple.BiometricKit.enrollmentChanged | tee "$BUILD_DIR/logs/$1-enrollment.log"
  python3 - "$BUILD_DIR/logs/$1-enrollment.log" <<'PY'
from pathlib import Path
import sys
assert Path(sys.argv[1]).read_text().split()[-1]=='1','Simulator biometric enrollment was not confirmed'
PY
}
run_test() {
  local selector="$1" label="$2" rc=0
  xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative \
    -configuration Debug -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" \
    -destination-timeout 180 -parallel-testing-enabled NO \
    -derivedDataPath "$BUILD_DIR/simulator" -resultBundlePath "$BUILD_DIR/results/$label.xcresult" \
    -only-testing:"$selector" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test-without-building \
    2>&1 | tee "$BUILD_DIR/logs/$label.log" || rc=$?
  xcrun xcresulttool get test-results summary --path "$BUILD_DIR/results/$label.xcresult" \
    > "$BUILD_DIR/results/$label-summary.json" 2> "$BUILD_DIR/logs/$label-summary-error.log" || rc=1
  if ! python3 - "$selector" "$label" "$rc" <<'PY'
import json,os,sys
from pathlib import Path
selector,label,rc=sys.argv[1:];folder=Path(os.environ['BUILD_DIR'])
try:
    summary=json.loads((folder/'results'/f'{label}-summary.json').read_text())
    passed=summary['passedTests'];failed=summary['failedTests'];skipped=summary['skippedTests']
    expected=15 if selector=='DANPERNativeTests' else 1
    status='PASS' if int(rc)==0 and passed==expected and failed==0 and skipped==0 else 'FAIL'
except (OSError,ValueError,KeyError) as error:
    summary={'error':str(error)};status='BLOCKED'
row={'selector':selector,'status':status,'source_sha':os.environ.get('DANPER_SOURCE_SHA',os.environ['GITHUB_SHA']),
     'recipe_sha':os.environ.get('DANPER_RECIPE_SHA',os.environ['GITHUB_SHA']),'summary':summary}
with (folder/'TEST_RESULTS.jsonl').open('a') as f:f.write(json.dumps(row)+'\n')
print(selector,status)
raise SystemExit(0 if status=='PASS' else 1)
PY
  then rc=1; fi
  return "$rc"
}
failed=0
new_simulator native
if run_test DANPERNativeTests native; then :; else failed=1; fi
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
    if ! run_test DANPERNativeTests/N2PremiumDemoFixtureTests "$label-fixture"; then
      failed=1
      echo "$selector BLOCKED (fixture failed)"
      continue
    fi
  fi
  if run_test "$selector" "$label"; then :; else failed=1; fi
done < "$BUILD_DIR/ui-methods.txt"
for result in "$BUILD_DIR/results/"*.xcresult; do
  xcrun xcresulttool export attachments --path "$result" --output-path "${result%.xcresult}-attachments" \
    > "${result%.xcresult}-attachments.log" 2>&1 || echo "Attachment export BLOCKED: $result"
done
exit "$failed"
