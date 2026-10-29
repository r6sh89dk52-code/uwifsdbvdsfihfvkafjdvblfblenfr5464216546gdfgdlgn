#!/usr/bin/env bash
# Rebuild candidate; rerun suites whose inputs cannot be proven equal.
set -euo pipefail
cd "$(dirname "$0")/../.."
: "${DANPER_AUDIT_OUT:?Evidence directory}"
: "${DANPER_BASELINE_EVIDENCE:?Recovered immutable baseline}"
OUT="$DANPER_AUDIT_OUT"; DD="$OUT/DerivedData"
mkdir -p "$OUT"
export DANPER_N1_FIXTURE_DIR="$OUT/fixtures"
git rev-parse HEAD > "$OUT/SOURCE_SHA.txt"
git rev-parse HEAD^{tree} > "$OUT/SOURCE_TREE.txt"
xcodebuild -version > "$OUT/xcode-version.txt"
uname -m > "$OUT/architecture.txt"
xcrun simctl list runtimes -j > "$OUT/runtimes.json"
python3 scripts/glass-audit/verify-scoped-reuse.py "$DANPER_BASELINE_EVIDENCE" "$OUT"
echo 'PHASE: generate deterministic fixtures and resources'
bash scripts/glass-audit/prepare.sh
echo 'PHASE: validate JavaScript guards and both workbook controls'
node scripts/glass-audit/javascript.cjs > "$OUT/javascript.log" 2>&1
for name in test-n1r-native-xlsx test-n1s-full-native-workbooks; do
 node "scripts/$name.cjs" > "$OUT/$name.log" 2>&1
done
git rev-parse HEAD > "$OUT/JAVASCRIPT_VALIDATED_SHA.txt"
if test "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["suites"]["swift"]["identical"])' "$OUT/SCOPED_REUSE.json")" != True; then
 echo 'PHASE: Swift inputs changed; rerun package suite'
 (cd native-ios && swift test --jobs 2) > "$OUT/swift-412.log" 2>&1
 python3 - "$OUT/swift-412.log" <<'PY'
import re,sys
s=open(sys.argv[1]).read();assert re.search(r'Executed 412 tests, with 0 failures',s),s[-4000:]
assert not re.search(r'\d+ tests? (?:were )?skipped',s)
PY
fi
git rev-parse HEAD > "$OUT/SWIFT_VALIDATED_SHA.txt"
node scripts/glass-audit/identity.cjs
(cd native-ios && bash scripts/make-app-icon.sh && xcodegen generate --spec project.yml) > "$OUT/xcodegen.log" 2>&1
echo 'PHASE: rebuild/revalidate simulator binaries for this checkout'
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug \
 -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DD" \
 ARCHS="$(uname -m)" ONLY_ACTIVE_ARCH=YES build-for-testing 2>&1 | tee "$OUT/build-for-testing.log"
git rev-parse HEAD > "$OUT/BUILD_SUCCESS_SHA.txt"
if test "$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["suites"]["native"]["identical"])' "$OUT/SCOPED_REUSE.json")" = True; then
 # Permitted only by byte-identity proof and pinned PASS evidence.
 git rev-parse HEAD > "$OUT/CORE_NATIVE_SHA.txt"
else
 echo 'PHASE: native inputs changed; rerun native suite'
 bash scripts/glass-audit/validate-macos.sh scoped-native
fi
