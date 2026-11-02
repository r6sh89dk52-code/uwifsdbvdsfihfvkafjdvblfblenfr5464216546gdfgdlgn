# Auditoría integral Build 15 — alcance, controles y evidencias

Inicio: `cc45aa27013922a68301be01eaa1f1a16ad9e910`, PR #10. Base estable Build 14: `9b1da6d4cdead4729bcade6843abcbcfc287e870`. Trabajo exclusivo en `fix/indicator-historical-visit-site-build15-20261030`.

## Estado de validación

Este documento describe cambios y cómo se comprueban; **no certifica una ejecución pendiente**. El workflow B15 genera `FINAL_GATES.json` únicamente cuando las pruebas del SHA actual terminan sin fallos. Los resultados antiguos se usan solo para diagnóstico, comparación de rendimiento y producción de entradas cifradas de compatibilidad; no certifican el nuevo HEAD.

La entrega incluye un inventario estático de los 56 archivos Swift de App y de sus botones, selectores, rutas y llamadas detectadas: `action-inventory.json`. Un inventario estático no equivale a pulsar cada combinación posible ni a medirla. Las rutas diagnósticas/laboratorio se identifican aparte del trabajo clínico cotidiano; se conservan.

## Recorridos y hallazgos

| Módulo | Acciones revisadas | Coste o defecto encontrado | Cambio y control |
|---|---|---|---|
| Inicio, sesión y navegación | Abrir, desbloquear, pestañas, contadores, segundo plano | Dos recuperaciones para revisión y contadores; tareas simultáneas de refresco | Revisión/contadores desde un mismo registro autenticado; refresco excluyente; ocultación clínica y Face ID conservados |
| Atención y alergias | Abrir formulario, seleccionar persona, revisar, guardar, pasar pasos | Auditorías repetidas de exactamente los mismos bytes; carrera con autosave; construir padrón después de una escritura | Prueba inmutable interna tras ambas auditorías; confirmación de persistencia real; actualización COW de una alergia; errores de guardado separados del refresco visual |
| Borradores | Debounce, cambio de paso, cerrar, recuperar, confirmar | Consulta completa de revisión antes de cada escritura; guardados idénticos; cancelación de alergias podía dejar el borrador pendiente | Escritura optimista con un reintento solo ante conflicto real; etapa capturada junto al formulario; no reescribir estado idéntico; reprogramación tras fallo de alergias |
| Personal | DNI, nombre, directorio, alta y ficha laboral | Filtrado con comparación de locale durante cada render/paginación | Índices normalizados en memoria; búsqueda diferida fuera del hilo principal; lista vacía sin consulta; 25 filas por página y cinco sugerencias; DNI exacto por diccionario |
| Historial | Buscar, paginar, detalle, rectificar, volver | Auditorías completas ya disponibles; recorrido de incidencias por cada visita; reconstruir padrón al abrir la edición | Proyección autenticada interna con firmas de rectificación verificadas; incidencias indexadas por visita; edición preparada desde una sola revisión; actualización de una fila de historial conservando consumos físicos |
| Kardex e inventario | Consolidado, 98 productos, filtros, ingresos/conteos, R 1/0, cortes 9–8, movimientos | Validaciones duplicadas en operaciones del diario y sumarios; trabajo de incidencias cuadrático en historial v2 | Pruebas semánticas ligadas a bytes exactos; sumarios reutilizan resultados autenticados; sin cambios al cálculo físico, redondeos, movimientos, cierres ni secuencia de consumos |
| Indicador de diez hojas | Período, ambas sedes, selección, sede pendiente, generar/compartir | Un filtro Fundo aceptaba sede vacía; verificar dos veces la misma cadena; escritura del archivo en MainActor | Sede histórica explícita; nunca copiar automáticamente la ficha laboral; proyección compartida; ruta interna autenticada; archivo protegido escrito por actor separado |
| Excel enfermeras y vigilancia | Rangos, filtros, generar, compartir | Escrituras de XLSX en el hilo de interfaz; coste compartido de la bóveda | Escrituras protegidas fuera de MainActor; fórmulas, 98 productos, saldos desconocidos y formatos conservados; comparaciones oficiales TS/Swift |
| Respaldos, importación y restauración | Autenticar, leer, verificar, cifrar, compartir, restaurar | Lecturas/escrituras grandes en MainActor; validaciones repetidas en fuente ya autenticada | I/O en actor dedicado, acceso security-scoped durante toda la lectura, límite 42 MB, archivos regulares sin symlinks, protección completa y escritura atómica conservados |
| Catálogos, diagnósticos, procedimientos y vencimientos | Elegir, buscar, validar, agregar tratamientos | Riesgo de trabajo dentro de `body`; reglas clínicas y validaciones no deben reducirse | Se conservan los catálogos revisados, búsqueda de productos y alertas clínicas. Los cambios comunes de bóveda no alteran su contabilidad; regresiones funcionales existentes siguen obligatorias |

