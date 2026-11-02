# Build15 — evidencia definitiva de eeea540, candidato posterior sin certificar

Fuente medida: `eeea540c94b6023684f56598c709cd8498d9bff8`. Estado: **FAILURE; NO IPA**. El candidato posterior es `799dc5f9a2812ed01f82ed28c78eb90d0750e09f`, con [validación nueva](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41490125275) pendiente. Ninguna cifra de esta página aprueba ese candidato.

La auditoría continuó desde el HEAD real90cb0ab, conservando los cambios anteriores al prompt que citaba cc45aa2. Build14 estable9b1da6d4cdead4729bcade6843abcbcfc287e870. PR10 en borrador; sin merge ni cambios en main ni acceso al iPhone. [Mapa integral y cambios](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/blob/799dc5f9a2812ed01f82ed28c78eb90d0750e09f/docs/build15-performance/AUDIT.md).

## Pruebas de esta fuente

[41482409677](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41482409677) terminó FAILURE. Swift433PASS/0FAIL/0SKIP; JS62PASS; Python24PASS. TypeScript, ambas comparaciones de Excel oficiales, compatibilidad cifrada Build14 y benchmarks13v1/12v2 PASS. Xcode compiló SwiftUI, pero la suite native-28 no terminó:12PASS, un caso de cancelación de política bloqueado y un error adicional del runner. No se suman errores de infraestructura como casos nativos aprobados ni se consideran aprobados los15casos restantes sin completar. UI13 e Instruments no se ejecutaron por la dependencia fallida.

El xcresult registra «Stall on main thread» en N2ColdAuthenticationPreflightTests y «Test runner never began executing tests after launching». El caso agotó600s pese a un temporizador de12s y espera18s. El candidato7524c1b cambia a async fulfillment y agenda disponibilidad/evaluación/cancelación fuera del hilo principal;799dc5f añade fallo explícito de disponibilidad. Se mantienen la respuesta appCancel real, ausencia de autenticación exitosa y los casos UI completos de sensor. Esta corrección está sin validar en Xcode hasta su propio resultado. No se modificó código App/Sources, datos ni autenticación del producto.

[Release41482696816](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41482696816): intento1 compiló y verificó la app pero falló CreateArtifact por timeout; intento2 SUCCESS. [Artifact13161293805](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41482696816/artifacts/13161293805) contiene app ARM64 sin IPA. Se verificaron localmente los22archivos exactos contra APP_SHA256.json. Identidad0.4.2/build15, mismo BundleID `pe.danper.saludmovil.native.iloaderpreview`, iOS17, sin firma ni datasets clínicos ni reloj de pruebas. No certifica instalación/contenedor físico ni el SHA posterior.

## Medición v2 con existencias físicas ficticias

Baselinec274140 y fuenteeeea540 en el mismo runner Linux x86_64, SwiftPM Release;9648trabajadores y1005atenciones, ambos con diario mantenido por sesión. En cada operación se leen y autentican realmente archivos/revisión. Conteo70+ingreso10−salida2=78; ambos lados preservan el estado físico completo codificado. Son dos productos físicos de prueba y un historial mayoritariamente de observación; no equivale a probar100000movimientos ni98productos con consumo no nulo.

Medianas en ms; reducción positiva significa menor tiempo. No se infiere causalidad de variaciones pequeñas ni se atribuyen a infraestructura sin evidencia.

| Acción | Antes p50 ms | Después p50 ms | Reducción | Muestras |
|---|---:|---:|---:|---:|
| `allergy_confirmed_encrypted_save` | 4698.598 | 3050.150 | 35.08% | 7 |
| `draft_confirmed_encrypted_save` | 8042.747 | 3051.489 | 62.06% | 7 |
| `form_prepare_9648` | 205.717 | 201.789 | 1.91% | 7 |
| `history_read_1005` | 122.899 | 117.628 | 4.29% | 7 |
| `dashboard_refresh` | 82.849 | 81.690 | 1.40% | 7 |
| `correction_editor_load` | 44.960 | 44.086 | 1.94% | 3 |
| `dispensing_readonly_refresh` | 3810.756 | 289.382 | 92.41% | 3 |
| `inventory_catalog_only` | 1.428 | 1.426 | 0.17% | 3 |
| `worker_search_last` | 0.173 | 0.175 | -1.22% | 100 |
| `worker_search_common` | 7.814 | 7.886 | -0.92% | 100 |
| `nursing_98_export` | 8203.280 | 6719.023 | 18.09% | 3 |
| `encrypted_backup_verified` | 16335.221 | 13313.471 | 18.50% | 3 |

