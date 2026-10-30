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
FLAGS=()
case "$CONFIGURATION" in
 baseline) ;;
 optimized) FLAGS=(-Xswiftc -DDANPER_PERF_OPTIMIZED) ;;
 *) exit 1 ;;
esac
DANPER_PERF_OUTPUT="$OUTPUT" swift test --package-path "$CHECKOUT/native-ios" -c release --jobs 2 \
  "${FLAGS[@]}" --filter N2PerformanceAuditTests
