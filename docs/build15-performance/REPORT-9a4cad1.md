# Build15 — informe de estado de9a4cad1

**FAILURE obligatorio abierto. NO IPA.** Fuente evaluada: `9a4cad1d1463eee5b0ae118b3c14fe58b73a7710`. No se presenta la auditoría como terminada ni la aplicación como aprobada para actualizar el iPhone.

## Continuidad y commits

La auditoría amplia empezó desde el HEAD real90cb0ab, posterior alcc45aa2 del prompt. Esta continuación comenzó eneeea540 y publicó7524c1b,799dc5f y9a4cad1. Se conservaron todos los avances. Build14 estable:9b1da6d4cdead4729bcade6843abcbcfc287e870. [PR10](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/pull/10) sigue en borrador, sin merge y sin modificaciones a main ni al iPhone.

Commits de fuente publicados desde90cb0ab:

```text
4079122 perf(search): narrow roster substring candidates with session-owned posting lists
69e75ad ci(b15): isolate Instruments, prepare cold auth UI and reduce redundant XCTest queries
911e49e ci(auth): subscribe to diagnostic stream before observing cold UI launch
9143997 perf(inventory): avoid rebuilding clinical roster for catalog-only and read-only dispensing actions
c274140 ci(b15): budget cold simulator setup and scope Instruments to owned device
bdc27f1 perf(v2): share complete snapshot audits through drafts, dispensing, backups and nursing reads
df10938 test(ios): keep picker taps above fixed footer and validate on native ARM64 runners
e909ca6 test(perf): require large v2 physical stock comparison and preserve measured failures
6f74d66 test(v2): use the journal's required synthetic-only temporary namespace
67c4ec8 fix(ci): let LocalAuthentication own CoreAuthUI lifecycle and retain genuine sensor checks
98c0dab test(ios): dismiss keyboard before locating form actions and recover recorded installer helper failure
eeea540 test(ios): bound genuine policy cancellation preflight and avoid repeated modal keyboard queries
7524c1b test(ios): await real policy cancellation asynchronously without blocking main
799dc5f test(ios): fail policy preflight explicitly when availability is denied
9a4cad1 test(ios): isolate genuine policy cancellation in an active MainActor test window
```

Los tres últimos modifican pruebas/CI/documentación, no App/Sources/formatos/clave/stock/BundleID. Las mejoras productivas medidas pertenecen al conjunto de cambios conservados: índice de búsqueda, sesión autenticada, auditorías compartidas, proyecciones y contexto de consumos/catálogo. No se atribuye una mejora de algoritmo a un commit que solo corrige pruebas.

## Workflows y pruebas del SHA evaluado

| Comprobación | Estado definitivo | Evidencia |
|---|---|---|
| Principal41497381071 |FAILURE | [Ejecución](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497381071) |
| Swift Core |433PASS/0FAIL/0SKIP; TypeScriptPASS | [job125455764062](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497381071/job/125455764062) |
| JavaScript/Python |62controlesPASS y24testsPASS | [job125455763601](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497381071/job/125455763601) |
| Ambos Excel oficiales |PASS, indicador10hojas y enfermeras98productos | Mismo job Swift y artifact13166943469 |
| Benchmarks v1/v2 |PASS en invariantes;13/12operaciones medidas | [v1](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497381071/artifacts/13168108265), [v2](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497381071/artifacts/13167063552) |
| Build14 cifrado |1PASS/0FAIL; preservación completa de la fixture | compatibility-9a4cad1.json |
| Xcode |Compilación realPASS;28nativas ejecutadas | [job125455764058](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497381071/job/125455764058) |
| Nativas |27PASS/1FAIL/0SKIP | [Artifact diagnóstico](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497381071/artifacts/13169635264) |
| UI13/Instruments/cierre |SKIPPED por dependencia fallida; no aprobados | Misma ejecución principal |
| Release ARM6441497509048 |SUCCESS | [Ejecución](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497509048) |
| Identidad ARM64 sin IPA |22archivos exactos verificados contra manifestSHA256 | [Artifact13166429463](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497509048/artifacts/13166429463) |

