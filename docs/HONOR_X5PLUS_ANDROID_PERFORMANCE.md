# DANPER Build 222 — rendimiento HONOR X5 Plus (Android, revisión experimental)

## Punto de partida (datos aportados por prueba física)
- El APK DEBUG original se compiló correctamente y completó 8/8 pruebas funcionales iniciales con datos ficticios.
- El usuario percibió **pequeños retrasos**; todavía **no hay cifras medidas de FPS, jank, tiempos de búsqueda ni memoria**.
- La versión original validada en el teléfono es la rama `feat/android-build222-local-apk-20261020`, commit `ca69ce316d258f4ca0dfb0db5e92d4bb3b0cfae5` y el APK DEBUG de fecha 20/10/2026. Conservar APK anterior para comparación si es posible.

## Cambios experimentales de esta rama
1. La búsqueda de trabajadores usa `workerSearchIndex.ts`: precalcula nombres normalizados una vez por cambio de padrón, filtra solo si la pantalla Trabajadores está abierta, detiene el recorrido después de 25 coincidencias y permite búsqueda por DNI sin cambiar su orden.
2. Un `Map` resuelve el DNI ya registrado al escribirlo en el formulario clínico. No cambia verificaciones de DNI, padrón oficial ni el guardado.
3. Historial renderiza 60 tarjetas al abrirse; el botón **Mostrar 60 atenciones más** da acceso al resto. No se elimina, limita, archiva ni modifica ninguna atención, movimiento, medicación o dato. La fecha y el orden siguen siendo los de Build 222.
4. Etiquetas de conciliación del historial utilizan un índice de `dispenseRef` de movimientos solo de lectura; no altera FEFO ni publica consumos.
5. Prueba `scripts/test-android-performance.cjs` compara búsqueda nueva contra la original usando 10 000 registros ficticios. Los tiempos que muestra son del Mac, NO del teléfono.

## Compilar SIN GitHub Actions
Este trabajo vive en una rama aparte. Para probar la versión experimental desde la carpeta actual del Mac, **conserva el APK original y un respaldo cifrado con datos ficticios**. Si `git status --short` muestra modificaciones versionadas, no hagas switch sin guardarlas. El directorio `android/` generado no está versionado; `git switch` no requiere borrarlo.

    cd ~/danper-salud-movil-pruebas
    git status --short
    git fetch origin feat/android-honor-x5plus-performance-20261020
    git switch --track origin/feat/android-honor-x5plus-performance-20261020
    bash scripts/build-android-apk-macos.command

El archivo sigue llamándose `outputs/android/DANPER-Build222-Android-DEBUG.apk` y el script lo sobrescribe. Para conservar una copia previa, primero:

    cp outputs/android/DANPER-Build222-Android-DEBUG.apk "$HOME/Desktop/DANPER-Build222-Android-ANTES-PERF.apk"

No desinstales la app antes de instalar el APK nuevo: desinstalar elimina el almacenamiento local. Para una actualización in situ, el paquete debe mantener el mismo `appId` y la misma firma debug del Mac; comprueba la firma si Android rechaza actualizar. Respaldo cifrado verificado y datos ficticios solamente.

## Evaluación en HONOR X5 Plus
Comparar versión original y experimental con **el mismo padrón y el mismo número de atenciones ficticias** (por ejemplo, 10 000 trabajadores; una base clínica ficticia pequeña primero, luego 500–1500 atenciones ficticias donde ya existan herramientas de generación de prueba seguras). **No importar bases laborales reales.**

- Arranque: abrir tras cerrar por completo y anotar segundos de arranque (5 repeticiones).
- Trabajadores: escribir búsqueda acentuada (Álvarez), un DNI exacto y una búsqueda sin resultados; comprobar las 25 primeras coincidencias y respuesta del teclado.
- Historial: abrir, desplazar 60 tarjetas y pulsar Mostrar 60 más; comprobar que una atención antigua y sus consumos siguen accesibles.
- Atenciones: crear borrador, editarlo, cerrar, reabrir, finalizar una atención con consumo de prueba y comprobar un único movimiento FEFO, Kardex y Excel.
- Cifrado: salir/volver a abrir, exportar respaldo, restaurarlo **solo en una base de prueba vacía**. Revisar que un error de contraseña no cambie la base.

## Opcional — perfilado Android con adb (si está instalado)
Con la depuración USB habilitada y el HONOR autorizado en el Mac:

    adb devices
    adb shell dumpsys meminfo pe.danper.saludmovil.prototipo
    adb shell dumpsys gfxinfo pe.danper.saludmovil.prototipo reset

Después de navegar entre trabajadores e historial:

    adb shell dumpsys gfxinfo pe.danper.saludmovil.prototipo

`gfxinfo` puede reportar solo el hilo de renderizado nativo y **no cuantifica por sí solo todas las pausas de JavaScript/WebView**. Cronometrar manualmente con vídeo o trazas Android Studio para comparar latencia visible. Nunca recopilar logcat de datos clínicos reales.

## Criterio de aceptación
El único resultado aceptable es **mismas funciones y datos, sin regresiones, con retrasos iguales o menores**. Si no mejora o hay regresiones, reinstalar el APK anterior **sin borrar los datos** (siempre que appId/firma sean compatibles), o volver a la rama original para generar su APK.

No declarar fluidez garantizada: sin mediciones en el HONOR X5 Plus eso sería una afirmación no sustentada.