Búsquedas tienen100muestras: p95 final0.184586→0.197321ms; común7.995602→8.435083ms. En esta comparación v2 no mejoraron; no es FAIL funcional. Las operaciones con3/7muestras conservan todas las muestras y no publican p95. Archivos JSON adjuntos permiten revisar valores exactos sin redondeo.

Recursos del workload Core/XCTest preparado, compilador excluido: CPUuser245.54→167.27s; CPUsistema1.18→1.10s; wall246.65→168.26s; RSSmáxima223764→224712KiB. El tiempo bajó y la memoria máxima subió948KiB. No son medidas de CPU/memoria del iPhone ni de cada pantalla.

## Comparación acumulada v1

[Artifact v1](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41482409677/artifacts/13160849145). Baselinecc45aa2 con diario por operación frente sesión del candidato; por ello no atribuir todo el beneficio a los últimos commits. Misma escala9648/1005. Formulario2650.176→264.483ms; búsquedaúltimo21.9295→0.2120665ms (p9522.05421→0.224410); indicador10hojas11151.568→813.933ms. El JSON contiene13operaciones y todas las muestras. [Artifact v2](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41482409677/artifacts/13160468254) contiene12operaciones y prueba de estado físico completo.

## Causas y modificaciones de producción conservadas

- Recuperaciones/contextos completos repetidos para alergias, panel y revisión de consumos: sesión autenticada y proyecciones de la misma revisión; errores de persistencia diferenciados del refresco visual.
- Auditoría de campos repetida dentro de paridad v2, snapshot, diario y respaldo: compartir informes completos inmutables generados solo desde bytes; no admitir informes arbitrarios. Confirmar escritura por revisión y bytes recuperados.
- Reconstruir/filtrar9648personas por render/consulta: índice normalizado de sesión y listas de candidatos por fragmento; búsqueda diferida fuera de main, vacía sin texto,25filas/página y5sugerencias. DNIexacto por diccionario.
- Revisar consumos reconstruía dos contextos; acciones auxiliares de inventario reconstruían personal para leer un catálogo: contexto único y acceso directo al catálogo revisado.
- Historial con incidencias cuadráticas y edición recargando padrón: índices por atención y proyección autenticada que verifica la cadena de rectificación; actualizar una fila.
- XLSX/backup/restauración con I/O en MainActor: actor separado con archivo protegido, escritura atómica, acceso security-scoped durante toda lectura y límites intactos.
- Indicador Fundo aceptaba sede vacía: sede histórica confirmada explícitamente en esa atención, sin copiar automáticamente sede laboral, duplicar visita ni tocar stock.
- Autosave con trabajo/revisiones repetidos: conservar captura de etapa/formulario, no reescribir idénticos y reprogramar borrador después de fallo de alergias, sin cancelar transacciones confirmadas.

Caché solo de memoria de sesión, dos generaciones≤8MiB; cada recuperación conserva Keychain, HMAC, AEAD/AAD, SHA y archivos reales. Cambio de clave/bloqueo/background invalida sesión. Revisión distinta exige auditoría completa. Pruebas conservan16escrituras concurrentes con1aceptada/15obsoletas. No se desactiva ningún control clínico de alergias ni de integridad.

## Módulos revisados y cobertura

Inicio/FaceID/navegación/background; atención4pasos y formularios; trabajador/búsqueda/alta/ficha; alergias y borradores; medicamentos/procedimientos/diagnósticos/aperturas; inventario/Kardex/98productos/corte9–8; historial/rectificaciónR/sede; indicador10hojas; exportación/compartir; respaldo/importación/restauración; catálogos/vencimientos y rutas de laboratorio. Inventario estático56archivos SwiftApp/414sitios de acción; no equivale a pulsar todas las combinaciones ni a medir todas las pantallas. Los cambios y pruebas por módulo están en AUDIT.md.

