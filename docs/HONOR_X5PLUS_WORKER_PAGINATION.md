# Android HONOR X5 Plus — paginación de trabajadores e importación en Ajustes

Rama: `feat/android-worker-pages-settings-20261021`.
Base: rama HONOR performance validada por el usuario en el dispositivo. Solo modificaciones de presentación y navegación.

## Cambios

- Pantalla **Trabajadores**: conserva registrar/editar/buscar; deja de mostrar el importador Excel.
- **Ajustes → Importar padrón desde Excel**: conserva exactamente las operaciones de importación, conciliación, activación del padrón oficial y el guardado cifrado existente. La recuperación de emergencia del padrón cifrado permanece en su pantalla de recuperación.
- El listado de trabajadores usa **25 fichas por página**, con botones **Anterior** y **Siguiente** y contador `Página N de M`. En el teléfono, al pulsar una flecha, la pantalla vuelve automáticamente al inicio del bloque **Buscar por DNI o nombre**; no abre el teclado por sí sola.
- El buscador consulta **todo** el padrón visible, aunque haya 10 000 o más personas, no solamente la página actual. Cualquier edición del texto de búsqueda empieza de nuevo en la página 1.
- Se muestran intervalos `Mostrando 26–50 de 10 000 trabajadores`; nunca confundir "25 visibles" con "25 existentes".
- Un cambio en el padrón que reduce el total corrige la página actual al último valor válido sin mostrar resultados fantasma.
- Los registros, atenciones, movimientos de Kardex, auditorías, FEFO, claves y copias de respaldo no cambian.

## Compilar en tu Mac sin GitHub Actions

La APK anterior debe conservarse, igual que un respaldo cifrado verificado de datos **ficticios**. No desinstalar la aplicación ni borrar sus datos para actualizarla.

    cd ~/danper-salud-movil-pruebas
    git status --short
    mkdir -p "$HOME/Desktop/DANPER-APKs"
    cp outputs/android/DANPER-Build222-Android-DEBUG.apk "$HOME/Desktop/DANPER-APKs/DANPER-HONOR-ANTES-PAGINACION.apk"
    git fetch origin feat/android-worker-pages-settings-20261021
    git switch --track origin/feat/android-worker-pages-settings-20261021
    bash scripts/build-android-apk-macos.command

El builder existente ejecuta las pruebas clínicas y de inventario, la prueba de búsqueda/paginación con 10 000 ficticios, compilación TS/Vite, sincronización Capacitor y Gradle. La ruta de salida sigue siendo `outputs/android/DANPER-Build222-Android-DEBUG.apk`. Si aparecen cambios locales **versionados**, resolver antes de `git switch`; `?? android/` es la carpeta nativa local ya generada y no debe borrarse.

## Prueba manual en HONOR X5 Plus

1. Abrir **Trabajadores** con 10 000 personas ficticias. Ver `Mostrando 1–25 de 10 000` y `Página 1 de 400`.
2. Bajar al final y pulsar **Siguiente**: debe mostrar 26–50 y desplazarse de nuevo al buscador. Pulsar **Anterior**: debe mostrar 1–25 y volver al buscador.
3. Avanzar hasta página 3 y buscar un DNI de una página posterior; debe aparecer en página 1 del resultado filtrado. Comprobar tildes en nombres.
4. Ir a **Ajustes**: debe estar allí `Importar padrón desde Excel` y no en Trabajadores. Importar el mismo Excel ficticio: no se deben duplicar DNIs. Verificar persistencia tras cerrar/reabrir.
5. Registrar una atención ficticia y verificar consumo FEFO, Kardex y exportación Excel. Eliminar solamente datos simulados, y solo mediante operaciones auditadas que la interfaz permita.

No declarar versión apta para datos reales hasta auditar seguridad Android y funcionalidad nativa.