La importación inicial, la admisión de un respaldo externo y la verificación de una generación distinta continúan realizando auditorías completas. No se sustituyen por una comprobación de tamaño, fecha de archivo o número de revisión.

## Límite de confianza de las optimizaciones

- `N2AuditedSnapshot` es interno e inmutable: construirlo exige las dos auditorías completas. No existe un inicializador que acepte informes arbitrarios.
- El diario lee el archivo y comprueba recibo HMAC, AES-GCM/AAD y SHA en **cada** recuperación. Solo reutiliza auditorías semánticas si los bytes descifrados son exactamente iguales a bytes ya auditados.
- Dos entradas como máximo, de hasta 8 MiB cada una, por diario; ninguna se escribe en texto plano. Las fuentes mayores mantienen el recorrido completo.
- Cada actor mantiene su propia sesión clínica o ficticia, comprueba Keychain en cada llamada y descarta la sesión al bloquearse, ir a segundo plano o fallar Keychain. Un cambio de clave crea otra sesión.
- Las firmas y la secuencia de la cadena de rectificaciones se verifican también en los recorridos autenticados. Una modificación efectiva de datos no recibe automáticamente la prueba de los bytes originales.
- Escrituras y revisiones permanecen serializadas por sus actores; se prueban 16 solicitudes concurrentes con la misma revisión, una aceptada y quince rechazadas como obsoletas.
- No se cambia Bundle ID, grupos compartidos, claves/servicios Keychain, formato del diario, esquema v2 ni codec del respaldo. Solo el número de compilación candidato avanza a 15. No se instala en el iPhone real.

## Mediciones reproducibles

`scripts/performance/run-core.sh` ejecuta un mismo harness sobre el HEAD inicial y el actual. Datos fabricados: 9.648 trabajadores, 1.005 atenciones iniciales, stock/lotes/movimientos originales ficticios y borrador. Compilación SwiftPM Release en Linux x86_64; no son tiempos de iPhone ni de SwiftUI.

Se conservan todas las muestras. Operaciones lentas: siete muestras (o tres en Excel, edición y respaldo), mediana y máximo; no se inventa p95 con tres/siete muestras. Búsquedas: cien muestras y p50/p95. Se declara el ciclo de vida de cada implementación: el adaptador inicial creaba un diario por llamada; el optimizado mantiene el diario autenticado durante la sesión. La preparación inicial en frío no se representa como reapertura caliente.

La tabla final procede del artefacto `B15_PERFORMANCE_COMPARISON/comparison.json`. CPU/memoria de la navegación se miden además con XCTest en Simulator; `profile-simulator.py` intenta registrar Time Profiler y Allocations y guarda el resultado real de cada herramienta. Si no puede capturar una métrica, se informa **No medido**, nunca cero ni aprobado por inferencia. No se afirma una mejora en el iPhone físico sin medirlo.

## Pruebas y compatibilidad

