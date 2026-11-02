# DANPER Build15 — estado técnico de 799dc5f

**Validación incompleta. NO IPA.** Corte de este informe: 2026-11-02T17:48:49.744Z. [PR10](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/pull/10) en borrador, sin merge. Los resultados futuros deben comprobarse en los enlaces; este documento no aprueba un job pendiente.

## Fuente, continuidad y cambios publicados

HEAD al retomar esta continuación: `eeea540c94b6023684f56598c709cd8498d9bff8`. HEAD actual: `799dc5f9a2812ed01f82ed28c78eb90d0750e09f`. El inicio real de la auditoría amplia fue90cb0ab, posterior alcc45aa2 del prompt; se conservaron todos los avances. Base estable Build14:9b1da6d4cdead4729bcade6843abcbcfc287e870. No se ha modificado main ni instalado nada en el iPhone.

Commits de esta continuación:
- [7524c1b](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/commit/7524c1b48ae27ac3f1a8a4ea857484fa61713ef3): reemplaza espera síncrona de la prueba de política real por async fulfillment; disponibilidad/evaluación y cancelación fuera del hilo principal, invalidación programada antes de evaluar. Conserva12s/18s, dos solicitudes como máximo, appCancel real y prohibición de autenticar. Archiva diagnósticos de hang fallido.
- [799dc5f](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/commit/799dc5f9a2812ed01f82ed28c78eb90d0750e09f): fallo explícito si la política no está disponible; una respuesta a canEvaluatePolicy no puede aprobar una evaluación no solicitada.

Son correcciones de prueba/CI/documentación. No alteran App/Sources, formato, claves, inventario ni BundleID. La mejora de rendimiento medida corresponde al conjunto de cambios productivos conservados, no a estos dos commits de pruebas.

Desde90cb0ab se conservan14commits en orden:4079122,69e75ad,911e49e,9143997,c274140,bdc27f1,df10938,e909ca6,6f74d66,67c4ec8,98c0dab,eeea540,7524c1b,799dc5f. [Mapa y desarrollo técnico](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/blob/799dc5f9a2812ed01f82ed28c78eb90d0750e09f/docs/build15-performance/AUDIT.md). Las estrategias de infraestructura retiradas no se describen como vigentes por aparecer en mensajes históricos.

## Estado comprobado del HEAD actual

| Comprobación | Resultado actual | Evidencia |
|---|---|---|
| Swift Core |433PASS,0FAIL,0SKIP | [job125431384301](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41490125275/job/125431384301) |
| JavaScript y arnés Python |62controlesPASS y24testsPASS | [job125431383594](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41490125275/job/125431383594) |
| TypeScript y Excel oficiales |PASS, indicador10hojas y enfermeras98productos | Mismo job Swift, logs y artifact |
| Benchmarks v1/v2 |13/12operaciones medidas; invariantesPASS | [v1](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41490125275/artifacts/13165172544), [v2](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41490125275/artifacts/13166080038) |
| Compatibilidad Build14 |1PASS/0FAIL; cifrado y estado conservados | compatibility-799dc5f.json y jobperformance |
| Xcode/28nativas |EN EJECUCIÓN; no aprobado todavía | [job125431383716](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41490125275/job/125431383716) |
|13casos UI |PENDIENTES del job nativo | [ejecución principal](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41490125275) |
| Instruments actual |PENDIENTE | Misma ejecución principal |
| Release ARM64 actual |Reintento en ejecución; primer intento fallido sin pasos | [41490193045](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41490193045) |

Los13/12son operaciones de benchmark, no13/12casos unitarios adicionales. Las semillas/preflights repetidos tampoco se suman como nuevos casos únicos. El estado global del workflow aún no es SUCCESS.

## Mediciones v2: existencias físicas ficticias

Baselinec274140→799dc5f en el mismo job Linux x86_64, SwiftPM Release,9648trabajadores/1005atenciones y2154425bytes iniciales. Ambas implementaciones mantienen un diario por sesión. Cada operación conserva lecturas reales, HMAC, AEAD/AAD, SHA y revisión. Conteo70+ingreso10−salida2=78 y estado físico completo preservado en ambos lados. La fixture tiene dos productos físicos y mayoritariamente atenciones de observación; no simula100000movimientos ni98productos con consumo no nulo.

Medianas en ms. Reducción positiva significa menor tiempo. No son latencias de SwiftUI ni del iPhone. Las variaciones pequeñas se publican sin atribuir una causa no medida.

