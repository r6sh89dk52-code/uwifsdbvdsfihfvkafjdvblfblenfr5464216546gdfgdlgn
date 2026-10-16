# N1q — Paridad de conciliación RESU / CONTEO / INGRESOS y fórmulas

## Continuidad
Base N1p PR #78, 152 pruebas Swift aprobadas. Esta etapa es exclusivamente read-only y ficticia: no modifica main, la rama release build222, su Keychain, sus respaldos, stock ni el iPhone instalado.

## Fuente TypeScript real
`src/ambulatoryReconciliation.ts` + `src/ambulatoryRows.ts` + `src/ambulatoryExcel.ts`, catálogo `src/products.json` con 432 materiales y libro limpio `scripts/fixtures/ambulatory-empty.xlsx`. El generador `scripts/generate-n1q-reconciliation-fixtures.cjs` usa dos atenciones artificiales previamente enlazadas a Kardex y genera en RAM tres XLSX reales para contraste (revisado, sin cierre de ingresos, revisión anulada), inspecciona su ZIP/XML y almacena únicamente referencias JSON sintéticas en RUNNER_TEMP, sin subir artefactos.

## Validaciones independientes Swift
- `N1qReconciliationParityAudit` compara los 432 materiales contra los resultados del motor TS, sus ingresos por fecha, documento y vencimiento (máximo cuatro), stock inicial, conteo, consumo físico confirmado y saldo calculado. Reutiliza `N1eLegacyClinicalAudit` para las salidas multilote y la distinción R=0 vs pendiente.
- `0` contado debe permanecer distinto de la ausencia de recuento. Antes de cerrar ingresos, la **cantidad recibida total X queda sin verificación (celda vacía, no cero)** y no se inventa saldo final.
- Comprueba la legitimidad de anulaciones, duplicados, registros posteriores a cierre, unidades oficiales, rangos numéricos, diferencias de stock y fuentes modificadas.
- Comprueba el texto exacto de fórmulas para las columnas de CONTEO, INGRESOS (incluida X solo tras revisión) y RESU (E,F,G,H,I,J,L), con cuatro filas muestreadas. El generador TS también verifica que las fórmulas necesarias existan en las **432 filas** antes de entregar la referencia.
- Compara celda por celda el stock/corte/ingresos de cuatro materiales testigo en el XLSX real, incluyendo fechas Excel, números de documento y columna M de RESU vacía.
- Las pruebas negativas modifican deliberadamente valores, documentos, fórmulas, anulación, recibos, fuente y libro, para garantizar fallo cerrado.

## Límites
- N1q no genera Excel en Swift ni verifica el cálculo de fórmulas en Microsoft Excel: comprueba sus cadenas textuales y los valores/fórmulas escritos por el exportador TypeScript contra un auditor Swift independiente.
- La revisión del período tampoco demuestra que los recuentos sean reales; el laboratorio solamente usa datos ficticios.
- Cero activación clínica, cero migración o publicación de IPA. Aún falta exportación XLSX enteramente nativa, reconciliación real y validación local del respaldo autenticado en iPhone con recuperación transaccional durable.
