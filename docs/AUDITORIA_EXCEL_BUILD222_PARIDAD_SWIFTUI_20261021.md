# Auditoría de paridad Build 222 → DANPER SwiftUI

Fecha: 2026-10-21. Fuente: código histórico `release/v0.21.12-build222-provisional-consumptions` y SwiftUI de `feat/build222-native-ui-parity-20261020`. Este documento NO es una certificación clínica ni afirma que un Excel privado original haya sido abierto durante esta revisión.

## Veredicto
- **No declarar paridad Excel total.** Las rutas SwiftUI son nativas y derivan de plantillas sanitizadas del proyecto, pero hay diferencias concretas y escenarios que no están probados.
- No comparar archivos XLSX mediante SHA ZIP bruto como criterio único: metadata, reserialización OOXML, compresión, índices de texto y estilo de fechas pueden producir bytes distintos aunque los valores/fórmulas coincidan.
- La referencia funcional es el exportador TS de Build 222, el objetivo final de validación es la plantilla oficial PRIVADA del indicador (10 hojas) y el Kardex enfermería de 98 productos, sin difundir el libro con información histórica.

## Matriz
| Elemento | Build 222 | SwiftUI | Estado |
|---|---|---|---|
| Indicador 10 hojas | `ambulatoryExcel.ts` valida diez nombres originales | `N1sFullExcelWriter` valida nombres y usa la plantilla OOXML almacenada | Implementado, prueba visual pendiente |
| Catálogo | 432 códigos oficiales / no mezcla códigos alfanuméricos | 432 códigos | Implementado, equivalencia validable por fixtures |
| Tablas de Excel | 19, con CONSUMOS / TB_CONSUMOS A:AD | 19 partes OOXML | Implementado, revisar todas las referencias y estilos |
| CONSUMOS | 30 columnas y R vinculada al movimiento físico | 30 columnas, R derivada de `N1eLegacyClinicalAudit` | Pruebas sintéticas parciales |
| R=0 / R=1 | Caja/frasco cuenta 1 al abrir, 0 en usos posteriores confirmados; registro no equivale a movimiento | Regla nativa de apertura y audit de entrega | Pruebas existentes, validar físicamente |
| Fórmulas de CONTEO, INGRESOS, RESU | `applyFormulas` | `N1sFullExcelWriter.formula` | Correspondencias principales comprobables; no afirmar 100% |
| Sedes | Fundo y Planta en un mismo reporte; corte mes 9–8 | Sedes individuales o ambas; selección rápida mes 9–8 | Implementado; comprobar cierres por sede |
| Kardex enfermería | hoja única `KARDEX ENFERMERAS`, 98 filas (omite hoja auxiliar) | Antes informaba 1 hoja sin retirar la hoja auxiliar; se añadió `stripDonorWorksheet` | **Corregido en fuente, pendiente XCTest en Mac** |
| Kardex fórmulas | F=D+E, H=F-G; otras D/E/G/I/J | mismas F y H | Comparación sintética por D7:J104 |
| Stock desconocido | celda vacía, no cero | Antes impedía exportar si todos los productos tenían stock desconocido | **Corregido** |
| Incidencias históricas de entrega | TS valida incidentes y bloquea únicamente movimientos en conflicto | `N2VerifiedIndicatorWorkbook` todavía exige `deliveryIncidents.isEmpty` | **Corregido en fuente**, falta ejecutar prueba de incidencias y escenario real |
| Datos de origen | Build 222 usa padrones de PERSONAL y respaldos cifrados | Vista de importación `N2NativePersonalImportView` y bóveda independiente | Flujo de importación existente, pendiente prueba con padrón autorizado |
| Primera ejecución | trabajador desde padrón | Inicio estándar ahora abre fuente clínica verificada/importación; no crea demo | Cambio de fuente integrado |
| Exportación real | Archivo XLSX listo para Excel | `N2VerifiedIndicatorWorkbook` / `N2VerifiedNursingWorkbook` | Validación visual y de Excel real pendiente |

## Correcciones integradas
1. `DANPERNativeApp` dirige la ruta normal a `N2ClinicalWorkspaceGateView`; importación de `PERSONAL` como primera opción; se conserva restauración 222 independiente. No se borran ni trasladan automáticamente archivos existentes.
2. `N1sNursingExcelWriter` ahora elimina `Hoja1`, `sheet1.xml` y sus referencias de workbook, relaciones, tipos de contenido, metadatos y configuraciones de impresión asociadas. Reindexa sharedStrings de la hoja preservada y confirma una hoja en el ZIP resultante.
3. `N2VerifiedNursingWorkbook` permite exportar 98 filas cuando no existen lotes conocidos. Todos los saldos permanecen en blanco, sin inventar cantidades cero.
4. `N2VerifiedIndicatorWorkbook` permite historial de incidencias de otros movimientos, pero bloquea las atenciones seleccionadas cuyos movimientos tengan devolución o discrepancia. Falta ejecutar el nuevo XCTest de alcance de incidencias.
4. Prueba JS de comparación TS/Swift extendida para exigir una sola hoja de Kardex y ausencia de componentes donados; XCTest nativo añadido para exportar desde padrón sin stock.

## Cómo auditar sin datos personales
```bash
cd ~/Downloads/DANPER_BUILD222_NATIVE
bash scripts/audit-build222-excel-parity-macos.sh
```
El script genera fixtures sintéticos aislados, ejecuta pruebas `N1sCombinedOfficialExcelTests` y `N2NursingParityTests`, genera dos libros Swift y los compara con archivos creados por TS. Conserva la evidencia en Downloads. Debe ejecutarse en Mac con Node y Swift instalados. Esta auditoría no prueba la apertura visual de Excel ni sustituye la comparación con los dos archivos originales privados.

## Condiciones de aceptación antes de declarar paridad completa
1. Contrastar el XLSX privado original contra plantilla sanitizada: nombres, fórmulas, rangos, comentarios y diseños de impresión. Nunca subir el original clínico al repositorio.
2. Comparación XML por celda para todos los códigos y todos los registros de CONSUMOS (A–AD), fechas seriales y fórmula cache.
3. Validar cada tabla estructurada y sus rangos, todas las referencias de hojas y cadenas compartidas, y que no haya piezas OOXML huérfanas.
4. Probar escenarios: sin stock, stock parcial, aperturas de caja/frasco, múltiples lotes FEFO, consumos R=0 confirmados, movimientos históricos sin confirmar, múltiples sedes, ingresos superiores a cuatro (debe bloquear sin truncar), fechas de vencimiento y cortes consecutivos.
5. Ejecutar `N2IncidentExportScopeTests` y escenarios reales de incidencias: el código ahora valida las incidencias y bloquea solo atenciones con movimientos afectados, sin rechazar todo el historial.
6. Abrir libros en Excel macOS/Windows; comprobar advertencias de reparación, recálculo y aspecto impreso.
7. Probar importación `PERSONAL` autorizada y persistencia tras cerrar/reabrir, sin datos de prueba precargados.

Resultado por ahora: **implementación sustancial, no paridad exacta acreditada**.
