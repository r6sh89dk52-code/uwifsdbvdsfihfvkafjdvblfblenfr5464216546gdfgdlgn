#!/usr/bin/env bash
set -euo pipefail
: "${DANPER_N1_FIXTURE_DIR:?Generate synthetic fixtures first}"
: "${DANPER_BUILD14_FIXTURE_OUT:?Use an isolated CI evidence folder}"
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BASE="$1"
git worktree add --detach "$BASE" 9b1da6d4cdead4729bcade6843abcbcfc287e870
cat "$ROOT/scripts/performance/Build14FixtureProducer.swift" >> "$BASE/native-ios/Tests/DanperCoreTests/N2SimpleInventoryTests.swift"
swift test --package-path "$BASE/native-ios" -c release --jobs 2 \
  --filter N2SimpleInventoryTests/testExportBuild14CompatibilityFixture
TARGET="$ROOT/native-ios/Tests/DanperCoreTests/N2Build14ForwardCompatibilityTests.swift"
test ! -e "$TARGET"
cp "$ROOT/scripts/performance/N2Build14ForwardCompatibilityTests.swift" "$TARGET"
trap 'rm -f "$TARGET"' EXIT
export DANPER_COMPAT_CONSUMER_SHA
DANPER_COMPAT_CONSUMER_SHA=$(git -C "$ROOT" rev-parse HEAD)
swift test --package-path "$ROOT/native-ios" -c release --jobs 2 \
  --filter N2Build14ForwardCompatibilityTests
