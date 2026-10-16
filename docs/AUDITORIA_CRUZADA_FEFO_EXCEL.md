# DANPER v0.21.10+ — Auditoría cruzada FEFO → CONSUMOS y Kardex

## Alcance
Auditoría reproducible únicamente con datos sintéticos sobre PR #57 (base PR #56 y release v0.21.10 build 220).
No utiliza datos reales de trabajadores, DNI clínicos ni archivos del iPhone; no cambia existencias existentes.
Archivo ejecutable: `scripts/test-fefo-cross-report-audit.cjs`, incluido en `npm run test:logic`.
Se generan en memoria los **dos XLSX reales** desde sus plantillas integradas, se descomprimen y se comprueban sus celdas y fórmulas (no solamente el estado JavaScript).

## Escenario de prueba
- Dos sedes oficiales: LA VENTUROSA y PLVENTUROSA, mismo Kardex físico compartido.
- Cuatro atenciones independientes, con horario explícito y material ficticio.
- Producto individual E-22 / material clínico 16000182:
  - Lote que vence primero: 2 UND.
  - Lote siguiente: 8 UND.
  - Caja sellada posterior: 20 UND internas, **contabilizadas en unidades y no como 1 caja**.
  - Primera atención: 5 UND → FEFO 2+3, CONSUMOS R=5.
  - Otra atención: 12 UND → FEFO 5+7, CONSUMOS R=12.
  - Kardex del día: D=30, G=17, H=13.
- Producto por caja E-57 / material clínico 16000013:
  - Lote más antiguo: 1 unidad interna abierta.
  - Siguiente lote: 1 caja sellada de 100 unidades internas.
  - Primera atención: 2 unidades internas → apertura por partes, cantidades físicas 1+1, R=0+1=1.
  - Segunda atención: 1 unidad interna del envase previamente abierto, R=0.
  - Kardex diario: D=1 caja cerrada, G=1 apertura, H=0 cajas cerradas; consumo físico interno adicional no se cuenta como otra caja.
- Una atención sintética adicional con requerimiento superior al stock físico verifica que el sistema no descuenta parcialmente ni inventa un saldo: Excel PROVISIONAL con R en blanco en esa línea.
- Prueba independiente de fracción: 0,50 de contenido interno distribuido en 0,25+0,25, con R=0+1=1, sin confundir mililitros con envases.

## Criterios de aprobación
1. Identidad y orden FEFO basados en vencimiento local de Perú, excluyendo lotes vencidos y agotados.
2. N movimientos físicos pueden proceder de **un solo artículo clínico**, con identificadores `ATT:...:PART:n`, `partCount` y `physicalTotal`; un grupo truncado, duplicado o alterado debe ser rechazado en lectura y restauración.
3. La exportación del Indicador contiene exactamente **10 hojas**, **una fila CONSUMOS por medicamento/atención**, los dos códigos organizativos de sede y R conforme a las cantidades oficiales auditadas.
4. El Kardex integrado utiliza la hoja **KARDEX ENFERMERAS** con **98 productos**, importes D/G/H idénticos a las salidas auditadas, y conserva las fórmulas **F=D+E** y **H=F-G**.
5. **Catálogo oficial UND/TBL/PAR**: si el producto está físicamente guardado en una caja, el Kardex contabiliza el contenido individual, no una unidad de caja.
6. **U.M. oficial CJA/FCO/PAQ**: reporta apertura de envase (1), uso continuado del abierto (0), manteniendo el control físico interno.
7. Exportación y planificación son de solo lectura, no reponen stock, no fabrican movimientos históricos ni recalculan un saldo inicial ausente.

## Correcciones derivadas de la auditoría
- `src/dailyKardex.ts`: usar la unidad oficial del material para clasificar saldos, no únicamente la forma física del recipiente.
- `src/ambulatoryRows.ts`: verificar un grupo multilote completo y después reconstruir cada movimiento físico individual sin invalidar el grupo; admite cantidades fraccionarias de contenido interno.
- `src/kardexMovements.ts`: no permitir grupos FEFO incompletos desde la API pública, conservar el total físico por atención y detectar inconsistencias incluso con contenido fraccionario.
- `scripts/test-daily-kardex.cjs`: corregir una antigua simulación de envase que usaba U.M. UND mientras esperaba resultados en frascos FCO.

## Lo que NO queda validado aún
- Exactitud de los **Excel exportados desde el iPhone con información real o anonimizada**. La auditoría es de integración sintética sobre código fuente y plantillas reales.
- Restauración real de una copia cifrada en un dispositivo o instalación vacía.
- Superación segura de límites de 1.000 movimientos, 500 lotes y 1.200 eventos de conciliación.
- Sustitución de la build220 instalada: PR#57 sigue en borrador y **no se ha generado IPA**.
- Cualquier presentación/volumen que no tenga conversión física interna validada: en ese caso la salida permanece pendiente, nunca se inventan movimientos.

## Conclusión condicionada
Solo cuando la última validación Linux del PR #57 termine PASS podrá declararse APROBADA la **concordancia sintética de los dos Excel**; eso no habilita operación clínica de producción ni reemplaza las pruebas físicas.
