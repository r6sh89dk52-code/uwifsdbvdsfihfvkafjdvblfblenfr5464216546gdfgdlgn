#!/usr/bin/env bash
set -euo pipefail
test "$#" = 3 || { echo 'usage: run-core.sh CHECKOUT OUTPUT_JSON baseline|optimized'; exit 1; }
CHECKOUT="$1"; OUTPUT="$2"; CONFIGURATION="$3"
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
: "${DANPER_N1_FIXTURE_DIR:?Generate synthetic fixtures first}"
TARGET="$CHECKOUT/native-ios/Tests/DanperCoreTests/N2PerformanceAuditTests.swift"
test ! -e "$TARGET"
cp "$ROOT/scripts/performance/N2PerformanceAuditTests.swift" "$TARGET"
trap 'rm -f "$TARGET"' EXIT
FLAGS=(-Xswiftc -enable-testing)
case "$CONFIGURATION" in
 baseline) ;;
 optimized) FLAGS+=(-Xswiftc -DDANPER_PERF_OPTIMIZED) ;;
 *) exit 1 ;;
esac
# Compile outside the resource measurement. The timed process runs only the
# prepared workload, not the compiler. This is Core/XCTest RSS, not iPhone RAM.
swift build --package-path "$CHECKOUT/native-ios" -c release --jobs 2 --build-tests "${FLAGS[@]}"
LC_ALL=C /usr/bin/time -f '{"user_cpu_s":%U,"system_cpu_s":%S,"peak_rss_kib":%M,"wall_s":%e}' \
  -o "$OUTPUT.resources.json" env DANPER_PERF_OUTPUT="$OUTPUT" \
  swift test --package-path "$CHECKOUT/native-ios" -c release --jobs 2 --skip-build \
  "${FLAGS[@]}" --filter N2PerformanceAuditTests
