# DANPER Salud Móvil v0.20.1 (iOS build 201) — respaldo cifrado portátil

**Etapa experimental: no instalar todavía sobre un dispositivo con el padrón real.**

- Copia portátil con contraseña de 14 a 200 caracteres, PBKDF2-HMAC-SHA256 con 310000 iteraciones y AES-256-GCM autenticado. Contiene padrón, atenciones, alergias, inventario, movimientos y conciliaciones.
- Exportar desde Ajustes → Respaldo y recuperación con iOS Share Sheet. Debe verificarse que el archivo quede guardado **fuera del dispositivo**. Ni contraseñas ni padrones reales se suben a GitHub.
- Importar respaldo .danperbackup: descifrado, autenticación y validación ANTES de modificar la base; no se permite si existen trabajadores, atenciones, inventario u otros registros.
- Recuperación de dos almacenes: las generaciones cifradas de trabajadores y clínico se escriben y verifican; luego journal de referencias en Keychain y cambio de punteros. El siguiente arranque puede reanudar una restauración interrumpida.
- Prohibido mezclar o reemplazar padrones existentes automáticamente. La depuración del padrón ficticio mezclado con el real es otra función pendiente.
- Pruebas con datos ficticios para contraseña equivocada, alteración, downgrade de PBKDF2 e interrupción del proceso. Requiere PASS Linux y Xcode.
- NO está implementado Face ID/bloqueo propio y aún falta la prueba física de restauración entre dispositivos; no es producción.
