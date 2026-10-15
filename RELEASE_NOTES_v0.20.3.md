# DANPER Salud Móvil v0.20.3 — Bloqueo nativo del acceso y privacidad iOS

Base: v0.20.2 / PR #31. No cambia identificador del paquete iOS, base clínica cifrada, padrón, atenciones, inventario ni plantillas oficiales.

## Acceso nativo
Se instala un overlay OPACO UIKit al iniciar WKWebView, cuando la ventana aparece y cuando la app pasa a segundo plano. Al regresar exige autenticación nativa del propietario de iPhone mediante LocalAuthentication (Face ID/Touch ID con código del dispositivo como alternativa). Sólo se quita la pantalla tras una respuesta de autenticación afirmativa de iOS en estado activo. Si se cancela o falla, conserva el bloqueo y permite reintento; si falta un código de desbloqueo, se mantiene cerrada y avisa que debe configurarse. Esto cubre visualmente el cambiador de aplicaciones y evita exposición casual de pantalla.

No se introduce una contraseña propia ni se almacena dato biométrico en DANPER. Info.plist incluye motivo NSFaceIDUsageDescription durante la compilación. Se mantiene el identificador anterior a fin de conservar el contenedor iOS al actualizar SIN desinstalar.

## Pruebas
- `scripts/test-native-access-lock.cjs` inspecciona la inyección Swift, idempotencia, apertura/reanudación/fondo, fallback código, fallo/cancelación y la clave Face ID en el IPA.
- macOS/Xcode debe compilar la extensión AppDelegate real. Falta comprobar Face ID y retorno desde segundo plano con iPhone físico.
- Copias y migración: preserva todas las salvaguardas de v0.20.2; resta por probar restauración completa del respaldo con dos contenedores o dispositivos.
- PR permanece draft, main intacta, sin archivos personales ni datos clínicos identificables en GitHub.
- PENDIENTE para operación clínica: dispositivo de prueba vacío, revisión de seguridad, retención/caducidad de snapshots, políticas de acceso y autorización organizacional.
