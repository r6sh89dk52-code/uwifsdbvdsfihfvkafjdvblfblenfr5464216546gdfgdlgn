# DANPER Salud Móvil — informe de continuación98c0dab

HEAD inicial real de la auditoría90cb0aba7b553e536c9d3ad42d65eae9f7890fd5; entrada de esta continuación67c4ec8d8d7a382471945e88a59f3e499a11f555; candidato98c0dab7f7e8138b799062d5aefc894bcafefd9e. Se conservaron los avances posteriores al antiguo cc45aa2 citado en el prompt. PR10 en borrador, base Build14 estable9b1da6d4cdead4729bcade6843abcbcfc287e870; sin merge ni instalación en iPhone.

## Estado actual, sin certificación anticipada

Swift433PASS/0FAIL/0omitidas, JavaScript62PASS, Python22PASS, compatibilidad1PASS y comparaciones oficiales Excel PASS para98c0dab. Benchmarks v1 trece operaciones y v2 doce, ambos completos. Release ARM64 PASS en41465269363, identidad y22 archivos verificados contra manifiesto. Xcode SwiftUI y27 nativas PASS, sin fallos/omitidas. UI13 y gate final están pendientes. No hay IPA. No se presenta ningún resultado de67c4ec8 como aprobación de98c0dab.

La ejecución41461695918 terminó FAILURE: contiene los cuatro jobs Linux aprobados del candidato. Su native-build se canceló sin runner ni pasos tras15min en cola; UI/Instruments/final quedaron omitidos. Release41461827215 y exportación41461991137 también terminaron FAILURE, con sus trabajos cancelados sin runner ni pasos. Las anotaciones públicas de GitHub consultadas después confirmaron limitación de capacidad de runners macOS ARM64 y un error interno al adquirir la máquina; no llegó a ejecutar Xcode. La API usada no detallaba ese motivo. Fallback41465269363 usa una rama auxiliar creada desde98c0dab y checkouts explícitos del mismo98c0dab: macos-15-intel, Xcode16.4/SDK18.5, iPhone16/iOS18.5, todas las suites originales, Release iPhoneOS arm64. Su gate verifica SHA/recuentos/cero fallos de cada artefacto y los cuatro jobs Linux aprobados; no sustituye pruebas por resultados antiguos. Simulador x86_64 no equivale a iPhone ARM64 físico.

## Cambios publicados y preservados

|Commit|Resultado|
|---|---|
|4079122|Índice de fragmentos en memoria para buscar9.648 trabajadores, conservando orden/Unicode/subcadena completa y paginación.|
|69e75ad|Aislamiento de Instruments y consultas XCTest; preparación de autenticación posteriormente corregida.|
|911e49e|Suscripción diagnóstica antes de observar lanzamiento del sistema.|
|9143997|Una carga de contexto para consumos y catálogo directo sin reconstruir el padrón al registrar lotes/asociaciones.|
|c274140|Presupuesto global de simulador y UDID propio en Instruments, manteniendo plazos de aserciones.|
|bdc27f1|Informes completos ligados a los mismos bytes compartidos en borradores, consumos, respaldo y Excel v2; tres regresiones nuevas y rechazo de cadena falsificada.|
|df10938|Comprobación de geometría antes de tocar selectores y ejecución ARM64.|
|e909ca6|Benchmark físico v2 obligatorio con9.648 trabajadores/1.005 atenciones/ingreso/salida.|
|6f74d66|Dos fixtures nuevas usan el prefijo temporal sintético permitido, sin relajar unsafeLocation.|
|67c4ec8|LocalAuthentication administra su escena; se retira calentamiento externo de CoreAuthUI, manteniendo sensor/ACK/política/aserciones.|
|98c0dab|El arnés cierra/comprueba el teclado antes de buscar botones ocultos mientras se escribe; recuperación única del fallo previo de instalación Cocoa4097/helper, con tres regresiones de clasificación.|

