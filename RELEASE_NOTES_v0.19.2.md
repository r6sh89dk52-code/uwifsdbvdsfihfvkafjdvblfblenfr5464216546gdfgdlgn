# DANPER SALUD MÓVIL v0.19.2 — corregir respaldo sin respuesta visible (Build 192)

Base: v0.19.1 / PR #28, derivada de v0.19.0 validada físicamente. No contiene migración clínica v0.20.x. No modifica Keychain, archivo cifrado de trabajadores ni estados clínicos.

## Incidente
En v0.19.1 tocar «Crear y compartir respaldo cifrado» parecía no hacer nada. El botón quedaba deshabilitado silenciosamente si contraseña de menos de 14 caracteres o las dos entradas no coincidían. El error o mensaje de éxito quedaban debajo del selector de archivo, fuera de la zona visible. El cifrado PBKDF2 y los guardados asíncronos también podían retrasar el inicio de la hoja nativa Compartir.

## Solución
1. Validación de contraseña visible y mensajes de error inmediatamente debajo del botón activo.
2. Preparación por etapas, con estado legible «leyendo / cifrando / verificando / guardando».
3. Archivo cifrado distinto en cada operación, comprobado con `Filesystem.stat` y ruta local nativa obtenida con `Filesystem.getUri`. No se escribe información clínica en texto legible.
4. Botón **separado** «Compartir / Guardar en Archivos» ejecutado por un toque directo tras la creación. Si falla Compartir, permite reintentar sin recalcular ni modificar registros.
5. Comprobar archivo .danperbackup externo con contraseña, sin restaurar ni borrar datos.
6. Pruebas: exportación cifrada con datos totalmente ficticios, corrupción, contraseñas, dos backups el mismo día, fallas de stat/URI y presencia del flujo UI.

## Puertas
- Linux CI y Xcode obligatorios; prueba física iPhone pendiente.
- Instalar sólo encima de versión anterior; no borrar ni reinstalar.
- Guardar copia externa y verificarla antes de migrar a v0.20.x. No subir bases reales o contraseñas a GitHub.
