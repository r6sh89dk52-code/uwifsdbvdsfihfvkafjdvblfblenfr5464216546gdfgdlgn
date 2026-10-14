# DANPER Salud Móvil v0.18.0 / iOS build 180 — padrón cifrado privado (candidato)

## Sin datos reales en repositorio
- El libro real PERSONAL se analiza **fuera** del código. NO introducir nombres, DNIs, fechas de nacimiento, saldos o datos clínicos del archivo privado en GitHub ni en el IPA.
- Importación local de una hoja PERSONAL a través de Trabajadores > Importar Excel. Un alta manual actualiza el padrón local; no requiere atención.
- Verificación por DNI: duplicados, valores M/F contradictorios, códigos de sexo inválidos y ausentes. Las contradicciones quedan pendientes y no se deduce el sexo de un nombre.

## Almacenamiento por dispositivo
- Para el padrón del iPhone, archivo cifrado AES-256-GCM bajo Directory.Data; secreto de 256 bits y puntero al archivo activo en Keychain con modo sin sincronización iCloud y acceso while-unlocked/this-device-only.
- Se escribe un archivo nuevo y se prueba su descifrado antes de cambiar el puntero; en error conserva la generación anterior.
- Migración progresiva: elimina el arreglo workers del snapshot grande de Keychain solo después de verificar el archivo cifrado. Conserva las demás partes de ese snapshot para no alterar atenciones, alergias, inventario o drafts.
- El navegador sigue usando almacenamiento de pruebas no cifrado. No usarlo con datos personales.
- **No es todavía una base SQLite/SQLCipher clínica**; el resto de datos del prototipo conserva su almacenamiento anterior. No declarar cumplimiento normativo/producción hasta auditoría, controles de acceso, backups cifrados y validación en iPhone real.

## QA
- Pruebas con ~9.635 trabajadores **ficticios** encriptados y recuperación sin datos planos; errores antes de confirmar un guardado y detección de alteración/corrupción.
- CI Linux, macOS y compilación Xcode deben ser PASS antes de entregar IPA.
- PR continúa en borrador; no fusionar a main hasta ensayos en iPhone.