## Build14, Excel e inventario

compatibility-eeea540.json:1PASS/0FAIL. El productor es el código original9b1da6d4, no una serialización nueva rotulada como Build14. Diario y respaldo cifrados ficticios se abrieron eneeea540; correcciónR1→R0 y guardado de alergia persistieron tras reabrir; trabajadores, atenciones originales y stock completos permanecieron iguales; nuevo backup pasó roundtrip. physicalDeviceValidated=false. No es una promesa de downgrade ni prueba de datos reales.

Ambos libros Excel Swift se compararon con las salidas originales TypeScript oficiales: indicador10hojas y enfermeras98productos. Se mantienen R0 como consumo clínico de presentación ya abierta, conteo físico y movimientos, período9–8, no inventar saldo previo y rectificación histórica sin descontar otra vez. Los tests de Core abarcan esas reglas; UI del SHAeeea540 está sin ejecutar, por lo que no se declara experiencia completa aprobada.

## Perfilado y pendientes

[Perfilado activo41390330778](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41390330778) pertenece a67c4ec8 y dos trabajadores ficticios: dos recorridos de alergias PASS;6907filas ponderadas/6923muestras,8618eventos runloop y4marcadores de posible bloqueo294.768–511.092ms. Tiempo CPU muestreado6907ms,5794msmain (inclusivo/no sumable). Captura0.610–22.511s terminada al salir proceso; sin parejas signpost de guardado. No mide latencia exacta del botón ni iPhone. Reexport Allocations41465406523 terminó técnicamente SUCCESS pero sin tablas de asignaciones: allocationMetricsAvailable=false. Asignaciones: **No medido**, no cero. No se ha comprobado una mejora antes/después con Instruments actual ni CPU/renderizado de cada acción.

Antecedentes:98c0dab/fallback41465269363 FAILURE,27nativasPASS/UI10PASS3FAIL; su ejecución principal41461695918 FAILURE por runnerARM no adquirido.67c4ec8/UI11PASS1FAIL1noejecutado; errores anteriores y sus causas constan en AUDIT.md y reportes previos. La planificación swift-package139 anterior no demuestra por sí sola un defecto de código ni una causa ambiental confirmada. No se borran ni renombran resultados fallidos.

## Distribución

**No IPA** porque hay fallos obligatorios sin resolver/validar. El BundleID coincide pero no basta para garantizar contenedor físico: también depende de la firma/equipo usados por iLoader. No se instala ni se reemplaza Build14 en el teléfono. Cuando haya candidato aprobado: respaldo cifrado reciente verificado y contraseña fuera del teléfono; misma cuenta/equipo/firma/BundleID; actualizar sobre instalación existente sin desinstalar/borrar/reimportar historia. Si aparece otra app o datos vacíos, detenerse. Revisar personas/visitas/alergias/borradores/stock compartidoFundoPlanta después de actualizar. No hay garantía de downgrade.


## Coste inicial del índice y commits de continuación

La creación del índice se mide aparte de las consultas: v2 71,410→87,724ms en esta pasada; v1 inicial no tenía esta métrica (null, no cero), candidato92,667ms. El coste se amortiza en la sesión y no se presenta como apertura fría gratuita ni como mejora v2. La memoria máxima agregada subió948KiB.

Desde el HEAD real90cb0ab se publicaron14commits de fuente, conservados en orden:4079122,69e75ad,911e49e,9143997,c274140,bdc27f1,df10938,e909ca6,6f74d66,67c4ec8,98c0dab,eeea540,7524c1b,799dc5f. Los dos últimos son posteriores a esta medición y requieren su propia validación; los commits de infraestructura intermedios no implican que sus estrategias abandonadas sigan vigentes. El estado final del código y la explicación de AUDIT.md tienen precedencia sobre mensajes históricos.
