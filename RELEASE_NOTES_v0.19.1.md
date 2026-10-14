# DANPER Salud Móvil v0.19.1 — respaldo cifrado antes de migrar

Puente derivado exclusivamente de la v0.19.0 (PR #26), versión que ya fue verificada físicamente en el iPhone. **No contiene la migración clínica de la v0.20 ni modifica su almacenamiento.**

- Ajustes: crear archivo `.danperbackup` del padrón, atenciones, alergias, inventario, entregas y conciliación.
- Contraseña privada de al menos 14 caracteres, PBKDF2-SHA256 310000 iteraciones y AES-256-GCM autenticado. Se entrega mediante iOS Share Sheet; nunca se almacena la contraseña en Keychain ni en GitHub.
- Exporta únicamente tras esperar a la cola de guardados seguros Keychain para evitar copias inconsistentes.
- No hay importación/restauración en esta versión puente: su único objetivo es obtener **una copia externa antes de actualizar al cifrado clínico v0.20.1**.
- No contiene trabajadores ni archivos personales reales en el código o IPA. La app requiere autorización de la organización para usar información identificable.
- CI Linux, Xcode y validación física de exportación pendientes. No desinstalar la aplicación actual ni vaciar datos.
