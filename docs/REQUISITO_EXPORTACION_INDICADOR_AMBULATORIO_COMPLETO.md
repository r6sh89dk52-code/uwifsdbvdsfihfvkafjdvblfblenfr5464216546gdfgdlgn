# Requisito prioritario — Exportación del libro COMPLETO de Indicador Ambulatorio

**Confirmación del usuario (2026-10-13).** La exportación del Indicador de Atenciones Ambulatorias debe generar, como primera opción, **todo el libro original XLSX**, no solamente la hoja `CONSUMOS`.

## Fuente oficial y alcance exacto
Archivo de referencia adjuntado por el usuario:
`REAL INDICADOR AMBULATORIO -KARDEX (MEJORADO) (version 1).xlsx`.

Inspección estructural del libro original:
- 15 hojas, en el orden original: `BD MATERIALES`, `CONSUMOS2`, `RESU (2)`, `KARDEX DIARIO`, `CONSUMOS`, `CONTEO`, `INGRESOS`, `RESU`, `REGISTRO`, `PERSONAL`, `GUIA`, `@subuo`, `BASE TRU`, `@uo`, `JUSTIFICACIONES`.
- `CONSUMOS`: encabezados A:AD; tabla estructurada `TB_CONSUMOS`; 168 filas actuales, parte de sus columnas contienen fórmulas de búsqueda al padrón/catálogos.
- `CONSUMOS2`: tabla `TB_CONSUMOS2` con atenciones históricas.
- `RESU` y `RESU (2)`: resúmenes con fórmulas de consumo, inventario e ingresos; NO copiar valores históricos.
- `PERSONAL` y `BASE TRU`: contienen miles de registros personales históricos de plantilla. **No incluir datos históricos no autorizados en ninguna exportación.**
- `GUIA`, `@subuo`, `@uo`, `BD MATERIALES`: referencias auxiliares para validaciones y fórmulas.
- El archivo contiene al menos una tabla dinámica y caché de tabla dinámica basada en `TB_CONSUMOS`, además de tablas y metadatos OOXML.

## Comportamiento de exportación requerido
1. **Opción predeterminada:** `Exportar libro completo (original)`. `Solo hoja CONSUMOS` es una alternativa secundaria, disponible si no es posible asegurar la integridad del libro.
2. Preservar nombres, orden de hojas, estilos, columnas, filas de encabezado, fórmulas, referencias y tablas, configuraciones de impresión y elementos compatibles de la plantilla.
3. Exportar exclusivamente los datos de atenciones y consumos del período seleccionado desde DANPER. La opción semanal por defecto será `esta semana`, con posibilidad de cambiar el intervalo.
4. Una atención con múltiples medicamentos/insumos puede generar varias filas en `CONSUMOS`; debe mantenerse un único identificador de atención, evitando duplicar registro clínico o consumos al repetir la exportación.
5. Usar los códigos oficiales guardados junto al producto. `CONSUMOS` columna R: para envases abiertos, 1 solo al confirmar apertura y 0 para usos posteriores; para unidad individual, la cantidad real entregada. No inferir códigos ni dosis por coincidencia de nombres.
6. Redimensionar `TB_CONSUMOS` y las fórmulas necesarias cuando el número de filas supere el espacio original (A1:AD168). No truncar silenciosamente registros.
7. Sustituir/limpiar **datos históricos sensibles** de `CONSUMOS`, `CONSUMOS2`, `PERSONAL`, `BASE TRU`, `JUSTIFICACIONES` y cualquier otra hoja o caché que almacene registros anteriores. No distribuir el archivo original con nombres/DNIs reales incrustados en el IPA ni en el repositorio.
8. Retener únicamente catálogos y elementos auxiliares apropiados, y reconstruir las vistas derivadas que deban reflejar el período. `PERSONAL` deberá rellenarse únicamente con el padrón actual autorizado para la exportación (si es necesario para las fórmulas), nunca copiar el padrón histórico de la plantilla.
9. Invalidar/reconstruir la caché de la tabla dinámica y marcar recálculo/refresco al abrir en Excel; no permitir que una vista o un gráfico muestre cifras antiguas aunque `CONSUMOS` esté actualizado.
10. No inventar datos ausentes ni saldos que no puedan conciliarse. Validar fechas, codificación, unidades, cantidad física, turno/responsable y referencias de fórmulas.
11. La exportación del **libro ambulatorio** es independiente del Excel del **Kardex diario de Enfermería**: deben coexistir como dos archivos/funciones distintas.
12. Ejecutarse **localmente en iPhone**, sin enviar datos de personas a servidores; abrir hoja de compartir nativa iOS para guardar/enviar XLSX a Archivos, correo o WhatsApp.
13. La plantilla puede seleccionarse desde Archivos del iPhone y trabajarse en memoria; antes de incorporarla al proyecto como recurso, debe pasar un proceso de sanitización/verificación de privacidad.
14. Si las funciones avanzadas (tablas dinámicas, vínculos, fórmulas) no se pueden preservar con garantías, avisar explícitamente y permitir `Solo CONSUMOS`, sin afirmar que el libro completo es idéntico.

## Pruebas obligatorias de aceptación
- Conserva **las 15 hojas y sus nombres/orden**, con estructura compatible y sin errores de reparación al abrir en Microsoft Excel y Apple Numbers (según soporte).
- Caso con cero atenciones, una atención, varias atenciones con productos múltiples, y más de 167 filas de CONSUMOS.
- Código y cantidad de cada producto correctos, frecuencia por día, fechas y horas Excel correctas, códigos y unidades verificados.
- Fórmulas, tablas y referencias funcionales; revisión de caché pivot y cálculos derivados, sin números antiguos.
- No aparecen nombres, DNI, diagnósticos ni historiales antiguos del XLSX plantilla ni otros períodos fuera de la selección. Probar búsqueda en XML interno, hojas ocultas y cachés de tablas dinámicas.
- Exportación no cambia ni elimina datos originales en el iPhone; repetir una exportación produce resultados coherentes sin descontar stock.
- Compartir XLSX usando Share Sheet nativo de iOS y abrir archivo exportado en Excel, incluyendo formatos y estilos.
- Pruebas automáticas de lógica y estructura OOXML en GitHub Actions antes de compilar IPA; validación manual con archivo generado.

## Estado
**Requisito documentado. NO está implementada todavía la exportación del libro completo.** El trabajo técnico y las pruebas deberán desarrollarse en una entrega posterior, tomando como base la versión principal validada. No hacer afirmaciones de compatibilidad o ausencia de datos personales hasta verificar el archivo exportado.
