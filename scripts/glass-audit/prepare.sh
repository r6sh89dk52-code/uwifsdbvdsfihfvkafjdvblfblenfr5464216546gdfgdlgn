#!/usr/bin/env bash
set -euo pipefail
: "${DANPER_AUDIT_OUT:?Set an absolute evidence directory}"
mkdir -p "$DANPER_AUDIT_OUT/fixtures"
export DANPER_N1_FIXTURE_DIR="$DANPER_AUDIT_OUT/fixtures"
npm ci --ignore-scripts --no-audit --no-fund > "$DANPER_AUDIT_OUT/npm.log" 2>&1
for name in native-compat-fixtures n1e-clinical-fixtures n1f-lossless-fixtures n1h-clinical-parity n1p-excel-parity n1q-reconciliation-fixtures n1r-stored-xlsx-template n1s-official-excel-fixtures n2-approved-fixture n2-nursing-parity n2-procedure-parity n2-stock-commands-fixtures; do
  node "scripts/generate-$name.cjs" >> "$DANPER_AUDIT_OUT/fixtures.log" 2>&1
done
node scripts/prepare-n1s-ios-demo-resources.cjs > "$DANPER_AUDIT_OUT/resources.log" 2>&1
# The clinical sample belongs to the test bundle, never the operational app.
test ! -f native-ios/App/N1sDemoResources/n2-synthetic-clinical.json
test -f native-ios/NativeTests/SyntheticFixtures/n2-synthetic-clinical.json
