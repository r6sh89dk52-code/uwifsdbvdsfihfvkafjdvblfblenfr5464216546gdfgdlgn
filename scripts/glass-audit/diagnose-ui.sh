#!/usr/bin/env bash
# Deliberately runs ONLY the three failures; no full audit or IPA path.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DANPER_AUDIT_OUT:?Set evidence directory}"
OUT="$DANPER_AUDIT_OUT"
DD="$OUT/DerivedData"
mkdir -p "$OUT"
git rev-parse HEAD > "$OUT/SOURCE_SHA.txt"
git rev-parse HEAD^{tree} > "$OUT/SOURCE_TREE.txt"
xcodebuild -version > "$OUT/xcode-version.txt"
xcrun simctl list runtimes -j > "$OUT/runtimes.json"
npm ci --ignore-scripts --no-audit --no-fund > "$OUT/npm.log" 2>&1
node scripts/prepare-n1s-ios-demo-resources.cjs > "$OUT/resources.log" 2>&1
node scripts/glass-audit/identity.cjs
(cd native-ios && bash scripts/make-app-icon.sh && xcodegen generate --spec project.yml) > "$OUT/xcodegen.log" 2>&1
SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
RUNTIME=$(python3 - "$OUT/runtimes.json" "$SDK_VERSION" <<'PY'
import json,sys
rows=[r for r in json.load(open(sys.argv[1]))['runtimes'] if r.get('isAvailable') and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-') and r['version'].split('.')[:2]==sys.argv[2].split('.')[:2]]
assert rows,'No runtime matching selected Xcode SDK'
print(rows[0]['identifier'])
PY
)
SIM_ID=''
cleanup(){ if test -n "$SIM_ID"; then xcrun simctl shutdown "$SIM_ID" || true; xcrun simctl delete "$SIM_ID" || true; fi; }
trap cleanup EXIT
fresh(){
 cleanup
 SIM_ID=$(xcrun simctl create "DANPER-SYNTHETIC-DIAG-$1" com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$RUNTIME")
 echo "$1 $SIM_ID" >> "$OUT/isolated-simulators.txt"
 xcrun simctl boot "$SIM_ID"
 xcrun simctl bootstatus "$SIM_ID" -b
 xcrun simctl ui "$SIM_ID" appearance dark
 xcrun simctl spawn "$SIM_ID" defaults write .GlobalPreferences AppleLanguages -array es
 xcrun simctl spawn "$SIM_ID" defaults write .GlobalPreferences AppleLocale es_PE
 bash scripts/glass-audit/enroll-simulator.sh "$SIM_ID" >> "$OUT/enrollment.log" 2>&1
 defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
}
run_test(){
 local label="$1" expected="$2" status=0; shift 2
 xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -destination-timeout 180 \
  -derivedDataPath "$DD" -parallel-testing-enabled NO -resultBundlePath "$OUT/$label.xcresult" \
  "$@" test-without-building > "$OUT/$label.log" 2>&1 || status=$?
 python3 scripts/glass-audit/check-xcresult.py "$OUT/$label.xcresult" "$expected" || status=1
 xcrun xcresulttool export attachments --path "$OUT/$label.xcresult" --output-path "$OUT/$label-attachments" || status=1
 return "$status"
}
fresh build
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
 -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -derivedDataPath "$DD" \
 ONLY_ACTIVE_ARCH=YES build-for-testing > "$OUT/build-for-testing.log" 2>&1
overall=0
while IFS=/ read -r cls method; do
 fresh "$cls"
 if test "$cls" = N2PremiumRedesignTests; then
  if ! run_test "seed-$cls" 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests; then overall=1; continue; fi
 fi
 # Protected-source case needs no DEMO fixture; starts with an empty isolated vault.
 if ! run_test "$cls" 1 "-only-testing:DANPERInteractionTests/$cls/$method"; then overall=1; fi
 xcrun simctl io "$SIM_ID" screenshot "$OUT/$cls-final.png" || true
 xcrun simctl spawn "$SIM_ID" log show --last 15m --style compact \
  --predicate 'process == "DANPERNative" OR process == "coreauthd" OR process == "CoreAuthUI" OR subsystem CONTAINS[c] "LocalAuthentication" OR subsystem CONTAINS[c] "Biometric"' \
  > "$OUT/$cls-system.log" 2>&1 || true
 # Preserve each completed case before the next one begins.
 echo "Completed $cls (cumulative status $overall)"
done <<'CASES'
N2BiometricInteractionTests/testAutomaticBiometryCancellationRetryAndForeground
N2PremiumRedesignTests/testDemoNavigationAttentionAndVersion
N3ClinicalJourneyTests/testProtectedClinicalSourceCreationAndRelaunch
CASES
if test "$overall" = 0; then git rev-parse HEAD > "$OUT/DIAGNOSED_3_SHA.txt"; fi
exit "$overall"
