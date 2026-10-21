#!/usr/bin/env bash
# Native-vs-Build222 synthetic Excel parity audit. NO clinical data, no real backups.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for cmd in node npm swift; do command -v "$cmd" >/dev/null || { echo "Falta $cmd" >&2; exit 1; }; done
STAMP="$(date +%Y%m%d_%H%M%S)"
DEST="$HOME/Downloads/DANPER_B222_AUDITORIA_EXCEL_$STAMP"
mkdir -p "$DEST"
export DANPER_N1_FIXTURE_DIR="$DEST"
echo "Auditoría Excel con fuentes sanitizadas: $DEST"
echo "No se abren padrones ni respaldos privados."
npm ci
for script in \
  generate-native-compat-fixtures.cjs \
  generate-n1e-clinical-fixtures.cjs \
  generate-n1f-lossless-fixtures.cjs \
  generate-n1h-clinical-parity.cjs \
  generate-n1p-excel-parity.cjs \
  generate-n1q-reconciliation-fixtures.cjs \
  generate-n1r-stored-xlsx-template.cjs \
  generate-n1s-official-excel-fixtures.cjs \
  generate-n2-approved-fixture.cjs \
  generate-n2-nursing-parity.cjs; do
  node "scripts/$script"
done
echo "Verificando exportadores Swift y diferencias de inventario..."
( cd native-ios && swift test --filter N1sCombinedOfficialExcelTests --jobs 2 ) 2>&1 | tee "$DEST/swift-excel.log"
( cd native-ios && swift test --filter N2NursingParityTests --jobs 2 ) 2>&1 | tee "$DEST/swift-kardex.log"
( cd native-ios && swift test --filter N2IncidentExportScopeTests --jobs 2 ) 2>&1 | tee "$DEST/swift-incident-scope.log"
for file in n1s-indicator-native.xlsx n1s-nursing-native.xlsx; do
  [ -s "$DEST/$file" ] || { echo "Falta el libro generado $file" >&2; exit 1; }
done
node scripts/test-n1s-full-native-workbooks.cjs 2>&1 | tee "$DEST/paridad-js-swift.log"
echo ""
echo "AUDITORÍA SINTÉTICA FINALIZADA — comparar datos y fórmulas con TS."
echo "Evidencia conservada en: $DEST"
echo "PENDIENTE: comprobar visualmente en Excel macOS/Windows y contrastar con las plantillas privadas originales."
