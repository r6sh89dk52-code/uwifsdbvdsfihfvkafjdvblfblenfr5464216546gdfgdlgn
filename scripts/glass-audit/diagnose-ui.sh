#!/usr/bin/env bash
# Build once, then run only explicitly selected recovered failures.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DANPER_AUDIT_OUT:?Set evidence directory}"
OUT="$DANPER_AUDIT_OUT"; DD="$OUT/DerivedData"
MODE="${1:?build or case}"; CLS="${2:-}"
mkdir -p "$OUT"
python3 - <<'PY' > "$OUT/selected-cases.txt"
import json
from pathlib import Path
allowed=['N2BiometricInteractionTests/testAutomaticBiometryCancellationRetryAndForeground','N2PremiumRedesignTests/testDemoNavigationAttentionAndVersion','N3ClinicalJourneyTests/testProtectedClinicalSourceCreationAndRelaunch']
cases=json.loads(Path('.github/glass-ui-diagnostic-request.json').read_text()).get('cases',allowed)
assert isinstance(cases,list) and cases and len(cases)==len(set(cases)) and all(c in allowed for c in cases)
print('\n'.join(cases))
PY
if test "$MODE" = build; then
 git rev-parse HEAD > "$OUT/SOURCE_SHA.txt"
 git rev-parse HEAD^{tree} > "$OUT/SOURCE_TREE.txt"
 xcodebuild -version > "$OUT/xcode-version.txt"
 xcrun simctl list runtimes -j > "$OUT/runtimes.json"
 echo 'PHASE: prepare resources and project'
 npm ci --ignore-scripts --no-audit --no-fund > "$OUT/npm.log" 2>&1
 node scripts/prepare-n1s-ios-demo-resources.cjs > "$OUT/resources.log" 2>&1
 node scripts/glass-audit/identity.cjs
 (cd native-ios && bash scripts/make-app-icon.sh && xcodegen generate --spec project.yml) > "$OUT/xcodegen.log" 2>&1
else
 test "$MODE" = case
 test "$(cat "$OUT/BUILD_SUCCESS_SHA.txt")" = "$(git rev-parse HEAD)"
