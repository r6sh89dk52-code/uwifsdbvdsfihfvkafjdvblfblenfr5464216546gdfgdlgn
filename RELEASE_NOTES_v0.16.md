# DANPER Salud Móvil v0.16 — conciliación auditable del Indicador Ambulatorio

Base: v0.15.1 ya fusionada, con cantidades de entregas por unidad y apertura de envases correctas.

## Alcance y fuente
Único libro de exportación: `01 INDICADOR AMBULATORIO -KARDEX 2026(2).xlsx` (10 hojas, 432 materiales de códigos exclusivamente numéricos).
El Kardex de Enfermería de 98+6 productos es independiente; **no** se usa su recuento para completar el Indicador Ambulatorio.

## Registro de prueba en iPhone
- Dentro de `Inicio → Exportar`, elegir fecha, subdivisión y plantilla original.
- Registrar **stock inicial** confirmado por material en unidad oficial en la fecha de inicio.
- Registrar **ingreso** con cantidad positiva, documento de respaldo, fecha del ingreso y vencimiento opcional. Como el libro original tiene 4 columnas de ingreso por material, más de 4 movimientos del mismo material en el intervalo **bloquean** la conciliación para evitar truncamiento.
- Registrar **conteo final** confirmado por material en la fecha final. Un conteo confirmado en cero es diferente de un conteo no realizado.
- Registrar **cierre/revisión de ingresos del período** con motivo. Sólo después de cerrar, la falta de ingresos se interpreta como cero. Si hay un ingreso registrado después del cierre, hay que anular el cierre y registrarlo de nuevo.
- Anulación auditada por identificador; nunca se edita destructivamente un recuento o ingreso.
- Los eventos se guardan en la snapshot Keychain que utiliza la app iOS, con migración compatible desde v0.15.1 (lista inicial vacía).
- Persistencia limitada a datos ficticios de prueba; no hay requisitos completos de producción, copias/roles, ni base clínica escalable.

## Exportación
En `CONTEO`, columna D: conteos registrados; lo no registrado permanece vacío.
En `INGRESOS`, H/L/P/T: cantidades; I/M/Q/U: fechas; J/N/R/V: vencimientos; K/O/S/W: documentos. X calcula el total por fórmula si el período está revisado, con cero confirmado cuando no hay ingresos. Si no está revisado, X se deja vacío.
En `RESU`, columna D: stock inicial confirmado; E, F, G, H, I, J, L conservan sus fórmulas o se reconstruyen desde los valores conciliados. M: aviso de pendientes y diferencias.
Stock teórico = inicial + ingresos revisados - consumo confirmado. F/S compara el saldo teórico con el conteo real. El estado cero **no equivale** a dato ausente.
La hoja `CONSUMOS` sigue usando exclusivamente entregas confirmadas y la regla v0.15.1; exportar no modifica ni vuelve a descontar inventario.

## Validaciones a ejecutar
- `npm run test:logic`, `npm run test:ambulatory`, `npm run build`, `npm run ios:check`, `npm audit --audit-level=high`.
- Pruebas de archivos XLSX con fuente ficticia vacía depurada y revisión de sus 10 hojas, 432 materiales, 19 tablas, datos privados, formulas y referencias.
- Pruebas: ausencia vs cero, stocks negativos, códigos alfanuméricos, duplicados, 5 ingresos, cierre y registro tardío, anulación, conservación de trazabilidad y compatibilidad de snapshot.
- Compilación IPA sin firmar en macOS GitHub Actions. Instalar en SideStore y abrir XLSX en Microsoft Excel sigue siendo validación manual, no afirmar que pasó.

## Limitaciones conocidas
- Los datos de ingreso, cierre y conteo son confirmaciones manuales de **prueba**. No se obtiene automáticamente un kardex independiente del almacén central.
- El modelo soporta una revisión de ingresos por período y hasta 4 entradas por material, según el formato original. No agrega silenciosamente 5 ingresos o más.
- La etiqueta 'CONCILIADO' sólo aplica cuando existen stock inicial, revisión de ingresos y conteo físico; una diferencia F/S distinta de cero exige revisión adicional.
