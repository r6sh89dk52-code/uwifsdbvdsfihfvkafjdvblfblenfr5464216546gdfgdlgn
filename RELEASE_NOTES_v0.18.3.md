# DANPER Salud Móvil v0.18.3 — Fix carpeta privada existente (iOS build 183)

## Incidente visto en iPhone
Tras confirmar la recuperación con padrón vacío (v0.18.2), la siguiente importación de PERSONAL dispara:
`Directory at '.../Documents/danper/private/' already exists, cannot be overwritten.`
El API Filesystem.mkdir de iOS puede fallar incluso con `recursive:true` si la carpeta ya existe.

## Correcciones
- Verificación mediante `Filesystem.stat` antes de ejecutar `mkdir`. Se crea solo si falta; tras carrera concurrente se acepta solo si `stat` demuestra que es un directorio. Nunca se elimina o sobrescribe una carpeta/archivo existente.
- Se conserva Keychain, el archivo cifrado activo y la referencia a versiones previas. Errores de carpeta/permisos se notifican sin sustituir datos.
- `PersonalImporter` ya espera confirmación asíncrona de `onApply`; el formulario normal de Trabajadores ahora **espera** `writeDemoSnapshot` para persistir y verificar Keychain+archivo cifrado antes de declarar la importación exitosa.
- Prohibido incorporar PADRÓN PERSONAL real en GitHub o IPA.
- Regresión: primera creación, segundo guardado en carpeta existente, recuperación con padrón vacío seguida de importación de 9635 trabajadores ficticios, reimportación y fallo deliberado cuando la ruta existente no es directorio.

## Pruebas pendientes
- Linux CI y macOS/Xcode obligatorios; iPhone SideStore sin desinstalar; confirmar importación, reinicio y persistencia. Hasta prueba física, evitar datos reales e impedir cualquier opción «Limpiar datos».
