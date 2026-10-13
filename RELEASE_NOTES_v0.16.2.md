# DANPER Salud Móvil v0.16.2 — mapeos verificados para atenciones

Fuente: `DANPER_Tabla_Correspondencias_Kardex_Indicador_104x432(1).xlsx` editada por el usuario y confirmaciones posteriores.

- El Kardex de Enfermería tiene **98** productos operativos. Los seis donados siguen excluidos desde v0.16.1.
- Se aprobaron **86 parejas Kardex↔Indicador Ambulatorio**; se corresponden con **85 códigos clínicos distintos**, porque dos llaves del Kardex comparten el código `16024400`.
- `E-62 LLAVE 3 VIAS CON EXTENSION` y `E-63 LLAVE 3 VIAS SIN EXTENSION` están **ambas** aprobadas para la asociación con `16024400` tras revisión explícita del usuario. Son existencias distintas: la enfermería debe escoger el lote verdadero, sin selección ni descuento automáticos.
- `E-68 NYLON AZUL 3/0` **NO** está asociado. Tampoco los 11 productos sin código candidato. Siguen visibles en Kardex, pero no pueden relacionarse con consumos de atención.
- No se alteran los nombres originales, saldos ni movimientos existentes. La tabla de 432 códigos y el libro original de diez hojas no cambian.
- Los datos de antiguas correspondencias manuales se conservan como historial pero no pueden autorizar entregas ajenas a esta lista validada.
- Entrega voluntaria y confirmada; se bloquean productos no autorizados, lotes incorrectos, stock insuficiente, doble entrega e incompatibilidad de unidades. Esta versión se utiliza únicamente con datos de prueba.

## Pruebas obligatorias
`npm run test:logic`, `npm run build`, `npm run ios:check`, auditoría npm y CI macOS/Xcode. Prueba explícita E-62 y E-63 con lotes distintos; E-68 y donados rechazados. Validación real de SideStore e impresión Microsoft Excel pendientes hasta comprobación física.