fi
SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
RUNTIME=$(python3 - "$OUT/runtimes.json" "$SDK_VERSION" <<'PY'
import json,sys
rows=[r for r in json.load(open(sys.argv[1]))['runtimes'] if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-') and r['version'].split('.')[:2]==sys.argv[2].split('.')[:2]]
assert rows,'No runtime matching selected Xcode SDK'
print(rows[0]['identifier'])
PY
)
SIM_ID=''; STREAM_PID=''; READY_PID=''
cleanup(){
 if test -n "$READY_PID"; then kill "$READY_PID" 2>/dev/null || true; wait "$READY_PID" 2>/dev/null || true; fi
 if test -n "$STREAM_PID"; then kill "$STREAM_PID" 2>/dev/null || true; wait "$STREAM_PID" 2>/dev/null || true; fi
 if test -n "$SIM_ID"; then xcrun simctl shutdown "$SIM_ID" || true; xcrun simctl delete "$SIM_ID" || true; fi
}
trap cleanup EXIT
fresh(){
 echo "PHASE: boot isolated simulator for $1"
 SIM_ID=$(xcrun simctl create "DANPER-SYNTHETIC-DIAG-$1" com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$RUNTIME")
 echo "$1 $SIM_ID" >> "$OUT/isolated-simulators.txt"
 xcrun simctl boot "$SIM_ID"
 xcrun simctl bootstatus "$SIM_ID" -b
 xcrun simctl ui "$SIM_ID" appearance dark
 xcrun simctl spawn "$SIM_ID" defaults write .GlobalPreferences AppleLanguages -array es
 xcrun simctl spawn "$SIM_ID" defaults write .GlobalPreferences AppleLocale es_PE
 bash scripts/glass-audit/enroll-simulator.sh "$SIM_ID" >> "$OUT/enrollment.log" 2>&1
 defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
 echo 'PHASE: prelaunch system authentication UI (no app authorization)'
 bash scripts/glass-audit/prepare-auth-ui.sh "$SIM_ID" 2>&1 | tee -a "$OUT/auth-ui-preparation.log"
}
run_test(){
 local label="$1" expected="$2" status=0; shift 2
 echo "PHASE: run $label ($expected required tests; no skips)"
 xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -destination-timeout 180 \
  -derivedDataPath "$DD" -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -maximum-test-execution-time-allowance 600 -default-test-execution-time-allowance 600 \
  -resultBundlePath "$OUT/$label.xcresult" "$@" test-without-building > "$OUT/$label.log" 2>&1 || status=$?
 echo "PHASE: verify and export $label"
 python3 scripts/glass-audit/check-xcresult.py "$OUT/$label.xcresult" "$expected" > "$OUT/$label-verdict.log" 2>&1 || status=1
 xcrun xcresulttool export attachments --path "$OUT/$label.xcresult" --output-path "$OUT/$label-attachments" > "$OUT/$label-export.log" 2>&1 || status=1
 python3 - "$OUT/$label.xcresult.summary.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]));print('RESULT:',s['passedTests'],'PASS,',s['failedTests'],'FAIL,',s['skippedTests'],'SKIP')
for f in s.get('testFailures',[]):print(f['testIdentifierString'],f['failureText'].splitlines()[0])
PY
 return "$status"
}
if test "$MODE" = build; then
 CLS=$(head -1 "$OUT/selected-cases.txt" | cut -d/ -f1)
 # Keep this synthetic device for the first case; avoid a redundant cold boot.
 fresh "$CLS"
 echo "$CLS $SIM_ID" > "$OUT/build-simulator.txt"
 echo 'PHASE: build test binaries once; restored cache is revalidated by Xcode'
 xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -derivedDataPath "$DD" \
  ONLY_ACTIVE_ARCH=YES build-for-testing 2>&1 | tee "$OUT/build-for-testing.log"
 git rev-parse HEAD > "$OUT/BUILD_SUCCESS_SHA.txt"
 echo 'PHASE: verify actual Face ID availability on this architecture (no authentication injected)'
 run_test biometric-preflight 1 -only-testing:DANPERNativeTests/N2BiometricEnvironmentTests
 trap - EXIT
 exit 0
fi
CASE=$(awk -F/ -v cls="$CLS" '$1==cls {print}' "$OUT/selected-cases.txt")
test -n "$CASE"
read -r OWNER SAVED_SIM < "$OUT/build-simulator.txt"
if test "$OWNER" = "$CLS"; then
 SIM_ID="$SAVED_SIM"
 # Cache/code compilation cannot authorize a DANPER LAContext.
 bash scripts/glass-audit/prepare-auth-ui.sh "$SIM_ID" 2>&1 | tee -a "$OUT/auth-ui-preparation.log"
else
 fresh "$CLS"
fi
# Stream before the test, so relaunch failures survive step timeouts too.
xcrun simctl spawn "$SIM_ID" log stream --level debug --style compact \
 --predicate 'process == "DANPERNative" OR process == "coreauthd" OR process == "CoreAuthUI" OR subsystem CONTAINS[c] "LocalAuthentication" OR subsystem CONTAINS[c] "Biometric"' \
 > "$OUT/$CLS-system.log" 2>&1 & STREAM_PID=$!
if test "$CLS" = N2BiometricInteractionTests || test "$CLS" = N3ClinicalJourneyTests; then
 python3 -u scripts/glass-audit/simulator-ready-bridge.py "$SIM_ID" "$OUT/$CLS-system.log" "$DD/Build/Products/Debug-iphonesimulator/DANPERInteractionTests-Runner.app/Info.plist" > "$OUT/$CLS-biometric-readiness.log" 2>&1 & READY_PID=$!
fi
if test "$CLS" = N2PremiumRedesignTests; then
 run_test "seed-$CLS" 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests
fi
status=0
run_test "$CLS" 1 "-only-testing:DANPERInteractionTests/$CASE" || status=$?
xcrun simctl io "$SIM_ID" screenshot "$OUT/$CLS-final.png" || true
if test "$status" = 0; then git rev-parse HEAD > "$OUT/$CLS-PASS_SHA.txt"; fi
exit "$status"