13/12 son operaciones de benchmark, no casos unitarios adicionales. Las semillas y preflights repetidos tampoco se suman como casos únicos nuevos. El único caso nativo fallido es N2ColdAuthenticationPreflightTests/testRealDeviceOwnerPolicyCanBeCancelledAfterColdLaunch.

## Bloqueo actual y diagnóstico real

La prueba exige appCancel real sin autenticar, mantiene cancelación12s/timeout18s y máximo dos solicitudes. En9a4cad1 usa una UIWindow pública temporal en escena foreground/MainActor, restaura la ventana anterior y espera mediante async fulfillment. La disponibilidad y evaluación se ejecutaron en main; el sistema confirmó la aplicación visible y recibió evaluatePolicy:2. Se registró INVALIDATE, pero no INVALIDATE_RETURNED ni CALLBACK. El timeout de18s produjo un fallo real; los otros27casos terminaron.

La traza llega a MechanismUI, añade motivos de desactivación y queda sin retorno de invalidación. No demuestra por sí sola que sea TCC, la ventana, el hilo o un fallo del proveedor. Los intentos anteriores de corregir contexto no se declaran efectivos para este caso.

Se publicó un [diagnóstico enfocado41509657892](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41509657892), fuente9a4cad1 y orquestación2a95b63a4e1446ac3b4f3482630851b47c6e738d, en la rama audit/b15-policy-observer-9a4cad1-20261102. Selecciona solamente el caso existente, sin modificar su código/política/plazos, y captura pantalla del Simulator propio y pila de su proceso durante la solicitud. Su marcador es POLICY_DIAGNOSTIC_PASS_SHA, nunca CORE_NATIVE_SHA ni aprobación de28nativas. No envía eventos biométricos, no lanza CoreAuthUI manualmente, no genera IPA y no accede al teléfono. Su resultado se debe consultar: al redactar, estaba en ejecución.

## Rendimiento físico v2 ficticio

Baselinec274140→9a4cad1 dentro del mismo job Linux x86_64, SwiftPM Release,9648trabajadores/1005atenciones y2154425bytes. Ambos mantienen diario por sesión. Cada operación conserva lecturas reales, HMAC, AEAD/AAD, SHA y control de revisión. Conteo70+ingreso10−salida2=78; estado físico completo inalterado en ambos lados. Dos productos físicos de fixture, mayoría de atenciones de observación; no representa100000movimientos ni98productos con consumo no nulo.

Medianas en ms; reducción positiva significa menor tiempo. Son operaciones de Core, no tiempos del botón SwiftUI ni del iPhone.

| Acción | Antes p50 ms | Después p50 ms | Reducción | Muestras |
|---|---:|---:|---:|---:|
| `allergy_confirmed_encrypted_save` | 4435.070 | 2983.455 | 32.73% | 7 |
| `draft_confirmed_encrypted_save` | 7622.774 | 3033.949 | 60.20% | 7 |
| `form_prepare_9648` | 235.807 | 235.057 | 0.32% | 7 |
| `history_read_1005` | 134.252 | 134.725 | -0.35% | 7 |
| `dashboard_refresh` | 95.006 | 92.910 | 2.21% | 7 |
| `correction_editor_load` | 51.216 | 47.179 | 7.88% | 3 |
| `dispensing_readonly_refresh` | 3702.754 | 326.787 | 91.17% | 3 |
| `inventory_catalog_only` | 1.417 | 1.557 | -9.92% | 3 |
| `worker_search_last` | 0.160 | 0.161 | -0.54% | 100 |
| `worker_search_common` | 7.002 | 7.055 | -0.76% | 100 |
| `nursing_98_export` | 8023.516 | 6365.788 | 20.66% | 3 |
| `encrypted_backup_verified` | 15843.537 | 12802.841 | 19.19% | 3 |

Búsquedas100muestras: último p950.168674→0.171769ms; común7.242281→7.211029ms. No se declara una mejora relevante de búsqueda v2: su baseline ya tiene el índice optimizado. Las operaciones con3/7muestras no publican p95 robusto. Las rutas sin mejora se mantienen visibles en JSON y tabla.

