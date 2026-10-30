#!/usr/bin/env bash
# Run only on an isolated synthetic Simulator; never uses existing devices.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DANPER_AUDIT_OUT:?Set an absolute evidence directory}"
mkdir -p "$DANPER_AUDIT_OUT"
OUT="$DANPER_AUDIT_OUT"
MODE="${1:-all}"
DD="${DANPER_AUDIT_DERIVED_DATA:-$OUT/DerivedData}"
if test "$MODE" != ui && test "$MODE" != resume-native && test "$MODE" != scoped-native && test "$MODE" != current; then
export DANPER_N1_FIXTURE_DIR="$OUT/fixtures"
for cmd in node swift xcodegen xcodebuild; do command -v "$cmd" >/dev/null; done
git rev-parse HEAD > "$OUT/SOURCE_SHA.txt"
git rev-parse HEAD^{tree} > "$OUT/SOURCE_TREE.txt"
xcodebuild -version > "$OUT/xcode-version.txt"
xcrun simctl list runtimes -j > "$OUT/runtimes.json"
bash scripts/glass-audit/prepare.sh
node scripts/glass-audit/javascript.cjs > "$OUT/javascript.log" 2>&1
(cd native-ios && swift test --jobs 2) > "$OUT/swift-412.log" 2>&1
python3 - "$OUT/swift-412.log" <<'PY'
import re,sys
s=open(sys.argv[1]).read();assert re.search(r'Executed 412 tests, with 0 failures',s),s[-4000:]
assert not re.search(r'\d+ tests? skipped|\d+ tests? (?:were )?skipped',s), 'Inspect skipped tests'
PY
for name in test-n1r-native-xlsx test-n1s-full-native-workbooks; do
 node "scripts/$name.cjs" > "$OUT/$name.log" 2>&1
done
(cd native-ios && bash scripts/make-app-icon.sh && xcodegen generate --spec project.yml) > "$OUT/xcodegen.log" 2>&1
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
 -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" build-for-testing > "$OUT/build-for-testing.log" 2>&1
fi
if test "$MODE" = resume-native; then
 : "${DANPER_BASELINE_EVIDENCE:?Download run 40790429936 evidence first}"
 python3 scripts/glass-audit/verify-reuse.py "$DANPER_BASELINE_EVIDENCE" "$OUT"
 git rev-parse HEAD > "$OUT/SOURCE_SHA.txt"
 git rev-parse HEAD^{tree} > "$OUT/SOURCE_TREE.txt"
 xcodebuild -version > "$OUT/xcode-version.txt"
 xcrun simctl list runtimes -j > "$OUT/runtimes.json"
 npm ci --ignore-scripts --no-audit --no-fund > "$OUT/npm.log" 2>&1
 node scripts/prepare-n1s-ios-demo-resources.cjs > "$OUT/resources.log" 2>&1
 node scripts/glass-audit/identity.cjs
 (cd native-ios && bash scripts/make-app-icon.sh && xcodegen generate --spec project.yml) > "$OUT/xcodegen.log" 2>&1
fi
# Current-branch CI: run every simulator suite from this checkout, without
# reusing earlier evidence or packaging. Swift/Excel gates run independently.
if test "$MODE" = current; then
 git rev-parse HEAD > "$OUT/SOURCE_SHA.txt"
 git rev-parse HEAD^{tree} > "$OUT/SOURCE_TREE.txt"
 xcodebuild -version > "$OUT/xcode-version.txt"
 xcrun simctl list runtimes -j > "$OUT/runtimes.json"
