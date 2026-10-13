# DANPER Salud Móvil v0.13 — Conciliación y devoluciones (prototipo)
- Verificación/revocación manual e histórica de equivalencias entre códigos de atenciones y Kardex oficial. No hay conversiones ni descuentos automáticos.
- Registro de incidencias por devolución o discrepancia vinculado al movimiento original; solo una incidencia por movimiento en esta fase.
- Devolución **NO** reintegra existencias automáticamente. Una modificación física requiere ajuste auditado independiente tras verificar condición del material.
- Persistencia del historial en snapshot compatible con Keychain de v0.12.
- Pruebas nuevas de vínculos, límites de devoluciones, duplicados, revocaciones y saldo inmutable.
- Pendiente: reconciliación más avanzada, devoluciones múltiples, flujos de cuarentena y Excel oficial; solo datos ficticios.

Prueba en iPhone: abrir Kardex, confirmar la equivalencia de un producto ficticio guardado; revocarla; seleccionar una entrega previa, registrar una incidencia y comprobar que el saldo físico NO cambie. Cerrar/abrir y verificar persistencia.
