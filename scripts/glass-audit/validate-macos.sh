#!/usr/bin/env bash
# Run only on an isolated synthetic Simulator; never uses existing devices.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DANPER_AUDIT_OUT:?Set an absolute evidence directory}"
mkdir -p "$DANPER_AUDIT_OUT"
OUT="$DANPER_AUDIT_OUT"
MODE="${1:-all}"
if test "$MODE" = replay; then
 case "${DANPER_REPLAY_LABEL:-}" in
  N2BiometricInteractionTests|N3ClinicalJourneyTests-demo|N3ClinicalJourneyTests-protected) ;;
  *) echo 'Invalid or absent replay suite'; exit 1 ;;
 esac
 printf '%s\n' "$DANPER_REPLAY_LABEL" > "$OUT/REPLAY_LABEL.txt"
fi
DD="${DANPER_AUDIT_DERIVED_DATA:-$OUT/DerivedData}"
if test "$MODE" != ui && test "$MODE" != resume-native && test "$MODE" != scoped-native && test "$MODE" != current && test "$MODE" != replay && test "$MODE" != b15-native && test "$MODE" != b15-shard; then
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
if test "$MODE" = current || test "$MODE" = replay || test "$MODE" = b15-native || test "$MODE" = b15-shard; then
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
TEST_RUN=''
if test "$MODE" = b15-shard; then
 : "${DANPER_B15_UI_LABEL:?Set one discovered UI suite}"
 : "${DANPER_TEST_PROOF:?Set same-HEAD compiled product proof}"
 python3 scripts/performance/test-products.py verify "$DD/Build/Products" "$DANPER_TEST_PROOF"
 TEST_RUN=$(python3 - "$DD/Build/Products" <<'PYRUN'
from pathlib import Path
import sys
paths=list(Path(sys.argv[1]).glob('*.xctestrun'))
assert len(paths)==1,paths
print(paths[0])
PYRUN
)
 printf '%s\n' "$DANPER_B15_UI_LABEL" > "$OUT/SHARD_LABEL.txt"