fi
if test "$MODE" = scoped-native; then test "$(cat "$OUT/BUILD_SUCCESS_SHA.txt")" = "$(git rev-parse HEAD)"; fi
if test "$MODE" = ui; then test "$(cat "$OUT/CORE_NATIVE_SHA.txt")" = "$(git rev-parse HEAD)"; fi
# Never pick or erase an existing user's simulator.
SDK_VERSION=$(xcrun --sdk iphonesimulator --show-sdk-version)
RUNTIME=$(python3 - "$OUT/runtimes.json" "$SDK_VERSION" <<'PY'
import json,sys
r=[x for x in json.load(open(sys.argv[1]))['runtimes'] if x.get('isAvailable') and x['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
sdk=tuple(map(int,sys.argv[2].split('.')[:2]))
r=[x for x in r if tuple(map(int,x['version'].split('.')[:2]))==sdk]
assert r,'No iOS runtime matching the selected Xcode SDK; do not silently select another major release'
print(r[0]['identifier'])
PY
)
SIM_ID=''
cleanup(){ if test -n "$SIM_ID"; then xcrun simctl shutdown "$SIM_ID" || true; xcrun simctl delete "$SIM_ID" || true; fi; }
trap cleanup EXIT
fresh(){
 cleanup
 SIM_ID=$(xcrun simctl create "DANPER-SYNTHETIC-$1" com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$RUNTIME")
 echo "$1 $SIM_ID" >> "$OUT/isolated-simulators.txt"
 xcrun simctl boot "$SIM_ID"
 xcrun simctl bootstatus "$SIM_ID" -b
 xcrun simctl ui "$SIM_ID" appearance dark
 xcrun simctl spawn "$SIM_ID" defaults write .GlobalPreferences AppleLanguages -array es
 xcrun simctl spawn "$SIM_ID" defaults write .GlobalPreferences AppleLocale es_PE
 bash scripts/glass-audit/enroll-simulator.sh "$SIM_ID" >> "$OUT/enrollment.log" 2>&1
 defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
 bash scripts/glass-audit/prepare-auth-ui.sh "$SIM_ID" >> "$OUT/auth-ui-preparation.log" 2>&1
}
run_tests(){
 local label="$1" expected="$2" status=0 stream='' bridge=''; shift 2
 case "$label" in
  N2BiometricInteractionTests|N3ClinicalJourneyTests-protected)
   xcrun simctl spawn "$SIM_ID" log stream --level debug --style compact \
    --predicate 'subsystem BEGINSWITH "com.apple.LocalAuthentication" OR (process == "coreauthd" AND eventMessage CONTAINS "simulateMatching") OR (process == "DANPERNative" AND subsystem == "com.apple.UIKit" AND category == "Application")' > "$OUT/$label-system.log" 2>&1 & stream=$!
   python3 -u scripts/glass-audit/simulator-ready-bridge.py "$SIM_ID" "$OUT/$label-system.log" "$DD/Build/Products/Debug-iphonesimulator/DANPERInteractionTests-Runner.app/Info.plist" > "$OUT/$label-biometric-readiness.log" 2>&1 & bridge=$! ;;
 esac
 xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -destination-timeout 180 \
  -derivedDataPath "$DD" -parallel-testing-enabled NO -resultBundlePath "$OUT/$label.xcresult" \
  ASSETCATALOG_COMPILER_APPICON_NAME="" "$@" test-without-building > "$OUT/$label.log" 2>&1 || status=$?
 if test -n "$bridge"; then kill "$bridge" 2>/dev/null || true; wait "$bridge" 2>/dev/null || true; fi
 if test -n "$stream"; then kill "$stream" 2>/dev/null || true; wait "$stream" 2>/dev/null || true; fi
 python3 scripts/glass-audit/check-xcresult.py "$OUT/$label.xcresult" "$expected" || status=1
 xcrun xcresulttool export attachments --path "$OUT/$label.xcresult" --output-path "$OUT/$label-attachments" || status=1
 return "$status"
}
if test "$MODE" != ui; then
 fresh native
 if test "$MODE" = resume-native || test "$MODE" = current; then
  # Compile for this actual Simulator architecture, not two unused slices.
  xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
   -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -derivedDataPath "$DD" \
   ONLY_ACTIVE_ARCH=YES ASSETCATALOG_COMPILER_APPICON_NAME="" build-for-testing > "$OUT/build-for-testing.log" 2>&1
 fi
 # Diagnose enrollment before running the remaining native/interaction cases.
 run_tests biometric-preflight 1 -only-testing:DANPERNativeTests/N2BiometricEnvironmentTests
 # All original 21 cases + exhaustive catalog + genuine Face ID availability.
 run_tests native-26 26 -only-testing:DANPERNativeTests
 git rev-parse HEAD > "$OUT/CORE_NATIVE_SHA.txt"
 if test "$MODE" = native || test "$MODE" = resume-native || test "$MODE" = scoped-native; then exit 0; fi
fi
# Discover all classes/cases from source, never an outdated handpicked subset.
python3 - <<'PY' > "$OUT/ui-classes.tsv"
from pathlib import Path
import re
for p in sorted(Path('native-ios/InteractionTests').glob('*.swift')):
 s=p.read_text(); c=re.search(r'final class (\w+):XCTestCase',s)
 if not c:continue
 cls=c[1];methods=re.findall(r'func (test\w+)\(',s)
 assert len(methods)==len(set(methods))
 if cls=='N3ClinicalJourneyTests':
  protected='testProtectedClinicalSourceCreationAndRelaunch'
  assert protected in methods
  demo=[m for m in methods if m!=protected]
  selectors=' '.join('-only-testing:DANPERInteractionTests/'+cls+'/'+m for m in demo)
  print(cls+'-demo',len(demo),cls,selectors,sep='\t')
  print(cls+'-protected',1,cls,'-only-testing:DANPERInteractionTests/'+cls+'/'+protected,sep='\t')
 else:print(cls,len(methods),cls,'-only-testing:DANPERInteractionTests/'+cls,sep='\t')
PY
overall=0
while IFS=$'\t' read -r label count cls selectors; do
 fresh "$label"
 case "$label" in
  N2GlassClinicalTests|N2PremiumRedesignTests|N3ClinicalJourneyTests-demo)
   if ! run_tests "seed-$label" 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests; then overall=1; continue; fi ;;
 esac
 IFS=' ' read -r -a selection <<< "$selectors"
 if ! run_tests "$label" "$count" "${selection[@]}"; then overall=1; fi
done < "$OUT/ui-classes.tsv"
python3 - "$OUT/ui-classes.tsv" <<'PY'
import sys
assert sum(int(s.split()[1]) for s in open(sys.argv[1]))==11,'Review UI test inventory'
PY
test "$overall" = 0
# Only this marker allows packaging in CI or locally.
git rev-parse HEAD > "$OUT/VALIDATED_SHA.txt"
echo 'PASS: current checkout, 26 native and all 11 UI cases; no failures/skips. Core/Excel results are validated separately.'
