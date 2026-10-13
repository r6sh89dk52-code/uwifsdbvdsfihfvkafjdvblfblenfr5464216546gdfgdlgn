# DANPER Salud Móvil v0.11.0 — Etapa B1: movimientos y aperturas

## Continúa la v0.10.1
Conserva las atenciones, el catálogo oficial de 98 + 6 donados, el inventario físico por lote, los gestos nativos y el almacenamiento Keychain.

## Funcionalidades nuevas

1. **Ingresos extraordinarios** de envases cerrados o cantidades sueltas, por producto y lote.
2. **Salidas físicas** de una cantidad registrada manualmente; nunca se permite stock insuficiente o uso de lote vencido.
3. **Apertura confirmada:** para caja, frasco, paquete o blíster, se conserva el contenido restante del único envase abierto; el primer movimiento registra **R=1** para el futuro Excel CONSUMOS, mientras los usos posteriores del mismo envase registran **R=0**. Si se agota, hay que confirmar la apertura del siguiente envase en un movimiento distinto.
4. **Unidades individuales:** el movimiento registra la cantidad de unidades efectivamente entregadas.
5. **FEFO sugerido:** al elegir un producto con varios lotes muestra preferentemente el no vencido más próximo a vencer. No fuerza ni sustituye el criterio profesional.
6. **Ajustes auditados:** incluyen motivo y saldos antes/después; lotes con historial no admiten edición ni eliminación directa.
7. **Trazabilidad y reintentos:** cada movimiento lleva un identificador único, fecha, motivo, cambios físicos, cantidad de futura columna R y fotografías del saldo previo/posterior. Reintentar exactamente el mismo identificador no duplica el movimiento. La continuidad histórica se verifica antes de nuevos movimientos.
8. **Persistencia:** inventario e historial de movimientos se guardan juntos en el mismo snapshot de prueba de Keychain o en localStorage del navegador de desarrollo; migración desde v0.10.1 con historial inicialmente vacío, sin borrar atenciones.

## Límites explícitos
- **No** hay aún descuento automático al guardar una atención: requiere mapeo seguro producto clínico ↔ catálogo Kardex oficial y conciliación de cantidades y unidades.
- Las cantidades **R=0/1** son de la lógica interna, no se genera todavía el Excel oficial, ni se envía WhatsApp o correo.
- **No se manejan envases abiertos simultáneamente del mismo lote.** Solo un abierto, los demás cerrados. Para registrar varios abiertos hace falta una evolución del modelo.
- No hay SQLCipher, backup y restauración de historiales ni auditoría de producción: **solo datos ficticios**.

## Validación de iPhone
1. Comprobar que el inventario inicial ficticio de v0.10.1 permanece.
2. Registrar ingreso extraordinario de dos frascos de 120 mL, comprobar +240 mL.
3. Con envase cerrado y sin abierto, registrar salida de 10 mL: debe solicitar apertura explícita.
4. Confirmar apertura: 10 mL físicos, R=1; otro uso de 5 mL: R=0 y resta 105 mL en el envase.
5. Consumir exactamente los 105 mL y confirmar nueva apertura para un uso posterior: R=1.
6. Probar rechazo de lote vencido y de cantidad mayor que el contenido disponible.
7. Registrar un ajuste con motivo; comprobar historial, saldos anterior/posterior y bloqueo de edición directa.
8. Cerrar y volver a abrir la aplicación para comprobar persistencia y gestos.

CI: `npm run test:logic` incluye pruebas automáticas para todos los casos principales y PR valida TypeScript/Vite en Linux antes de la compilación IPA macOS.
