# DANPER Salud Móvil — auditoría Build 15

Candidato: `67c4ec8d8d7a382471945e88a59f3e499a11f555`.
Entrada real de la auditoría: `90cb0aba7b553e536c9d3ad42d65eae9f7890fd5`; entrada de esta continuación: `67c4ec8d8d7a382471945e88a59f3e499a11f555`. El prompt original citaba cc45aa2; se conservaron los avances posteriores. PR #10 en borrador. Build 14 estable: `9b1da6d4cdead4729bcade6843abcbcfc287e870`.

## Cambios publicados desde la entrada real

| Commit | Cambio |
|---|---|
|4079122|Índice de fragmentos en memoria para buscar dentro del padrón, con verificación final de subcadena y pruebas de orden/Unicode/9.648 trabajadores.|
|69e75ad|Aislamiento de Instruments y consultas XCTest; preparación de autenticación posteriormente corregida.|
|911e49e|Suscripción al diagnóstico antes de lanzar interfaz de autenticación.|
|9143997|Catálogo directo en lotes/asociaciones y una carga de contexto al revisar consumos.|
|c274140|Presupuesto global de simulador y dispositivo explícito para Instruments; resultados fallidos conservados.|
|bdc27f1|Reutilización de informes completos ligados a los mismos bytes en borradores, consumos, respaldo y Excel enfermeras v2; tres regresiones nuevas y rechazo de cadena falsificada.|
|df10938|Toques de contenido fuera del pie fijo y Xcode/UI sobre ARM64.|
|e909ca6|Comparación obligatoria v2 con existencias físicas y 12 operaciones.|
|6f74d66|Dos fixtures nuevas usan el espacio temporal sintético permitido, sin reducir unsafeLocation.|
|67c4ec8|LocalAuthentication administra CoreAuthUI; se retira calentamiento externo que bloqueaba la preparación, conservando sensor/ACK/política/aserciones.|

## Alcance

El mapa estático comprende 56 archivos Swift y 414 sitios de acciones/llamadas. Se revisaron inicio/sesión/navegación, atención y pasos, alergias/autosave/borradores, Personal, historial/correcciones, inventario/Kardex, indicador de diez hojas, Excel enfermeras y vigilancia, respaldo/restauración y catálogos. El mapa no significa que se hayan ejecutado todas las combinaciones de botones. AUDIT.md documenta componentes, causas, cambios y controles por módulo.

Los cambios anteriores al inicio real se mantienen: sesión autenticada, caché semántica interna de bytes exactos, índices por DNI, búsquedas diferidas/paginadas, contadores desde una lectura, historial sin recorridos cuadráticos, proyecciones y archivos fuera de MainActor y rectificación explícita de sede histórica. No se atribuyen como descubrimientos nuevos de esta continuación.

## Estado de validación

Resultado definitivo de67c4ec8: ejecución41389072346 FAILURE. Swift433/433, nativas27/27, JavaScript62/62, Python19/19, compatibilidad1/1, trece operaciones v1 y doce v2 aprobadas. UI11PASS/1FAIL/1no ejecutado: el recorrido R buscó Siguiente con teclado abierto; biometría no llegó a XCTest por fallo del instalador NSCocoaErrorDomain4097/helper. No se reinterpretan como pruebas aprobadas.

Corrección posterior publicada en98c0dab7f7e8138b799062d5aefc894bcafefd9e: cerrar/comprobar teclado antes de buscar botones y reconocer exclusivamente ese fallo previo de instalación para un único reinicio del simulador sintético propio.22 Python locales PASS. Ejecución41461695918 repite todo para98c0dab; sus resultados están pendientes y no se certifica con este informe de67c4ec8. Build14 instalada sigue intacta; IPA bloqueada.

Compilación Release iPhoneOS ARM64 actual: ejecución41389127133 SUCCESS. Su SOURCE_SHA y RELEASE_IDENTITY apuntan al candidato; se verificaron localmente los 22 archivos contra APP_SHA256.json. Bundle ID `pe.danper.saludmovil.native.iloaderpreview`, versión0.4.2/build15, iOS17, sin firma, sin dataset clínico ni reloj de pruebas. No es IPA.

## Integridad y actualización

No se borraron bóvedas ni inventarios ni se accedió a datos del iPhone. No se cambia esquema v2, codec, servicios Keychain, Bundle ID ni grupos. La prueba de compatibilidad usa el código congelado de Build14 para producir diario/respaldo cifrados ficticios y comprueba lectura, rectificación R, alergias, reapertura, stock completo/trabajadores/atenciones originales idénticos y nuevo respaldo verificado. Su resultado del candidato debe consultarse, no inferirse de ejecuciones previas.

La identidad de Bundle ID es necesaria para actualizar; la conservación del contenedor/Keychain depende además de la firma real que aplique iLoader. No está certificada físicamente. Mantener un respaldo cifrado verificado de Build14 y su contraseña fuera del iPhone, misma cuenta/equipo de firma, actualizar sobre la app existente y no desinstalarla. Detenerse si iLoader propone otra identidad o una segunda app. No restaurar ni reimportar automáticamente el historial ya presente.

## Límites

