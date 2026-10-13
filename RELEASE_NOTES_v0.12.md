# DANPER Salud Móvil v0.12 — Entrega confirmada Atención ↔ Kardex

Continuación de v0.11 verificada por el usuario. **Solo información ficticia**.

## Función principal
- Desde Inicio → Kardex se puede seleccionar una **atención guardada**, uno de sus medicamentos/insumos, un producto y lote físico del Kardex, y la cantidad física a entregar.
- Antes de descontar, se exige confirmar expresamente identidad/presentación, equivalencia de unidades y que la entrega ocurrió.
- **No se hacen equivalencias por nombres parecidos**. El código de atención es distinto del identificador del catálogo Kardex, por lo que el operador debe verificar ambos.
- Se reutiliza el motor de stock v0.11: bloquea lotes vencidos, stock insuficiente y requiere confirmación de apertura. Conserva regla R=1 al abrir envase, R=0 en usos posteriores.
- El movimiento auditado incluye identificadores de atención y artículo clínico, códigos y cantidades del registro original, lote usado, fecha y delta físico.
- Un producto de una atención solo puede tener una entrega ligada; el segundo intento queda bloqueado aunque se haya vuelto a abrir la pantalla.
- La atención puede guardarse sin entrega: el descuento **no es automático** y no cambia el registro clínico. Correcciones posteriores requieren trazabilidad adicional (no doble descuento).
- Los vínculos están dentro del mismo histórico de movimientos existente en Keychain. El esquema anterior sigue siendo legible.
- No existe todavía exportación oficial Excel, compensación por devolución ni conciliación automática entre catálogos. No uso con datos clínicos reales.

## Pruebas de aceptación
1. Crear un registro ficticio con medicamento y guardarlo.
2. Abrir Kardex → Entrega vinculada; elegir atención y artículo.
3. Seleccionar un lote ficticio no vencido; confirmar su identidad/presentación y cantidad física.
4. Confirmar entrega, comprobar descuento y movimiento con vínculo.
5. Intentar repetir la entrega; debe bloquearse.
6. Verificar R=1 al abrir y R=0 en siguientes usos del envase.
7. Cerrar y reabrir la app; los saldos y vínculos deben persistir.
8. Comprobar rechazo de atención en borrador, lote vencido y unidades dudosas (sin las confirmaciones obligatorias).
