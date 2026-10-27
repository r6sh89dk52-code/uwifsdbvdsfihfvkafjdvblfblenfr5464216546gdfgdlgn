#!/usr/bin/env bash
set -euo pipefail
: "${BUILD_DIR:?}"
mkdir -p "$BUILD_DIR/logs" "$DANPER_N1_FIXTURE_DIR"
for generator in generate-native-compat-fixtures generate-n1e-clinical-fixtures generate-n1f-lossless-fixtures generate-n1h-clinical-parity generate-n1p-excel-parity generate-n1q-reconciliation-fixtures generate-n1r-stored-xlsx-template generate-n1s-official-excel-fixtures generate-n2-approved-fixture generate-n2-nursing-parity generate-n2-procedure-parity generate-n2-stock-commands-fixtures; do
  node "scripts/$generator.cjs" >> "$BUILD_DIR/logs/fixtures.log" 2>&1
done
if [[ "${1:-}" == fixtures-only ]]; then exit 0; fi
swift --version | tee "$BUILD_DIR/logs/swift-toolchain.txt"
swift scripts/diagnose-foundation-equality.swift 2>&1 | tee "$BUILD_DIR/logs/foundation-portability.log"
swift test --package-path native-ios --force-resolved-versions --jobs 3 2>&1 | tee "$BUILD_DIR/logs/swift-core.log"
