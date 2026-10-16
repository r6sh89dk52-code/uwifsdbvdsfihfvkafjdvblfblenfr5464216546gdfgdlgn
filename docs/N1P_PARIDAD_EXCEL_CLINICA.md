# N1p — Paridad experimental entre registro clínico y Excel oficial de 10 hojas

## Fuente exacta
Se conserva la base N1o (#77) sin modificar el motor antiguo. La fuente de reglas de exportación es **TypeScript actual** de build222: \`src/ambulatoryRows.ts\`, \`src/automaticClinicalDispensing.ts\`, \`src/ambulatoryExcel.ts\`, \`src/ambulatoryTemplate.json\` y \`src/procedureRules.ts\`.

## Alcance realizado
- Nuevo generador \`scripts/generate-n1p-excel-parity.cjs\` (solo CI): lee el fixture ficticio N1e FEFO generado por los propios motores TS, genera el plan provisional A–AD y el XLSX con el exportador TS existente, verifica directamente desde ZIP/XML **diez hojas, 432 materiales, 19 tablas, 30 columnas** y guarda únicamente una huella SHA-256 y las filas esperadas en directorio temporal del runner. Nunca sube el XLSX como artefacto.
- Las cinco atenciones ficticias incluyen cuatro consumos FEFO físicos auditados \`R=[5,1,0,12]\` y un consumo pendiente \`R=1000\` **solo en exportación provisional**, sin descuento real. \`R=0\` confirmado implica reutilización de un envase ya abierto, y NO debe confundirse con una entrega no verificada.
- Un segundo escenario ejercita una atención con dos artículos, frecuencia PRIMERA compartida entre dos filas, siguientes atenciones SEGUNDA a QUINTA, sexta frecuencia REVISAR, y exclusión de borradores y fechas fuera del corte.
- El auditor Swift independiente \`N1pExcelParityAudit\` revalida físicamente movimientos multilote y R con el validador N1e, reconstituye las treinta columnas, fecha y hora serial Excel, DNI con ceros iniciales, frecuencia por trabajador/fecha y valores provisional/confirmado. Compara todo contra el reporte producido por el motor TS.
- Pruebas negativas de sustitución indebida de 0 por 1, DNI truncado, frecuencia duplicada, columnas/hojas faltantes, fila reordenada, falso consumo conciliado y modificación de fuente o de movimientos físicos.
- \`canActivate=false\` y \`canClaimOfficialReconciledExport=false\` siempre: el libro de prueba se genera únicamente en CI con datos sintéticos, no en SwiftUI. No hay escritura clínica, migración, conversión inventada, nueva IPA o cambios en build222.

## Restricciones importantes
1. **Esto es paridad de lectura/filas y contrato XLSX generado por TypeScript, NO exportador Swift nativo completo**. Reconciliación oficial de RESU, CONTEO, INGRESOS/GUIA y actualización nativa de todas las fórmulas/estilos aún pendientes.
2. Solo se verifica con material de prueba y catálogo de fixture, no con respaldos reales de pacientes.
3. Antes de activar datos clínicos reales: verificar origen auténtico, reconstrucción transaccional durable, FEFO y paridad de todos los movimientos, y Excel original completo en un iPhone físico. No importar automáticamente.