1. Todas las pruebas Swift actuales, sin filtro, y comparaciones Excel oficiales.
2. 50 regresiones JavaScript y 12 controles adicionales.
3. Xcode real sobre el candidato y todas las pruebas nativas, incluyendo concurrencia; Face ID real inscrito en simuladores propios.
4. Todas las suites UI descubiertas, incluyendo guardar alergias/reabrir, búsqueda vacía, paginación y métricas del formulario. Los binarios se comparten solo dentro de la ejecución del **mismo HEAD**, con hashes de cada archivo y permisos preservados en tar. No se reutiliza un binario de otro SHA.
5. Archivos cifrados producidos por el código original Build 14 se abren y editan en el candidato; stock, trabajadores y atenciones originales deben permanecer iguales. Se verifica respaldo Build 14 y nuevo round trip. Es compatibilidad hacia delante; no una promesa de que Build 14 entienda campos nuevos de rectificación de Build 15.
6. Los fallos reales y las cancelaciones anteriores quedan en GitHub y en `previous-linux-failures.json`.

## Pendientes y distribución

No hay IPA de Build 15 autorizada por este documento. La versión instalada Build 14 permanece intacta. Se debe revisar el resultado completo de la ejecución actual, las métricas y cualquier limitación de Instruments antes de evaluar distribución.

La firma iLoader y la conservación del contenedor en una actualización física no pueden certificarse con Simulator. Conservar el respaldo original de Build 14 y la misma identidad de firma; no desinstalar la app que contiene los datos reales. No se ha accedido a datos del iPhone durante estas pruebas.


## Continuación desde el HEAD real 90cb0ab — 1 de noviembre

La solicitud volvió a citar cc45aa2, pero la rama ya contenía toda la auditoría anterior. Se conservan los cambios. El workflow 41173716294 terminó FAILURE: 428 Swift, 27 nativas, ambos Excel, 62 controles JS, 15 Python, benchmark de once operaciones y compatibilidad Build 14 pasaron; UI 9 PASS y 4 FAIL. Ninguna cifra anterior certifica un candidato nuevo.

Diagnóstico de los fallos actuales:
- Los dos casos de autenticación no observaron el sensor porque CoreAuthUI terminó su arranque después del watchdog de 5 s de coreauthd: código -1000 y `UI activation timed out`. No fue un ACK falso ni una autenticación exitosa. Se prepara el ejecutable del servicio antes de solicitar la política, se observa su arranque real y se retira su escena independiente. La espera real del sensor y todos los eventos/aserciones de los casos permanecen obligatorios.
- El caso de alergias seguía en Inicio después de tocar Nueva atención. Se elimina la captura de Instruments concurrente con esa prueba funcional y se exige que el formulario esté presente antes de buscar sus controles. Se conserva la regresión de persistencia y de alergia modificada sin confirmar.
- El recorrido R1/R0 consumió diez minutos con consultas XCTest redundantes. Los botones ya visibles usan su hit point real sin múltiples lecturas de geometría y pie de página. La entrada de texto conserva el control de posición/foco. Se mantienen stock, R1/R0, relanzamiento, historial y el límite de 600 s.
- Instruments no había llegado a obtener PID: la consulta `simctl spawn launchctl list` agotaba su propio timeout. Se selecciona el proceso host por ruta del simulador propio (con cuatro regresiones de aislamiento), se adjunta por PID y se ejecuta en un job separado. El alcance de esa captura es Inicio ficticio, no todas las acciones ni el iPhone físico. Si falla, queda No medido.

Optimización productiva adicional: `N2SearchIndex` pasa de recorrer todas las filas normalizadas a elegir la lista de candidatos del fragmento de dos caracteres menos frecuente y verificar la subcadena completa. Conserva orden, acentos/anchura, límites y búsqueda por DNI/nombre. El índice sigue siendo un valor de sesión en memoria. Dos regresiones Swift comprueban equivalencia, Unicode, falsos candidatos, paginación y el último registro de 9.648. El benchmark repite el harness original e informa además el coste inicial de construcción; ese coste no se confunde con latencia de consulta. No se declara una mejora hasta leer la medición nueva. CPU y RSS del workload se vuelven a medir para mostrar el coste de memoria del índice.

El job de UI se serializa para reducir contención de CI. Esto no cambia la aplicación, los tiempos límite, las pruebas ni su verificador de evidencia. El job de Instruments conserva su SHA y binarios del mismo HEAD. La versión instalada y el PR en borrador permanecen intactos; no se genera IPA mientras falten controles.


