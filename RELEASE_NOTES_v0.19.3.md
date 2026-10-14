# DANPER Salud Móvil v0.19.3 — verificación de respaldo independiente

Incidente en iPhone: tras crear un respaldo, al seleccionar el archivo para comprobarlo la aplicación pide la contraseña, sin mostrar una casilla independiente en esa sección. En v0.19.2 la comprobación reutilizaba la primera contraseña destinada a crear un nuevo respaldo.

Corrección: sección independiente con selector de .danperbackup, casilla visible de contraseña ORIGINAL del archivo, botón explícito para comprobar, errores adyacentes y archivo elegido retenido si contraseña ausente o incorrecta. Se permite seleccionar el archivo antes de ingresar la contraseña. Al autenticar el archivo muestra recuento de trabajadores y atenciones y borra la contraseña de comprobación en memoria. Esta opción NO restaura, fusiona, elimina ni modifica registros.

No se cambia Keychain, padrón, visitas, Kardex, reportes ni la lógica de creación del archivo cifrado. Prueba de interfaz dinámica con React simulado y contraseñas correctas/incorrectas, sin datos reales. PR borrador, sin modificar main; pruebas CI Linux/Xcode e iPhone físico obligatorias antes de recomendar actualización.

Solución temporal v0.19.2: escribir la contraseña original en la PRIMERA casilla «Contraseña del respaldo», luego volver a la sección «Comprobar» y seleccionar el archivo. No subir archivos de trabajadores o contraseñas a GitHub.
