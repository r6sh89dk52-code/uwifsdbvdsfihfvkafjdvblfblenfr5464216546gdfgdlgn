#!/usr/bin/env bash
# B11 fail-closed clinical P0 gate. 100% synthetic tests. Creates and deletes
# ONLY a newly generated simulator; never erases the user's other simulators,
# never installs on a real iPhone and never reads actual patient backups.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${DANPER_B11_BUILD_OUTPUT:-$HOME/Downloads/DANPER_B11_SIM_BUILDS}"
mkdir -p "$DEST"
echo 'B11 clinical gate: isolated clean simulator, no IPA, no patient records.'
echo "Commit: $(git -C "$ROOT" rev-parse --short HEAD)"
command -v node >/dev/null || { echo 'Missing Node'; exit 1; }
command -v xcrun >/dev/null || { echo 'Missing Xcode command line tools'; exit 1; }
command -v python3 >/dev/null || { echo 'Missing python3'; exit 1; }
bash "$ROOT/scripts/check-b11-priority-parity-macos.sh"

# Build a new, isolated simulator. Never boot or erase the user's existing one.
TYPE="$(xcrun simctl list -j devicetypes | python3 -c '
import sys,json
items=json.load(sys.stdin)["devicetypes"]
choice=next((x for x in items if x["name"]=="iPhone 16"),None)
if choice is None: choice=next((x for x in items if x["name"].startswith("iPhone")),None)
if choice is None: sys.exit("No iPhone type")
print(choice["identifier"])
')"
RUNTIME="$(xcrun simctl list -j runtimes | python3 -c '
import sys,json
items=json.load(sys.stdin)["runtimes"]
match=[x for x in items if x.get("isAvailable") and x["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")]
if not match: sys.exit("No available iOS simulator runtime")
print(match[-1]["identifier"])
')"
SIM_NAME="DANPER-B11-TEMP-$(date +%s)-$$"
SIM_ID=""
cleanup() {
    if [ -n "$SIM_ID" ]; then
        xcrun simctl shutdown "$SIM_ID" >/dev/null 2>&1 || true
        xcrun simctl delete "$SIM_ID" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT INT TERM
SIM_ID="$(xcrun simctl create "$SIM_NAME" "$TYPE" "$RUNTIME")"
echo "Temporary test simulator: $SIM_NAME ($SIM_ID)"
xcrun simctl boot "$SIM_ID"
xcrun simctl bootstatus "$SIM_ID" -b
cd "$ROOT/native-ios"
LOG="$DEST/DANPER_B11_CLINICAL_P0_TEST.log"
RESULT="$DEST/DANPER_B11_CLINICAL_P0_TEST.xcresult"
if [ -e "$RESULT" ]; then
    echo "Existing test result bundle retained. Move it before retrying: $RESULT" >&2
    exit 1
fi
# Unit interop: build222 backup archive encryption, read-only inspection,
# decryption with correct/incorrect password, integrity and clinical history.
set +e
xcodebuild -project DANPERNative.xcodeproj -scheme DANPERNative \
    -configuration Debug -sdk iphonesimulator \
    -destination "platform=iOS Simulator,id=$SIM_ID" \
    -destination-timeout 180 -parallel-testing-enabled NO \
    -derivedDataPath "$DEST/DerivedData" \
    -resultBundlePath "$RESULT" \
    -only-testing:DANPERNativeTests/N2PortableBackupInteropTests \
    CODE_SIGNING_ALLOWED=NO test > "$LOG" 2>&1
TEST_STATUS=$?
set -e
if [ "$TEST_STATUS" -ne 0 ] || ! grep -q 'TEST SUCCEEDED' "$LOG"; then
    echo 'FAILED: clinical interop XCTest. Compiler/test diagnostics:' >&2
    grep -nE '(error:|failed|FAIL|Testing failed|TEST FAILED|XCTAssert)' "$LOG" | tail -n 65 >&2 || true
    echo "Full test log: $LOG" >&2
    exit 1
fi
echo 'PASS: backup format and clinical test source interoperability in isolated iOS Simulator.'
echo 'Still required: original private build222 .danperbackup preview/restore on-device,'
echo 'Excel A-AD validation, inventory reconciliation and physical iPhone tests.'
