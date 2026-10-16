# DANPER N1e — Paridad clínica y Kardex sin importar datos

## Inspección de estructuras reales
- Source of truth: `src/attentionKardex.ts`, `src/automaticClinicalDispensing.ts`, `src/inventoryRules.ts`, `src/kardexMovements.ts`, `docs/AUDITORIA_CRUZADA_FEFO_EXCEL.md`.
- Swift `N1eLegacyClinicalAudit.inspect` valida solo lectura, usando 9 colecciones del snapshot; comprueba identidad de trabajador, líneas clínicas, lotes y movimientos de Kardex. No corrige ni reescribe historiales.
- Comprueba grupos físicos multilote completos, `ATT:<atención>:ITEM:<item>:PART:<n>`, consistencia de identidad, cantidad y parte, cierre de saldos por lote, signo y magnitud de cambios físicos, Excel R por movimiento.
- Preserva diferencia entre `nil` (consumo clínico pendiente **sin salida física**) y `0` (uso confirmado de envase abierto). Columna R se calcula **una vez por línea clínica**, no por movimiento.
- SHA-256 del JSON fuente permite verificar inmutabilidad exacta de la fuente durante una inspección (no sustituye autenticación GCM original).

## Validación cruzada sintética
`scripts/generate-n1e-clinical-fixtures.cjs` usa los motores TS reales `finalizeVisitAndPlanStock`, `validateStockLedger` y `buildAmbulatoryRows` para 5 atenciones inventadas, incluidos 4 items con movimiento FEFO y 1 pendiente. Verifica R = [5, 1, 0, 12, null], salidas UND en varios lotes, apertura reutilizada CJA y físico separado del consumo clínico.
- Genera datos y mutaciones de prueba **exclusivamente en el directorio temporal RUNNER_TEMP** (no quedan archivados ni como artefactos).
- Pruebas negativas: grupo incompleto, DNI duplicado, Excel R falsificado, saldo final divergente, modificación de cantidad clínica, movimiento duplicado y referencia inexistente.
- Conserva las pruebas N1b/N1c/N1d y realiza solo swift test en ubuntu-latest.

## Gates pendientes
- Auditoría comparativa de todos los campos clínicos opcionales, historial de alergias y datos de procedimientos: el validador actual se centra en identidad, consumos y Kardex.
- Paridad de escritura y regeneración íntegra de los dos XLSX, especialmente las **10 hojas del Indicador** y los **98 productos del Kardex**, aún no realizada por Swift.
- No hay adaptador Keychain ni importador operativo: el descifrado y la validación no habilitan restauración de datos reales.
- Las reglas de histórico no fabrican movimientos anteriores ni saldos. Límites existentes: 500 lotes, 1000 movimientos, 1200 conciliaciones. Ampliarlos requerirá estudio de paginación y migraciones.
- Sin runner macOS y sin nuevas IPA. Mantener la build222 intacta y la PR en borrador.