Se hallaron además dos rutas secundarias de producción no cubiertas por la optimización previa: revisar consumos sin reintento reconstruía dos veces el contexto completo; registrar lote auxiliar y confirmar asociación operativa obtenían el catálogo estático reconstruyendo también trabajadores, alergias y lotes. La revisión usa una sola carga de contexto; al reintentar usa la revisión autenticada, y las dos transacciones auxiliares cargan el mismo catálogo revisado directamente. Sus validaciones y commits cifrados permanecen en el núcleo existente. El harness incorpora `dispensing_readonly_refresh` e `inventory_catalog_only` (tres muestras cada una); el gate final exige ahora trece operaciones comparadas. No se afirma una mejora cuantitativa antes de revisar sus muestras. El tiempo de construir el índice se conserva además en el JSON bruto, separado de la búsqueda caliente.


## Presupuesto de CI y selección de Instruments

En `9143997`, Xcode/27 nativas, 430 Swift, JS62/Python19, los dos Excel y las trece operaciones medidas pasaron. Las dos pruebas de alergias y su verificador pasaron, pero GitHub concluyó su job CANCELLED al llegar a 30 minutos globales; no se presenta como un job verde. La preparación/preflight del simulador consumió la mayor parte de ese presupuesto. Se amplía exclusivamente el job UI a 45 minutos y se restauran cuatro runners independientes; el timeout XCTest de 600 s y las esperas del sensor no cambian. Instruments recibe 35 minutos globales de preparación/captura.

El proceso de Inicio ficticio fue observado, pero xctrace sin selección de dispositivo no encontró el PID (salida 21). El arnés vuelve a especificar el UDID del simulador propio al adjuntarse por PID. La nueva ejecución debe confirmar si permite capturar: el cambio de parámetros por sí solo no demuestra una captura ni mide acciones clínicas.

El benchmark previo compara de forma acumulada cc45aa2 frente a 9143997, no aísla las mejoras nuevas frente al HEAD real de entrada 90cb0ab. En el artefacto de 9143997, guardar alergias cifradas pasó de p50 9831,402 a 2349,057 ms (7 muestras Linux Release), búsqueda del último trabajador de 12,192 a 0,126 ms (100), formulario Core de 1616,834 a 209,665 ms (7). Son cifras del núcleo con datos ficticios, no latencia física de iPhone. La medición XCTest UI de cinco ciclos abrir/cerrar formulario tuvo media 5,803 s y CPU 3,011 s, memoria física máxima media 55.810,458 kB; incluye automatización y solo dos trabajadores sintéticos. No tiene línea base UI ni equivale al tiempo del botón Guardar alergias. Los contadores de ciclos/instrucciones cero del simulador se consideran No medido.

Este commit de infraestructura cambia el HEAD: las evidencias de 9143997 quedan como antecedentes y se requieren comprobaciones frescas para el candidato siguiente. PR en borrador, sin IPA y sin cambios a Build 14 instalada.

## Hallazgo adicional medido: inventario físico v2 con padrón completo

La carga adicional de c274140 (`41369582547`, artefacto `13108563610`) usa 9.648 trabajadores, 1.005 atenciones ficticias e inventario v2: conteo 70, ingreso 10 y salida 2, saldo 78. Conservó el estado físico completo tras todas las escrituras, pero midió p50 de 3.491,715 ms en alergias, 6.136,331 ms en borradores, 3.033,512 ms al revisar consumos y 6.416,381 ms en Excel enfermeras. Son cifras Linux Release, no iPhone. El indicador no se mide en ese arnés v2 porque no se inventa validación histórica para forzar su exportación; su corrección sigue siendo obligatoria en la suite completa.

Se encontraron duplicaciones verificables en código: la auditoría de paridad v2 ya ejecutaba N1fLosslessFieldGate, pero N2AuditedSnapshot y el codec de respaldo la repetían; el borrador devolvía bytes tras auditar y perdía su prueba antes del commit; dispensingLines volvía a auditar dos veces la generación autenticada; Kardex/corte releían la misma instantánea para extraer sus rectificaciones.

