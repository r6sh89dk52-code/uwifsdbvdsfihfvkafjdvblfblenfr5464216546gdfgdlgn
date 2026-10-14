# DANPER SALUD MÓVIL v0.18.2 / iOS build 182 — recuperación del archivo cifrado del padrón

## Incidente real de arranque
Al instalar la v0.18.1 en iPhone, Keychain conservaba la ruta 'workers-*.enc' mientras que Filesystem Directory.Data no encontraba el archivo bajo Documents/danper/private. La app anterior abortaba todo el arranque. La referencia puede sobrevivir a una reinstalación o cambio de contenedor, pero eso por sí solo NO demuestra que los datos sigan disponibles.

## Recuperación segura
- Archivo cifrado de trabajadores ausente -> MissingWorkerVaultError específica.
- El estado clínico independiente sigue legible desde el snapshot Keychain válido; **se suspenden todos los guardados automáticos** y la sincronización en segundo plano mientras el padrón esté pendiente.
- Pantalla guiada: restaurar desde Excel PERSONAL local o, sólo con confirmación, iniciar un padrón vacío. El guardado del Excel se espera y verifica antes de mostrar éxito.
- Antes de confirmar un nuevo archivo cifrado, se conserva la referencia huérfana anterior en el propio Keychain. La clave y los demás datos clínicos no se eliminan.
- Errores de corrupción, de clave o acceso denegado NO se interpretan como archivo ausente: deben bloquearse sin sobrescribir.
- El archivo anterior no se recupera por arte de magia; si no hay respaldo disponible, los trabajadores perdidos deberán importarse de nuevo.
- Sin modificación de inventario, Kardex, atenciones, borradores, FEFO, equivalencias ni Excel oficial de diez hojas. No contiene datos personales reales.

## Pruebas
- CI Linux y Xcode obligatorios; simulación de Keychain con puntero huérfano, archivo ausente, error de disco al recuperar, preservación de snapshot clínico y restauración explícita.
- Versión de prueba pendiente de verificación física en iPhone. No desinstalar la app ni borrar los datos antes de evaluar recuperación.
