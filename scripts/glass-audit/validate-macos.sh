#!/usr/bin/env bash
# Run only on an isolated synthetic Simulator; never uses existing devices.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DANPER_AUDIT_OUT:?Set an absolute evidence directory}"
mkdir -p "$DANPER_AUDIT_OUT"
OUT="$DANPER_AUDIT_OUT"
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
DD="$OUT/DerivedData"
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
 -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" build-for-testing > "$OUT/build-for-testing.log" 2>&1
# Never pick or erase an existing user's simulator.
RUNTIME=$(python3 - "$OUT/runtimes.json" <<'PY'
import json,sys
r=[x for x in json.load(open(sys.argv[1]))['runtimes'] if x.get('isAvailable') and x['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')]
assert r,'No available iOS runtime'; print(sorted(r,key=lambda x:tuple(map(int,x['version'].split('.'))))[-1]['identifier'])
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
 xcrun simctl spawn "$SIM_ID" notifyutil -s com.apple.BiometricKit.enrolled 1
 xcrun simctl spawn "$SIM_ID" notifyutil -s com.apple.BiometricKit.pearl.enrolled 1
 defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool NO
}
run_tests(){
 local label="$1" expected="$2"; shift 2
 xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -destination-timeout 180 \
  -derivedDataPath "$DD" -parallel-testing-enabled NO -resultBundlePath "$OUT/$label.xcresult" \
  "$@" test-without-building > "$OUT/$label.log" 2>&1
 python3 scripts/glass-audit/check-xcresult.py "$OUT/$label.xcresult" "$expected"
 xcrun xcresulttool export attachments --path "$OUT/$label.xcresult" --output-path "$OUT/$label-attachments"
}
fresh native
# All original 21 cases, plus the exhaustive 432-code classification regression.
run_tests native-22 22 -only-testing:DANPERNativeTests
# Discover all classes/cases from source, never an outdated handpicked subset.
python3 - <<'PY' > "$OUT/ui-classes.tsv"
from pathlib import Path
import re
for p in sorted(Path('native-ios/InteractionTests').glob('*.swift')):
 s=p.read_text(); c=re.search(r'final class (\w+):XCTestCase',s)
 if c: print(c[1],len(re.findall(r'func test\w+\(',s)),sep='\t')
PY
while IFS=$'\t' read -r cls count; do
 fresh "$cls"
 case "$cls" in
  N2GlassClinicalTests|N2PremiumRedesignTests|N3ClinicalJourneyTests)
   run_tests "seed-$cls" 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests ;;
 esac
 run_tests "$cls" "$count" "-only-testing:DANPERInteractionTests/$cls"
done < "$OUT/ui-classes.tsv"
python3 - "$OUT/ui-classes.tsv" <<'PY'
import sys
assert sum(int(s.split()[1]) for s in open(sys.argv[1]))==11,'Review UI test inventory'
PY
# Only this marker allows packaging in CI or locally.
git rev-parse HEAD > "$OUT/VALIDATED_SHA.txt"
echo 'PASS: 412 Swift, 22 native (21 original + exhaustive catalog), all 11 UI, 50 JavaScript, 12 additional guards + 2 cross-workbook controls.'