Las mediciones Core/Linux no son latencias de iPhone. Las muestras 3/7 no sustentan p95 fiable; las búsquedas usan100. CPU/RSS del proceso de prueba no equivalen a CPU/asignaciones de SwiftUI. Instruments fallido se informa No medido. No se declara cero consumo a partir de tablas vacías. La carga representa9.648 trabajadores/1.005 atenciones y movimientos ficticios concretos; no demuestra rendimiento con cualquier volumen.

La auditoría no se considera cerrada si quedan UI o métricas obligatorias sin resolver. No generar IPA con comprobaciones obligatorias fallidas.

## Rendimiento del candidato medido

Comparación v2 c274140→67c4ec8, Swift6.0.3 Release/Linux x86_64, mismo runner/harness/datos/ciclo de sesión.9.648 trabajadores/1.005 atenciones; conteo70+ingreso10−salida2=78. Estado físico completo idéntico en todas las escrituras de ambas implementaciones. Tres/siete muestras lentas, cien búsquedas; p50 en ms. Cada valor conserva sus muestras y máximo en JSON. No son latencias físicas ni de SwiftUI.

|Acción Core v2|Antes ms|Después ms|Reducción|Muestras|
|---|---:|---:|---:|---:|
|allergy_confirmed_encrypted_save|5673.730|3774.202|33.48%|7|
|draft_confirmed_encrypted_save|9773.356|3891.450|60.18%|7|
|form_prepare_9648|262.329|286.035|-9.04%|7|
|history_read_1005|154.816|166.743|-7.70%|7|
|dashboard_refresh|102.037|109.978|-7.78%|7|
|correction_editor_load|56.330|60.813|-7.96%|3|
|dispensing_readonly_refresh|4793.535|400.386|91.65%|3|
|inventory_catalog_only|1.813|1.842|-1.56%|3|
|worker_search_last|0.215|0.215|-0.10%|100|
|worker_search_common|9.388|10.093|-7.50%|100|
|nursing_98_export|10362.002|8238.958|20.49%|3|
|encrypted_backup_verified|20742.313|16693.385|19.52%|3|

Las reducciones negativas son empeoramientos observados, no mejoras. No se aísla una causa de CPU/host por inferencia; las rutas sin ganancia no se marcan optimizadas. Las búsquedas siguen verificando el resultado correcto y el límite de filas. Ninguna cifra de una pasada aislada fija una garantía de latencia en iPhone. El indicador de diez hojas no se mide con el fixture v2 porque no se inventa sede/validación histórica para forzar su exportación. Su benchmark v1 y las comparaciones oficiales completas sí se ejecutan.

Recursos de todo el workload Core/XCTest preparado (excluye compilador, no memoria del iPhone):

|Recurso|Antes|Después|
|---|---:|---:|
|user_cpu_s|304.84|210.94|
|system_cpu_s|1.36|2.11|
|wall_s|305.9|212.75|
|peak_rss_kib|222952|223296|

Comparación acumulada v1 cc45aa2→67c4ec8: incluye optimizaciones ya publicadas antes de90cb0ab; no se atribuye íntegramente a esta continuación. Mismo runner, fixture v1 sin saldo físico v2.

|Acción Core v1|Antes ms|Después ms|Reducción|
|---|---:|---:|---:|
|allergy_confirmed_encrypted_save|8744.830|2225.579|74.55%|
|draft_confirmed_encrypted_save|10111.056|2288.570|77.37%|
|form_prepare_9648|1473.963|172.951|88.27%|
|history_read_1005|4647.792|97.769|97.90%|
|dashboard_refresh|2683.291|69.248|97.42%|
|correction_editor_load|9370.421|41.977|99.55%|
|dispensing_readonly_refresh|5605.387|265.256|95.27%|
|inventory_catalog_only|1412.040|1.021|99.93%|
|worker_search_last|11.825|0.127|98.92%|
|worker_search_common|12.243|5.616|54.13%|
|nursing_98_export|2953.079|1723.601|41.63%|
|indicator_10_sheets_export|6346.708|520.321|91.80%|
|encrypted_backup_verified|8834.497|7577.001|14.23%|

Artifacts actuales: v1/compatibilidad13117191634; v2/estado físico13117296756, ambos en ejecución41389072346.

## Enlaces verificables

- [Validación completa actual](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41389072346)
- [Release ARM64 actual, sin IPA](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41389127133)
- [Perfilado activo actual, diagnóstico](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41390330778)
- [Diagnóstico natural previo, no certifica candidato](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41388727286)
- [Regresiones de fixture previas, no certifican candidato](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41388149441)

## Perfilado activo de67c4ec8

Ejecución41390330778/artifact13117703641: ambos recorridos reales de guardar/reabrir alergias PASS con dos trabajadores ficticios. TimeProfiler6907 filas ponderadas; peso de muestras corriendo6907ms,5794ms en hilo principal. Son estimaciones por muestreo, no contabilidad exacta de CPU; no sumar pesos inclusivos de funciones. Cuatro marcadores de pausa potencial:502,074/511,092/506,208/294,768ms. No se declara ausencia de bloqueos ni se atribuye su causa sin análisis suficiente. Primera/última muestra0,610/22,511s: la salida del proceso terminó la captura antes del plazo nominal180s. El intervalo no contiene una pareja de signposts Confirmed allergy save: latencia exacta del guardado UI No medido. Allocations grabó pero agotó el plazo al exportar; cuantificación de asignaciones No medido, pendiente diagnóstico41461991137 sobre la misma traza. No es comparación UI antes/después ni medición física.