El último commit cambia pruebas/infraestructura/documentación. No cambia App, Sources ni project.yml respecto a67c4ec8. La orquestación auxiliar f03227ba mantiene fuente98c0dab y diferencia SHA del workflow de SHA de la aplicación. Se conservan las optimizaciones anteriores a90cb0ab; no se atribuyen como descubrimientos nuevos de esta continuación.

## Módulos, causas y controles

Se revisaron56 archivos Swift de App y414 sitios estáticos de acciones/llamadas. El mapa estático no significa ejecución de todas las combinaciones de botones.

|Módulo|Coste/defecto y corrección mantenida|
|---|---|
|Inicio/sesión/navegación|Recuperaciones dobles para revisión/contadores y refrescos simultáneos: una proyección autenticada, refresco excluyente, limpieza de sesión al bloquear/segundo plano y FaceID conservado.|
|Atención y alergias|Reauditorías y reconstrucción de9.648 personas tras guardar: prueba semántica inmutable de bytes exactos, actualización local de una alergia y confirmación real de persistencia. Error de refresco posterior no se muestra como guardado fallido.|
|Autosave/borradores|Consulta completa previa a cada escritura y carreras: revisión optimista/reintento acotado solo ante conflicto, etapa capturada con formulario, omitir escrituras idénticas, reprogramar tras alergias.|
|Trabajadores|Filtrado/normalización repetida por render: índice de sesión, consulta diferida, vacío sin texto,25 filas/página, cinco sugerencias, DNI exacto indexado; altas/corrección/historial conservados.|
|Historial/rectificaciones|Auditorías y recorridos cuadráticos de incidencias: proyección autenticada e incidencias indexadas, editar una fila sin modificar movimientos físicos ni duplicar visitas.|
|Kardex/inventario|Doble reconstrucción al revisar consumos; catálogo estático cargaba trabajadores/lotes; auditorías repetidas v2: una lectura validada y catálogo directo, sin cambiar corte9–8, saldos, ingresos ni R1/R0.|
|Indicador10hojas|Filtro aceptaba sede vacía, doble cadena verificada y escritura en MainActor: sede histórica explícita por atención, proyección compartida y archivo protegido por actor. La sede laboral actual nunca verifica automáticamente la histórica.|
|Excel enfermeras/vigilancia|Validaciones repetidas y escritura en interfaz: lectura comprobada compartida y escritura protegida fuera de MainActor, preservando98 productos/fórmulas/saldos desconocidos.|
|Respaldo/restauración|I/O grande en MainActor y auditoría repetida: actor de archivos, validaciones completas compartidas para mismos bytes, acceso security-scoped sostenido y escritura atómica/protección completa conservados.|
|Catálogos/diagnósticos/procedimientos/vencimientos|Se conservan búsqueda, catálogos revisados y alertas clínicas; no se elimina validación de alergias para acelerar. La revisión estática no se declara como medición de cada selector.|

## Rendimiento medido del candidato

Core/Linux x86_64, Swift6.0.3 Release, misma máquina dentro de cada par,9.648 trabajadores y1.005 atenciones ficticias. V2 c274140→98c0dab usa el mismo ciclo de sesión en ambos lados, conteo70+ingreso10−salida2=78. Conserva el estado físico completo en todas las escrituras de ambas implementaciones. Son tiempos del núcleo, no latencias del iPhone ni de SwiftUI. p50 en ms; n3/7 no permite un p95 fiable. Búsquedas n100 incluyen p95 en JSON.

|Acción Core v2|Antes ms|Después ms|Reducción|n|
|---|---:|---:|---:|---:|
|allergy_confirmed_encrypted_save|5591.297|3518.533|37.07%|7|
|draft_confirmed_encrypted_save|9664.154|3814.594|60.53%|7|
|form_prepare_9648|267.488|278.101|-3.97%|7|
|history_read_1005|160.746|161.923|-0.73%|7|
|dashboard_refresh|108.260|110.854|-2.40%|7|
|correction_editor_load|58.645|58.689|-0.08%|3|
|dispensing_readonly_refresh|4848.933|388.146|92.00%|3|
|inventory_catalog_only|1.834|1.921|-4.75%|3|
|worker_search_last|0.209|0.206|1.55%|100|
|worker_search_common|9.062|9.048|0.16%|100|
|nursing_98_export|10358.680|8005.572|22.72%|3|
|encrypted_backup_verified|20224.983|16178.179|20.01%|3|

