#!/usr/bin/env bash
set -euo pipefail
: "${BUILD_DIR:?}"
mkdir -p "$BUILD_DIR/logs" "$DANPER_N1_FIXTURE_DIR"
test "$(git rev-parse HEAD)" = "$GITHUB_SHA"
# Fix the audited Apple toolchain; fail visibly if this image drops it.
export DEVELOPER_DIR=/Applications/Xcode_16.4.app/Contents/Developer
test -d "$DEVELOPER_DIR"
echo "DEVELOPER_DIR=$DEVELOPER_DIR" >> "$GITHUB_ENV"
xcodebuild -version | tee "$BUILD_DIR/logs/toolchain.txt"
xcrun --sdk iphoneos --show-sdk-version | tee -a "$BUILD_DIR/logs/toolchain.txt"
swift --version | tee -a "$BUILD_DIR/logs/toolchain.txt"
if ! command -v xcodegen >/dev/null 2>&1; then brew install xcodegen; fi
xcodegen --version | tee -a "$BUILD_DIR/logs/toolchain.txt"
test "$(xcodegen --version)" = 'Version: 2.46.0'
npm ci --ignore-scripts --no-audit --no-fund
node scripts/prepare-n1s-ios-demo-resources.cjs 2>&1 | tee "$BUILD_DIR/logs/resources.log"
bash native-ios/scripts/make-app-icon.sh
xcodegen generate --spec native-ios/project.yml
LOCK=native-ios/DANPERNative.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
mkdir -p "$LOCK"
cp native-ios/Package.resolved "$LOCK/Package.resolved"
xcodebuild -resolvePackageDependencies -onlyUsePackageVersionsFromResolvedFile \
  -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative \
  -derivedDataPath "$BUILD_DIR/device" 2>&1 | tee -a "$BUILD_DIR/logs/toolchain.txt"
cmp native-ios/Package.resolved "$LOCK/Package.resolved"
