#!/usr/bin/env bash
# Synthetic-only acceptance. Creates its own Simulator; never erases an existing device.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for tool in swift node xcodegen xcodebuild xcrun python3; do command -v "$tool" >/dev/null; done
: "${DANPER_N1_FIXTURE_DIR:?Point DANPER_N1_FIXTURE_DIR to the generated fictional compatibility fixtures}"
test -s "$DANPER_N1_FIXTURE_DIR/n1s-nursing-template-store.zip"
DANPER_V2_TMP="${TMPDIR:-/tmp}"
DANPER_V2_OUT="$(mktemp -d "${DANPER_V2_TMP%/}/danper-kardex-v2-XXXXXX")"
DANPER_V2_RUNTIME="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; r=[x for x in json.load(sys.stdin)["runtimes"] if x.get("isAvailable") and x.get("name","").startswith("iOS")]; print(r[-1]["identifier"] if r else "")')"
test -n "$DANPER_V2_RUNTIME"
DANPER_V2_SIM="$(xcrun simctl create "DANPER-Kardex-V2-$(date +%Y%m%d-%H%M%S)" com.apple.CoreSimulator.SimDeviceType.iPhone-16 "$DANPER_V2_RUNTIME")"
printf 'Resultados: %s\nSimulador aislado: %s\n' "$DANPER_V2_OUT" "$DANPER_V2_SIM"
swift test --package-path native-ios --jobs 2 >"$DANPER_V2_OUT/swift.log" 2>&1
npm run test:logic >"$DANPER_V2_OUT/javascript.log" 2>&1
for guard in test-n2-simple-inventory-v2 test-n2-build222-ui-parity test-n2-premium-redesign test-n2-workspace-routing audit-n2-workspace-routing audit-n2-build222-backup-restore audit-n2-swift-string-concatenations; do
  node "scripts/$guard.cjs" >>"$DANPER_V2_OUT/guards.log" 2>&1
done
xcodegen generate --spec native-ios/project.yml >"$DANPER_V2_OUT/xcodegen.log" 2>&1
xcrun simctl boot "$DANPER_V2_SIM"
xcrun simctl bootstatus "$DANPER_V2_SIM" -b >"$DANPER_V2_OUT/boot.log" 2>&1
xcrun simctl spawn "$DANPER_V2_SIM" notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
xcrun simctl spawn "$DANPER_V2_SIM" notifyutil -p com.apple.BiometricKit.enrollmentChanged
xcodebuild build-for-testing -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -jobs 2 \
  -destination "platform=iOS Simulator,id=$DANPER_V2_SIM" -derivedDataPath "$DANPER_V2_OUT/DerivedData" >"$DANPER_V2_OUT/build.log" 2>&1
# Each device receives its own source and draft fixture before any UI test.
xcodebuild test-without-building -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative \
  -destination "platform=iOS Simulator,id=$DANPER_V2_SIM" -derivedDataPath "$DANPER_V2_OUT/DerivedData" \
  -parallel-testing-enabled NO -only-testing:DANPERNativeTests -resultBundlePath "$DANPER_V2_OUT/native.xcresult" >"$DANPER_V2_OUT/native.log" 2>&1
grep -q 'Executed 16 tests, with 0 failures' "$DANPER_V2_OUT/native.log"
xcodebuild test-without-building -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative \
  -destination "platform=iOS Simulator,id=$DANPER_V2_SIM" -derivedDataPath "$DANPER_V2_OUT/DerivedData" \
  -parallel-testing-enabled NO -only-testing:DANPERInteractionTests -resultBundlePath "$DANPER_V2_OUT/ui.xcresult" >"$DANPER_V2_OUT/ui.log" 2>&1
grep -q 'Executed 8 tests, with 0 failures' "$DANPER_V2_OUT/ui.log"
printf 'Aceptación terminada. Revisa logs y capturas en %s\nNo se creó IPA ni se publicó código.\n' "$DANPER_V2_OUT"