Las cifras negativas son empeoramientos observados; no se presentan como optimizaciones ni se atribuyen al host sin demostrarlo. El índice del último trabajador mantiene el resultado correcto incluso al final del padrón. La prueba Core no representa renderizar9.648 filas: la interfaz conserva búsqueda vacía/paginada.

Recursos de todo el workload preparado, excluido compilador; no memoria física de la app iPhone:

|Recurso|Antes|Después|
|---|---:|---:|
|user_cpu_s|301.06|203.19|
|system_cpu_s|1.59|1.38|
|wall_s|302.28|204.26|
|peak_rss_kib|222632|224532|

Comparación acumulada v1 cc45aa2→98c0dab: incluye cambios ya publicados antes de90cb0ab y distinto ciclo de diario por llamada frente a sesión. No se atribuye íntegramente a los once commits listados. El fixture v1 no acredita existencias físicas v2. El indicador no se mide en el fixture v2 porque no se inventa sede/validación histórica para forzar la exportación.

|Acción Core v1|Antes ms|Después ms|Reducción|
|---|---:|---:|---:|
|allergy_confirmed_encrypted_save|15828.494|3862.311|75.60%|
|draft_confirmed_encrypted_save|17930.969|3860.983|78.47%|
|form_prepare_9648|2637.353|273.838|89.62%|
|history_read_1005|8389.430|161.076|98.08%|
|dashboard_refresh|4890.234|107.228|97.81%|
|correction_editor_load|16898.340|57.300|99.66%|
|dispensing_readonly_refresh|10191.215|385.882|96.21%|
|inventory_catalog_only|2565.682|1.837|99.93%|
|worker_search_last|22.754|0.213|99.06%|
|worker_search_common|22.746|9.422|58.58%|
|nursing_98_export|5326.529|2917.902|45.22%|
|indicator_10_sheets_export|11283.899|823.623|92.70%|
|encrypted_backup_verified|15497.445|13385.352|13.63%|

## Datos, Excel y compatibilidad

La prueba usa el código real congelado de Build14 para producir diario/respaldo cifrados completamente ficticios. El candidato los abre, corrige una apertura histórica R1→R0, guarda alergias, reabre el diario y verifica un respaldo nuevo. Stock completo, trabajadores y atenciones originales permanecen idénticos; sin duplicar consumo ni descontar historial. PASS1/0 para98c0dab. Es compatibilidad hacia delante, no promesa de downgrade.

Comparaciones oficiales: indicador10hojas/19tablas/432materiales y todas sus fórmulas; enfermeras98filas/7columnas con celdas combinadas/impresión/fórmulas; interoperabilidad XLSX A–AD en modos stock/frecuencia. PASS del SHA actual. Regresiones Swift cubren saldos desconocidos, primer conteo posterior, corte9–8, R1/R0 sin segunda salida y sede histórica pendiente/rectificada, respaldos/correcciones y revisión concurrente. Los casos nativos de concurrencia están aprobados para este SHA; faltan las pruebas UI.

Cifrado AES-GCM/AAD, HMAC, SHA, Keychain y revisión se comprueban en cada recuperación. La caché semántica interna requiere bytes descifrados exactamente iguales, máximo dos entradas de8MiB; no persiste índices sensibles en texto plano. Las modificaciones generan pruebas completas propias. No se cambian esquema v2, codec, servicios Keychain, BundleID ni grupos compartidos.

## Fallos preservados, perfilado y límites