| Acción | Antes p50 ms | Después p50 ms | Reducción | Muestras | Estado |
|---|---:|---:|---:|---:|---|
| `allergy_confirmed_encrypted_save` | 6259.609 | 4027.899 | 35.65% | 7 | Medido; menor tiempo |
| `draft_confirmed_encrypted_save` | 11034.563 | 4141.777 | 62.47% | 7 | Medido; menor tiempo |
| `form_prepare_9648` | 334.538 | 336.140 | -0.48% | 7 | Medido; sin mejora relevante |
| `history_read_1005` | 193.092 | 193.418 | -0.17% | 7 | Medido; sin mejora relevante |
| `dashboard_refresh` | 138.797 | 139.223 | -0.31% | 7 | Medido; sin mejora relevante |
| `correction_editor_load` | 74.853 | 75.808 | -1.28% | 3 | Medido; sin mejora relevante |
| `dispensing_readonly_refresh` | 5387.106 | 485.409 | 90.99% | 3 | Medido; menor tiempo |
| `inventory_catalog_only` | 2.129 | 2.189 | -2.81% | 3 | Medido; sin mejora relevante |
| `worker_search_last` | 0.209 | 0.209 | -0.23% | 100 | Medido; sin mejora relevante |
| `worker_search_common` | 11.011 | 11.129 | -1.08% | 100 | Medido; sin mejora relevante |
| `nursing_98_export` | 11417.822 | 8650.401 | 24.24% | 3 | Medido; menor tiempo |
| `encrypted_backup_verified` | 22546.996 | 18207.215 | 19.25% | 3 | Medido; menor tiempo |

Búsquedas100muestras: p95 último0.219646→0.230266ms; común11.207140→11.289998ms. No mejoraron en esta comparación v2, cuyo baseline ya contiene el índice optimizado. Operaciones con3/7muestras: p95 no informado por muestra insuficiente para una estimación robusta. No se presentan como mejoras los tiempos de formulario, historial, panel, editor, catálogo ni búsqueda v2.

Construir el índice:94.440→95.078ms, separado de la consulta caliente. CPUuser del workload preparado337.27→225.83s; sistema1.09→1.02s; wall338.02→226.44s; RSS máxima224036→224516KiB. El tiempo bajó y la memoria máxima subió480KiB. Compilador excluido; no son CPU/memoria del iPhone ni asignaciones de cada acción.

## Comparación v1 acumulada

Baselinecc45aa2, diario por operación, frente sesión del candidato799dc5f; no atribuir todo el beneficio a los últimos commits. Mismos9648trabajadores/1005atenciones. El JSON contiene13operaciones y los recursos exactos. Ejemplos medidos:
- Formulario2584.746→294.824ms.
- Buscar último trabajador21.889→0.207ms.
- Indicador10hojas10739.990→856.914ms.

Este indicador corresponde a la fixture v1; la medición física v2 declara indicatorExportMeasured=false. No se mezclan ambas fuentes en un mismo porcentaje.

## Módulos, causas y modificaciones conservadas

| Módulo revisado | Coste encontrado | Modificación y control |
|---|---|---|
| Inicio/autenticación/navegación/background | Recuperar revisión y contadores por separado; refrescos simultáneos | Una lectura autenticada, refresco excluyente y limpieza al bloquear. Se conserva FaceID/código |
| Atención4pasos/alergias | Recuperaciones/auditorías/contextos repetidos; reconstruir padrón después de guardar | Sesión autenticada, prueba inmutable de bytes exactos y actualización de una alergia. Éxito solo tras confirmar persistencia; error visual posterior separado |
| Autosave/borrador | Lectura extra de revisión, escrituras idénticas y conflicto con alergias | Capturar etapa/formulario, revisión optimista y reintento solo de conflicto real; reprogramar borrador pendiente sin perderlo |
| Trabajadores/alta/ficha/búsqueda | Recorrer/normalizar todo el padrón por pulsación/render | Índice de sesión, listas de candidatos por fragmento, DNI por diccionario, debounce fuera de main; lista vacía sin texto,25filas/página,5sugerencias |
| Historial/rectificaciones | Incidencias por atención con coste cuadrático; recargar padrón para editar | Índice por atención y proyección autenticada, firma/cadena de rectificación verificadas y actualización de fila |
| Inventario/Kardex/ingresos/conteos/R1-R0 | Contextos duplicados al revisar consumo; cargar padrón para catálogo | Contexto único y catálogo directo. Invariantes físicas, cortes9–8 y conteos intactos |
| Indicador ambulatorio | Sede vacía admitida como Fundo; cadena verificada repetidamente; I/O en main | Confirmación histórica por atención; no copiar sede laboral automáticamente; proyección compartida y escritura por actor |
| Excel/enfermeras/exportar/compartir | Repetir auditorías completas e I/O en hilo UI | Reutilizar informes completos de la misma revisión y archivo protegido fuera de MainActor; comparación exacta oficial |
| Backup/importar/restaurar | I/O grande en main y auditorías de campos duplicadas | Actor de archivos, acceso security-scoped durante toda lectura, límite42MB, archivo regular sin symlink, protección completa/escritura atómica |
| Catálogos/diagnósticos/procedimientos/vencimiento | Trabajo en render y dependencia del contexto general | Conservar selección/alertas y reglas clínicas; usar catálogos revisados sin reconstruir datos no necesarios |