fi
SIM_ID=''
INSTALL_RECOVERY_SIM=''
cleanup(){ if test -n "$SIM_ID"; then xcrun simctl shutdown "$SIM_ID" || true; xcrun simctl delete "$SIM_ID" || true; fi; }
finish(){
 local result=$?
 trap - EXIT
 # Bash 3 can terminate on an expansion error before XCTest is launched.
 # Cleanup must never turn an incomplete B15 run into a successful job.
 if test "$MODE" = b15-shard && ! test -f "$OUT/SHARD_PASS_SHA.txt"; then
  echo 'FAIL: UI shard did not produce its completion marker' >&2; result=1
 fi
 if test "$MODE" = b15-native && ! test -f "$OUT/CORE_NATIVE_SHA.txt"; then
  echo 'FAIL: native suite did not produce its completion marker' >&2; result=1
 fi
 cleanup
 exit "$result"
}
trap finish EXIT
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
# Install explicitly before XCTest asks Xcode to launch its runner. New CI
# images can fail in Xcode's placeholder/delta installer before any test runs.
# Only the just-created synthetic device is eligible; install errors stay fatal.
prepare_test_installation(){
 xcrun simctl list devices -j | python3 -c 'import json,sys
rows=[d for group in json.load(sys.stdin)["devices"].values() for d in group if d["udid"]==sys.argv[1]]
assert len(rows)==1 and rows[0]["state"]=="Booted" and rows[0]["name"].startswith("DANPER-SYNTHETIC-")' "$SIM_ID" || return 1
 local app bundle executable attempt status
 for app in "$DD/Build/Products/Debug-iphonesimulator/DANPERNative.app" \
            "$DD/Build/Products/Debug-iphonesimulator/DANPERInteractionTests-Runner.app"; do
  test -d "$app" || return 1
  bundle=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Info.plist") || return 1
  if ! xcrun simctl get_app_container "$SIM_ID" "$bundle" app >/dev/null 2>&1; then
   # Check the actual signed Simulator binary before diagnosing its installer.
   codesign --verify --deep --strict "$app" >> "$OUT/simulator-signatures.log" 2>&1 || return 1
   codesign --display --entitlements - "$app" >> "$OUT/simulator-signatures.log" 2>&1 || return 1
   executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$app/Info.plist") || return 1
   xcrun lipo -archs "$app/$executable" >> "$OUT/simulator-signatures.log" || return 1
   attempt="$OUT/install-$SIM_ID-$bundle.log"
   status=0
   xcrun simctl install "$SIM_ID" "$app" > "$attempt" 2>&1 || status=$?
   cat "$attempt" >> "$OUT/simulator-installation.log"
   if test "$status" != 0; then
    # Recover one known, pre-test InstallCoordination failure. Never retry an
    # XCTest assertion, erase data, alter entitlements, or inject authentication.
    if test "$INSTALL_RECOVERY_SIM" = "$SIM_ID" ||
       ! grep -q 'domain=IXErrorDomain, code=2' "$attempt" ||
       ! grep -q 'Failed to create promise' "$attempt"; then
     cat "$attempt"; return "$status"
    fi
    INSTALL_RECOVERY_SIM="$SIM_ID"
    echo "RECOVERY: reboot owned synthetic Simulator after recorded IXErrorDomain code=2" | tee -a "$OUT/simulator-installation.log"
    python3 - "$SIM_ID" "$OUT/installer-system-$SIM_ID.log" <<'PYINSTALL'
import subprocess,sys
try:
 p=subprocess.run(['xcrun','simctl','spawn',sys.argv[1],'log','show','--last','3m','--style','compact',
  '--predicate','process == "installd" OR process == "installcoordinationd"'],capture_output=True,text=True,timeout=30)
 open(sys.argv[2],'w').write(p.stdout+p.stderr)
except subprocess.TimeoutExpired:
 open(sys.argv[2],'w').write('Installer diagnostic collection timed out; original install error preserved.\n')
PYINSTALL
    xcrun simctl shutdown "$SIM_ID" || return 1
    xcrun simctl boot "$SIM_ID" || return 1
    xcrun simctl bootstatus "$SIM_ID" -b || return 1
    bash scripts/glass-audit/enroll-simulator.sh "$SIM_ID" >> "$OUT/enrollment.log" 2>&1 || return 1
    bash scripts/glass-audit/prepare-auth-ui.sh "$SIM_ID" >> "$OUT/auth-ui-preparation.log" 2>&1 || return 1
    xcrun simctl install "$SIM_ID" "$app" >> "$OUT/simulator-installation.log" 2>&1 || {
     cat "$OUT/simulator-installation.log"; return 1;
    }
   fi
  fi
  xcrun simctl get_app_container "$SIM_ID" "$bundle" app >> "$OUT/simulator-installation.log" || return 1
 done
}
run_tests(){
 local label="$1" expected="$2" status=0 stream='' bridge='' profiler=''; shift 2
 echo "PHASE: $label — $expected required tests; no skips"
 prepare_test_installation || return $?
 case "$label" in
  N2BiometricInteractionTests|N3ClinicalJourneyTests-protected)
   python3 -u scripts/glass-audit/simulator-ready-bridge.py --stream "$SIM_ID" > "$OUT/$label-system.log" 2>&1 & stream=$!
   python3 -u scripts/glass-audit/simulator-ready-bridge.py "$SIM_ID" "$OUT/$label-system.log" "$DD/Build/Products/Debug-iphonesimulator/DANPERInteractionTests-Runner.app/Info.plist" > "$OUT/$label-biometric-readiness.log" 2>&1 & bridge=$! ;;
 esac
 # Keep the argument array nonempty on macOS /bin/bash 3.2. Expanding an
 # empty array under nounset aborts there before the command can execute.
 local selection=(-project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug -derivedDataPath "$DD")
 if test -n "$TEST_RUN"; then selection=(-xctestrun "$TEST_RUN"); fi
 if test "$label" = N2AllergySaveInteractionTests; then
  # Seed/preflight XCTest may leave its host alive. The UI suite explicitly
  # relaunches the app: profiling must observe that new process, not the seed.
  xcrun simctl terminate "$SIM_ID" pe.danper.saludmovil.native.iloaderpreview > "$OUT/profiler-process-reset.log" 2>&1 || true
  python3 scripts/performance/profile-simulator.py "$SIM_ID" "$OUT/Instruments" > "$OUT/profiler-launch.log" 2>&1 & profiler=$!
 fi
 xcodebuild "${selection[@]}" \
  -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -destination-timeout 180 \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 600 -maximum-test-execution-time-allowance 600 -resultBundlePath "$OUT/$label.xcresult" \
  ASSETCATALOG_COMPILER_APPICON_NAME="" "$@" test-without-building > "$OUT/$label.log" 2>&1 || status=$?
 if test -n "$profiler"; then wait "$profiler" || echo 'Profiler could not collect all diagnostics; inspect profiler-launch.log'; fi
 if test -n "$bridge"; then kill "$bridge" 2>/dev/null || true; wait "$bridge" 2>/dev/null || true; fi
 if test -n "$stream"; then kill "$stream" 2>/dev/null || true; wait "$stream" 2>/dev/null || true; fi
 python3 scripts/glass-audit/check-xcresult.py "$OUT/$label.xcresult" "$expected" || status=1
 xcrun xcresulttool export attachments --path "$OUT/$label.xcresult" --output-path "$OUT/$label-attachments" || status=1
 return "$status"
}
if test "$MODE" != ui; then
 fresh native
 if test "$MODE" = resume-native || test "$MODE" = current || test "$MODE" = replay || test "$MODE" = b15-native; then
  # Compile for this actual Simulator architecture, not two unused slices.
  xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
   -sdk iphonesimulator -destination "platform=iOS Simulator,id=$SIM_ID" -derivedDataPath "$DD" \
   ONLY_ACTIVE_ARCH=YES ASSETCATALOG_COMPILER_APPICON_NAME="" build-for-testing > "$OUT/build-for-testing.log" 2>&1
 fi
 # Diagnose enrollment before running the remaining native/interaction cases.
 run_tests biometric-preflight 1 -only-testing:DANPERNativeTests/N2BiometricEnvironmentTests
 # All original 21 cases + exhaustive catalog + genuine Face ID availability.
 if test "$MODE" != replay && test "$MODE" != b15-shard; then
  NATIVE_COUNT=$(python3 - <<'PYCOUNT'
from pathlib import Path
import re
print(sum(len(re.findall(r'func (test\w+)\(',p.read_text())) for p in Path('native-ios/NativeTests').glob('*.swift')))
PYCOUNT
)
  run_tests "native-$NATIVE_COUNT" "$NATIVE_COUNT" -only-testing:DANPERNativeTests
  git rev-parse HEAD > "$OUT/CORE_NATIVE_SHA.txt"
 fi
 if test "$MODE" = native || test "$MODE" = resume-native || test "$MODE" = scoped-native || test "$MODE" = b15-native; then exit 0; fi
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
 if test "$MODE" = replay && test "$label" != "$DANPER_REPLAY_LABEL"; then continue; fi
 if test "$MODE" = b15-shard && test "$label" != "$DANPER_B15_UI_LABEL"; then continue; fi
 # A B15 shard already owns a fresh Simulator and has just proved real Face
 # ID availability on it. The preflight only calls LAContext; it writes no
 # clinical fixture. Keep that device for this shard's single selected suite.
 # Other modes still create a separate device for each suite in their loop.
 if test "$MODE" != b15-shard; then fresh "$label"; fi
 case "$label" in
  N2GlassClinicalTests|N2PremiumRedesignTests|N3ClinicalJourneyTests-demo|N2AllergySaveInteractionTests)
   if ! run_tests "seed-$label" 2 -only-testing:DANPERNativeTests/N2PremiumDemoFixtureTests -only-testing:DANPERNativeTests/N2SimpleInventoryNativeTests; then overall=1; continue; fi ;;
 esac
 IFS=' ' read -r -a selection <<< "$selectors"
 if ! run_tests "$label" "$count" "${selection[@]}"; then overall=1; fi
done < "$OUT/ui-classes.tsv"
python3 - "$OUT/ui-classes.tsv" <<'PY'
import sys
assert sum(int(s.split()[1]) for s in open(sys.argv[1]))==13,'Review UI test inventory'
PY
test "$overall" = 0
if test "$MODE" = b15-shard; then
 grep -q "^$DANPER_B15_UI_LABEL" "$OUT/ui-classes.tsv"
 git rev-parse HEAD > "$OUT/SHARD_PASS_SHA.txt"
 exit 0
fi
if test "$MODE" = replay; then
 git rev-parse HEAD > "$OUT/REPLAY_PASS_SHA.txt"
 echo "PASS: replay $DANPER_REPLAY_LABEL only; combined coverage must be verified before packaging."
 exit 0
fi
# Only this marker allows packaging in CI or locally.
git rev-parse HEAD > "$OUT/VALIDATED_SHA.txt"
echo 'PASS: current checkout, 26 native and all 11 UI cases; no failures/skips. Core/Excel results are validated separately.'