Recursos del workload Core preparado, compilador excluido: CPUuser235.52→161.79s; sistema1.07→1.16s; wall237.12→163.41s; RSS224200→224124KiB. No son asignaciones ni memoria física de cada pantalla. Los valores absolutos de distintos jobs/hosts no se comparan como si provinieran de un mismo dispositivo ni se atribuyen a cambios de prueba.

## Comparación v1 acumulada

Baselinecc45aa2 con diario por operación frente sesión del candidato. Misma escala9648/1005. Buscar último trabajador16.681393→0.168286ms, p9516.877312→0.175029; búsqueda común16.930920→7.913175ms, p9517.102986→8.759210. Indicador10hojas8405.987915→676.986382ms, tres muestras. El JSON conserva13operaciones; el indicador corresponde a v1, mientras que la fixture v2 declara indicatorExportMeasured=false. No mezclar ambos escenarios ni atribuir todas las mejoras a los últimos commits.

## Módulos y modificaciones conservadas

| Módulo y acciones | Causa encontrada | Corrección/garantía |
|---|---|---|
| Inicio, navegación, contadores, FaceID, background | Recuperaciones dobles y refrescos simultáneos | Lectura autenticada compartida, exclusión de refrescos, limpieza al bloquear; autenticación conservada |
| Atención4pasos, alergias, formularios | Auditorías/contextos repetidos y reconstrucción de padrón tras guardar | Sesión, prueba inmutable de bytes exactos, actualización de una alergia; confirmación real de persistencia y error visual diferenciado |
| Autosave y borradores | Consulta extra de revisión, cambios idénticos, conflicto con alergias | Etapa capturada junto al formulario, revisión optimista/reintento solo de conflicto; no perder borrador pendiente |
| Trabajadores, DNI/nombre, alta/ficha/historia | Filtrado/normalización de9648filas por consulta/render | Índice normalizado de sesión y candidatos por fragmento, debounce fuera de main, DNI por diccionario, lista vacía sin consulta,25filas/5sugerencias |
| Historial y edición | Incidencias cuadráticas y reconstrucción de padrón | Índice por visita, proyección autenticada con cadena de corrección verificada, actualización de fila |
| Inventario/Kardex/ingreso/conteo/R1-R0 | Contextos dobles al revisar consumos y cargar catálogo | Contexto único y catálogo directo; sin cambiar stock físico, FEFO, movimientos ni corte9–8 |
| Indicador ambulatorio10hojas | Sede vacía admitida como Fundo, repetición de cadena, I/O en main | Confirmar sede histórica en la visita sin copiar ficha laboral automáticamente ni duplicar/alterar stock; proyección e I/O por actor |
| Excel enfermeras/exportación/compartir | Auditorías repetidas e I/O en main | Reutilizar informes completos de la misma lectura, archivo protegido fuera de MainActor; fórmulas/formatos exactos |
| Backup/importación/restauración | I/O grande en main y auditorías duplicadas | Actor dedicado, acceso security-scoped,42MB, archivo regular sin symlink, protección completa y atomicidad |
| Catálogos/diagnósticos/procedimientos/vencimientos | Dependencias de contexto general en render | Catálogo revisado sin cargar datos innecesarios; alertas y validación clínica intactas |

[Mapa fuente completo](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/blob/9a4cad1d1463eee5b0ae118b3c14fe58b73a7710/docs/build15-performance/AUDIT.md). Inventario estático56archivos App/414sitios de acción, no ejecución de cada combinación. Las pantallas/rutas se revisaron en código; el HEAD no ha superado sus13casos de interfaz y no se declara todo medido.

## Build14, stock, rectificaciones y Excel

La fixture se produjo con el código original9b1da6d4 y archivos cifrados ficticios. Se verificaron diario/backup Build14 en9a4cad1, rectificaciónR1→R0 persistente tras reabrir, alergia guardada y nuevo backup roundtrip; workers/originalVisits/stock sin cambios. physicalDeviceValidated=false. No equivale a probar datos del teléfono ni a garantizar downgrade.