El inventario estático cubre56archivos App y414sitios de acción. No equivale a ejecutar cada botón/combinación ni medir cada pantalla. Las rutas de laboratorio y migración se conservan. Las pruebas actuales permiten validar el núcleo, pero la experiencia SwiftUI del HEAD sigue pendiente.

## Integridad y compatibilidad Build14

El productor es el código original9b1da6d4, con archivos cifrados completamente ficticios. En799dc5f se verificaron diario y backup Build14, rectificaciónR1→R0 persistente tras reabrir, guardado de alergia y nuevo backup roundtrip. Workers/originalVisits/stock sin cambios. physicalDeviceValidated=false. No es validación de datos del iPhone ni garantía de downgrade.

Las433pruebas conservan casos de R1/R0, consumo clínico R0, corte9–8, primer conteo posterior al inicio, saldo desconocido sin evidencia y rectificación sin débito físico duplicado. Ambos Excel oficiales se compararon con TypeScript:10hojas/19tablas/432materiales en indicador y98filas/7columnas, fórmulas/impresión/celdas combinadas en enfermeras.

La caché es interna/inmutable de sesión: dos generaciones≤8MiB, bytes descifrados exactamente iguales ya auditados. No acepta informes arbitrarios; Keychain y autenticación criptográfica siguen en cada recuperación; bloqueo/background/error de clave descartan sesión. Los bytes no auditados exigen auditoría completa. Los actores conservan serialización y control de revisión;16escrituras concurrentes con misma revisión dan1aceptada/15obsoletas. No hay índice clínico persistido en texto plano, reinicio de bóveda/stock, reimportación ni acceso al iPhone real.

## Fallos conservados y límites del perfilado

[eeea540/41482409677](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41482409677):FAILURE. Core433/JS62/Python24/Excel/compatibilidad/benchmarksPASS; native-28 quedó con12PASS,1caso bloqueado por stall y1error del runner,15casos sin completar; UI13/InstrumentsSKIPPED. Los dos commits actuales corrigen esa prueba, pero no se declaran aprobados hasta su Xcode real. [Reporte previo y muestras](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/blob/audit/b15-evidence-eeea540-20261102/docs/build15-performance/REPORT-eeea540.md).

[7524c1b/41489657521](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41489657521):CANCELLED por nuevo commit799dc5f; no aprobación completa. Release intermedia41489901985:FAILURE, sin pasos; no se reutiliza para799dc5f.

Recopilador41492441801:FAILURE por HTTP401 al descargar artifact tras redirección. Corregido únicamente en la rama auxiliar para retirar Authorization al cambiar de origen y usar la URL firmada. [Recopilador41494225210](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41494225210):SUCCESS, pero su estado es REPORT_ONLY_NOT_RELEASE_APPROVAL. Comprueba source799dc5f y publica JSON/muestras originales sin generar IPA. No reemplaza Xcode/UI ni oculta el fallo inicial.

Perfilado activo anterior67c4ec8/41390330778:6907filas ponderadas,6923muestras,8618eventos runloop y4marcadores de posible bloqueo294.768–511.092ms. Dos recorridos ficticios de alergiasPASS con dos trabajadores. Captura0.610–22.511s; no hay pares de signposts para medir el guardado exacto. Allocations reexport41465406523 terminó técnicamenteSUCCESS con allocationMetricsAvailable=false. Asignaciones:No medido. No certifica el HEAD actual ni demuestra ausencia de bloqueos.

Pendientes: latencia exacta de acciones SwiftUI, uso físico de CPU/memoria/asignaciones y comparación Instruments antes/después para todas las acciones. No se fuerza una modificación estructural del almacenamiento sin pruebas/migración segura para alcanzar una cifra. El stock físico y la seguridad clínica tienen prioridad.

## IPA, BundleID e instalación

**No IPA generada.** CurrentReleaseARM64 y gates nativos/UI aún pendientes. La compilacióneeea540 anterior verificó el BundleID estable `pe.danper.saludmovil.native.iloaderpreview`,0.4.2/build15,iOS17,ARM64,sin firma ni datasets clínicos; no sustituye la compilación799dc5f.

El BundleID por sí solo no garantiza conservar el contenedor físico: depende también de la cuenta/equipo/firma de iLoader. Cuando exista candidato aprobado, conservar un backup cifrado reciente verificado y su contraseña fuera del iPhone; misma cuenta/equipo/firma/BundleID; actualizar sobre la instalación existente sin desinstalar/borrar/reimportar historia. Detenerse si propone otra app o aparecen datos vacíos. Verificar trabajadores, visitas, alergias, borradores y stock compartidoFundo/Planta después de actualizar. No instalar una versión pendiente ni prometer downgrade.


[Artifact completo de recopilación](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41494225210/artifacts/13164943582) conserva READ_ONLY_EVIDENCE.json y RAW_SAMPLES.json. Las muestras proceden de los artifacts anteriores del mismo SHA; el verde del recopilador no es el verde de la aplicación.