La corrección comparte los dos informes completos generados dentro de una misma llamada que solo acepta bytes. No se permite inyectar informes de confianza. El borrador entrega su prueba inmutable al diario y confirma revisión y bytes después de escribir. Las líneas de consumo usan los informes de esa recuperación autenticada, y la lectura de stock/rectificaciones valida una sola vez conservando la verificación de la cadena de correcciones. No cambia formato, cifrado, HMAC, lecturas de archivo, clave, control de revisión, movimientos ni valores del Excel.

Se agregan tres regresiones: equivalencia de informes/rechazo de campos, balances y esquemas inválidos; borrador cifrado reabierto con etapa y stock/atenciones originales conservados, rechazo de revisión obsoleta; líneas v2 equivalentes a la auditoría completa sin modificar generación. El caso de rectificación R añade rechazo de una cadena falsificada. El workflow final incorpora una comparación v2 obligatoria c274140→candidato con igual ciclo de sesión, doce operaciones, ingreso/salida y saldo 78 inalterado en ambos lados. Los beneficios nuevos no se cuantifican antes de leer esa ejecución.

La ejecución c274140 `41366450170` terminó FAILURE: 430 Swift, 27 nativas, JS62/Python19, ambos Excel y compatibilidad Build14 pasaron; UI 7 PASS, 3 FAIL y 3 no ejecutadas por cancelación del shard Glass. CoreAuthUI volvió a exceder su watchdog de 5 s incluso en el reintento posterior a una cancelación real. El toque de Tipo de atención del recorrido R apuntó a y=838 detrás del pie fijo: ser hittable no probó visibilidad útil. Se exige geometría de contenido también en botones, manteniendo los controles fijos identificados y todas las aserciones clínicas. El nuevo CI utiliza `macos-15` ARM64 (documentado por GitHub), registra y exige su arquitectura, conserva Xcode16.4, iPhone16 y los plazos XCTest/sensor. Esto es una corrección del entorno y del arnés; no se declara Face ID aprobado hasta obtener el nuevo resultado.

La compilación Release ARM64 de c274140 `41370048064` pasó las comprobaciones de Bundle ID, Build15, iOS17, recursos sin datasets clínicos y ausencia de firma; no generó IPA y no certifica el código posterior. El diagnóstico activo `41368239478` aprobó el recorrido ficticio bajo ambas plantillas, pero sus capturas agotaron el plazo: métricas Instruments No medido. Se distingue ahora explícitamente el timeout de observación de proceso, grabación y exportación. Ninguna de estas evidencias anteriores sustituye las pruebas del nuevo HEAD.


La ejecución e909ca6 registró 433 pruebas Swift: 431 PASS y dos fixtures nuevas bloqueadas por unsafeLocation al usar un prefijo temporal no permitido. Se corrigen únicamente sus rutas al espacio danper-n2-synthetic-; la protección no se relaja. Las cuatro pruebas v2 del candidato 6f74d66 pasaron en 41388149441. Xcode/27 nativas y Release ARM64 de e909ca6 pasaron. La comparación v2 en el mismo runner midió alergias4506,975→2927,991ms (35,0%), borrador7634,421→3008,924ms (60,6%), consumos3739,349→329,005ms (91,2%), Excel enfermeras8018,742→6377,904ms (20,5%) y respaldo15905,101→13143,116ms (17,4%), con saldo78 y estado físico completo idénticos. Son antecedentes medidos; se repetirán sobre el HEAD posterior.

El shard biométrico ARM64 no llegó a XCTest: la preparación externa de CoreAuthUI esperaba un stream vacío y terminó con Authentication diagnostic stream did not start. Se retira el lanzamiento/terminación manual de esa escena privada; LocalAuthentication administra su ciclo de vida. Se mantienen la inscripción real del simulador, el log del sensor durante los tests, los ACK por generación y todas las aserciones/plazos. El diagnóstico separado 41388727286 usa binarios e909ca6 con el diff del arnés explícito; no certifica el nuevo HEAD. La aprobación exige otra ejecución completa del SHA definitivo. No IPA.