67c4ec8: ejecución41389072346 FAILURE;433Swift/27nativas/62JS/19Python/Excel/compatibilidad/benchmarks PASS, UI11PASS/1FAIL/1no ejecutado. R se detuvo buscando Siguiente con teclado abierto; biometría no llegó a XCTest por instalador4097/helper. Corregido en el arnés98c0dab, pendiente de validar UI. Los fallos e909ca6 de dos fixtures unsafeLocation se corrigieron en6f74d66 y ya pasaron dentro de433 pruebas completas. Crash SwiftPM139 anterior ocurrió antes de tests; causa exacta no demostrada, no se convierte en PASS.

Perfilado activo anterior67c4ec8: ejecución41390330778, dos recorridos de alergias PASS, TimeProfiler6907 filas ponderadas/6923 muestras y8618 eventos runloop. Peso de muestras corriendo6907ms/5794ms hilo principal; son estimaciones de muestreo, no CPU exacta. Cuatro marcadores potenciales de bloqueo294,768–511,092ms; no se declara ausencia de bloqueos ni se atribuye causa sin prueba suficiente. Primera/última muestra0,610/22,511s; terminó al salir el proceso. No contiene pareja de signposts Confirmed allergy save: latencia exacta de guardado UI No medido. La exportación41465406523 pasó técnicamente pero confirmó que la traza Allocations no contiene tablas de asignaciones: cuantificación No medido, no cero. Dataset UI de dos trabajadores, sin comparación UI antes/después; no certifica98c0dab.

No se accedió a datos del iPhone ni se ejecutó una instalación física. FaceID/contenedor/Keychain reales tras firma iLoader y latencia física: No medido. El workload no representa todos los tamaños posibles de historial/movimientos ni todas las combinaciones de414 sitios. No se fuerza una validación incremental por campo para reducir el coste restante: exige demostrar conservación de todos los invariantes del diario y puede comprometer compatibilidad. Se conserva la alternativa segura de sesiones autenticadas/actores y validación completa compartida.

## Distribución y actualización

IPA no generada: faltan UI/gate final actuales. Build14 instalada intacta. BundleID esperado pe.danper.saludmovil.native.iloaderpreview, versión0.4.2/build15/iOS17. La coincidencia de identificador no certifica conservación del contenedor al cambiar de firma.

Antes de cualquier actualización aprobada: respaldo cifrado reciente verificado y contraseña conservados fuera del iPhone; misma cuenta/equipo de firma que la app instalada; instalar sobre la app existente, sin desinstalar, borrar bóveda, restaurar ni reimportar historial automáticamente. Detenerse si iLoader propone otra identidad/segunda app o si aparece una fuente vacía inesperada. Verificar tras actualizar trabajadores, atenciones, alergias, conteos/ingresos/consumos, borradores y saldo compartido Fundo/Planta antes de trabajar.

## Workflows y evidencias

- [Linux actual, macOS cancelado](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41461695918)
- [Xcode/UI/Release auxiliar del mismo98c0dab](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41465269363)
- [Release ARM sin runner, cancelado](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41461827215)
- [Exportación ARM sin runner, cancelada](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41461991137)
- [Exportación real de Allocations anterior, sin métricas](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41465406523)
- [Último67c4ec8 fallido](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41389072346)
- [Perfilado activo67c4ec8](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41390330778)

[Swift actual](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41461695918/artifacts/13150950105), [JavaScript/Python](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41461695918/artifacts/13150131224), [v1/compatibilidad](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41461695918/artifacts/13150314678), [v2/estado físico](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41461695918/artifacts/13149598246).

Diagnóstico auxiliar de arranque:41470753089 FAILURE de validación del workflow (runner.temp en contexto job-env, cero trabajos/tests ejecutados). Corregido en48be5391;41471227122 está pendiente y no reemplaza ninguna prueba clínica. La validación nativa real41465269363 terminó27/27PASS; sus resultados están en artifact13155085864, binarios de prueba del mismo98c0dab en13155115868. El tiempo prolongado de la etapa anterior al preflight no se presenta como latencia de la aplicación.