Se conservan conteos e ingresos, consumos, inventario único compartido, historial clínico/laboral, R0 como consumo clínico de presentación abierta y rectificación sin segundo débito físico. Las433pruebas incluyen corte9–8, primer conteo posterior al inicio, no inventar saldo anterior y saldo desconocido cuando falta evidencia. Los Excel Swift se compararon con TypeScript oficial: indicador10hojas/19tablas/432materiales y enfermeras98filas/7columnas, fórmulas, impresión y celdas combinadas. La confirmación histórica de sede es explícita por atención, nunca una sustitución automática por sede laboral.

Caché interna/inmutable solo en memoria de sesión: dos generaciones≤8MiB, reutilización solo de bytes descifrados idénticos ya auditados. Toda recuperación conserva Keychain/archivo/HMAC/AEAD/AAD/SHA y revisión. Bytes no auditados exigen auditoría completa; bloqueo/background/error de clave descartan sesión. No hay índices clínicos persistidos en texto plano ni informes arbitrarios de confianza.16escrituras concurrentes con una revisión dan1aceptada/15obsoletas. No se reinició ni accedió a la bóveda real.

## Perfilado y limitaciones

No medido en9a4cad1: latencia exacta del botón de alergias, apertura de pantallas SwiftUI, consultar Kardex como pantalla, renderizado por acción, asignaciones, memoria física del iPhone y comparación Instruments activa antes/después. El job Instruments actual se omitió por fallo nativo.

El perfil anterior67c4ec8/41390330778 obtuvo6923muestras,8618eventos runloop y4marcadores de posible bloqueo294.768–511.092ms, con dos trabajadores ficticios; no certifica9a4cad1. No produjo pares de signposts del guardado exacto. Allocations reexport41465406523 fue técnicamenteSUCCESS con allocationMetricsAvailable=false:No medido, no cero. Se comprobó que el binario histórico c274140 es Intel x86_64 y que el código de los recorridos/semillas de alergias no cambió; una comparación nueva sigue pendiente, no ejecutada.

No se fuerza una migración estructural del almacenamiento para alcanzar una cifra sin evidencia/compatibilidad. La alternativa aplicada conserva formatos y realiza trabajo autenticado compartido e I/O fuera de main. Los objetivos de latencia física quedan sin certificar.

## IPA e iLoader

No existe IPA de este candidato. El [artifact ARM64 actual](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41497509048/artifacts/13166429463) es una app compilada sin IPA/firma, no una actualización aprobada. Se verificaron22archivos contra manifest y BundleID `pe.danper.saludmovil.native.iloaderpreview`,0.4.2/build15,iOS17,ARM64, recursos exactos, ausencia de datasets clínicos/reloj de pruebas. El fallo nativo impide distribuir.

La firma y conservación del contenedor físico no se certifican con Simulator/BundleID solamente. Cuando exista candidato aprobado: respaldo cifrado reciente verificado y contraseña conservada fuera del iPhone; misma cuenta/equipo/firma/BundleID en iLoader; actualizar encima de la instalación existente sin desinstalar/borrar/reimportar historia. Detenerse si propone otra app o aparecen datos vacíos; comprobar trabajadores, atenciones, alergias, borradores y stock compartidoFundo/Planta después de actualizar. No instalar esta versión pendiente.

## Antecedentes no ocultados

799dc5f/41490125275FAILURE:27nativasPASS/1FAIL y UI13/InstrumentsSKIPPED; su Release41490193045SUCCESS en reintento. eeea540/41482409677FAILURE por stall del mismo preflight, con15casos sin completar.7524c1b41489657521CANCELLED por nuevo commit.98c0dab/fallback41465269363FAILURE, UI10PASS/3FAIL; principal41461695918falló por asignación de runnerARM. Recopilador41492441801FAILURE401 de descarga corregido en41494225210SUCCESS de solo lectura, no aprobación. Los fallos swift-package139 anteriores no prueban por sí solos causa de código ni causa ambiental confirmada. Reportes históricos y logs permanecen en GitHub.
