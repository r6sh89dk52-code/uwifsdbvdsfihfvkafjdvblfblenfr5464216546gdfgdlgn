# Build15 — cierre verificable de fuente 4daba96

**Estado: auditoría abierta, gate FAILURE, no IPA.** Este informe cierra los resultados de la fuente, no certifica candidatos posteriores. PR10 permanece borrador y sin merge; main y Build14 no se modifican. No se accede al iPhone real.

## Fuente y trazabilidad

Inicio real de esta auditoría: `90cb0aba7b553e536c9d3ad42d65eae9f7890fd5` (el SHA del prompt ya no era HEAD). HEAD primario verificado: `4daba9649824b58dedc57721d8cd1ad5af035963`, tree `a954b7b330a7228ea6d85225af5c78fd3ee213bd`. Build14 estable: `9b1da6d4cdead4729bcade6843abcbcfc287e870`. Los 25 commits publicados entre inicio y HEAD se enumeran al final.

## Validación del HEAD, sin reutilizar resultados antiguos

[Gate 41565545738](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41565545738): FAILURE.

| Comprobación | Aprobadas | Fallidas | Omitidas | Estado |
|---|---:|---:|---:|---|
| Swift Core Linux | 437 | 0 | 0 | PASS |
| Xcode SwiftUI + nativas iPhone16/iOS18.5 | 29 | 0 | 0 | PASS |
| Disponibilidad Face ID / consentimiento real | 1 + 1 | 0 | 0 | PASS, preflights adicionales |
| JavaScript / guardas clínicas | 62 | 0 | 0 | PASS |
| Python de rendimiento/CI | 37 | 0 | 0 | PASS |
| UI funcionales | 12 | 2 | 0 | FAIL, 14 ejecutadas |
| Presupuestos Core v2 | 9 | 0 | 0 | PASS, no son 9 casos UI |
| Ambos Excel oficiales | — | 0 | — | PASS de procesos, no inventar recuento de casos |
| Compatibilidad Build14 original | 1 | 0 | 0 | PASS con datos ficticios |
| complete | — | — | 1 job | SKIPPED por dependencia fallida |

Desglose UI: Glass3/0, Alergias2/0, Biometría2/0, Premium2/0, Menú1/0, Shell1/0, N3demo1/1, N3protegido0/1. Los JSON originales de las ocho suites están adjuntos en `evidence-4daba96`; la suma se verificó, sin inferir aprobación del nombre del job.

**Fallos restantes:** (1) El recorrido completo R1/R0 agota 600 segundos. La primera atención sí persiste, con stock70→68/12→11; la segunda llega a tratamiento pero no completa las aserciones finales. Tres pausas de 60 segundos de XCTest indican que no recibió la notificación de fin de animación; no prueban por sí solas que el iPhone tarde lo mismo ni que Picker sea la causa. (2) Fuente protegida: CoreAuthUI tarda en activarse, watchdog5s/Code-1000 y UI tardía sin mecanismo pendiente. La pantalla ya ofrece Reintentar Face ID cuando el test exige Verificando identidad. No se envió match ni se fabricó autenticación.

## Módulos revisados, causas y cambios conservados

El inventario estático contiene 55 archivos App Swift y 414 coincidencias de acciones/llamadas. Es un mapa heurístico, no demuestra que se hayan pulsado o medido las 414 ni una auditoría semántica exhaustiva de cada botón.

| Módulo/ruta | Coste o problema encontrado | Implementación publicada / validación y límite |
|---|---|---|
| Inicio, acceso, navegación, reanudación | Inspección protegida y Keychain aun con fuente confirmada vacía; inspección antes de escena activa | Diferir a escena activa, evitar Keychain solo ante ausencia/vacío real; errores/permisos/symlinks siguen cerrados; revisión al desbloquear. Pruebas nativas y de raíces; UI protegido aún falla por activación del simulador. Inicio real del iPhone: No medido. |
| Nueva atención y pasos | Contextos completos/revisiones reconstruidos y tareas de interfaz repetidas | Contextos y modelos por sesión, separación de persistencia/actualización visual, control de revisiones y validación clínica conservados. UI alergias/formulario pasa; R1/R0 final sigue pendiente. No se certifica cada botón. |
| Alergias | Recuperaciones/auditorías completas y carreras con borrador; error visual podía confundirse con error de persistencia | Confirmación real de escritura y recuperación antes de éxito, actualización visual diferenciada, reintento limitado de revisión, validación previa a administrar intacta; benchmarks Core y UI2PASS. Tiempo del botón con 9648 en iPhone: No medido. |
| Autosave y borradores | Guardados repetidos e interferencia con alergias | Captura de formulario/paso, omitir duplicados, reprogramar tras fallo de alergias, no cancelar commit en curso. Pruebas concurrentes/de persistencia; nuevos controles nativos de carga aún en curso. |
| Trabajadores | Normalizar/filtrar 9648 por pulsación e índices reconstruidos por revisión | Índices en memoria por sesión, listas de candidatos/bigramas, búsqueda fuera del hilo principal y diferida, 0 resultados con campo vacío, 25/página y sugerencias limitadas. Conserva alta/corrección/historial; datos sensibles no persistidos en claro. 100 consultas medidas; UI con 9648 pendiente. |
| Historial, correcciones R y sede | Recargas globales y búsquedas de incidencias por atención; sede histórica pendiente | Índices por atención, actualización de fila, sede explícita por atención sin copiar automáticamente ficha actual, sin duplicación/stock; pruebas Core/exportación. No se afirma mejora significativa v2 de lectura1005. |
| Kardex e inventario | Catálogo y dispensación solo lectura reconstruían padrón/contexto clínico completo | Catálogo directo y contexto de lectura compartido; conserva inventario único, físico, ingresos y R0 clínico, corte9–8, primer conteo posterior y NO VERIFICADO sin evidencia. Auditorías/Excel/regresiones pasan; recorrido UI R final pendiente. |
| Indicador10hojas / enfermeras98 | Repeticiones de auditoría/transformaciones/exportación y falta de sede histórica verificada | Reutilización de pruebas de misma revisión y armado fuera de UI; rectificación de sede por atención; plantillas oficiales y consumos históricos probados. Indicador10hojas medido v1; no v2. Compartir real iPhone: No medido. |
| Bóveda, concurrencia, seguridad | Auditoría completa repetida de los mismos bytes autenticados, JSON repetido | Prueba inmutable solo para bytes descifrados idénticos ya auditados: 2 entradas RAM≤8MiB cada una; limpiar al bloquear/background/fallo Keychain. Cada operación mantiene archivo/HMAC/AEAD/AAD/SHA/revisión/Keychain; bytes nuevos requieren auditoría completa. Corrupción/cadena forjada y concurrencia tienen regresiones. |
| Respaldo/restauración/importación | I/O y transformación en interfaz, auditoría duplicada | Actor de I/O, archivos regulares≤42MB, alcance de seguridad, escritura atómica/protección completa; respaldos14 originales/roundtrip aprobados. Restauración real de contenedor iPhone: no ejecutada. |

No se eliminan módulos ni controles clínicos, no se inventa stock, no se vuelve a descontar historia, no se impone motivo escrito para rectificación R y no se sustituye R0 por ausencia de consumo clínico.

## Rendimiento medido, condiciones y límites

Core SwiftPM Release x86_64 Linux, mismo host por comparación, 9648 trabajadores/1005 atenciones ficticias, sin compilador en recursos; valores p50 en ms. Tabla v2: C274→4daba, ambos con sesión de bóveda, verificaciones criptográficas reales. No es comparación aislada del último commit UI ni latencia SwiftUI/iPhone. Muestras3/7 no permiten p95 defendible; solo búsquedas100 tienen p95.

| Acción | Antes ms | Después ms | Reducción | n | Interpretación |
|---|---:|---:|---:|---:|---|
| allergy_confirmed_encrypted_save | 3340.115 | 2163.922 | 35.21% | 7 | Mejora medida |
| draft_confirmed_encrypted_save | 5785.598 | 2224.702 | 61.55% | 7 | Mejora medida |
| form_prepare_9648 | 168.442 | 168.722 | -0.17% | 7 | Sin mejora relevante |
| history_read_1005 | 100.221 | 100.300 | -0.08% | 7 | Sin mejora relevante |
| dashboard_refresh | 67.987 | 65.400 | 3.81% | 7 | Sin mejora relevante |
| correction_editor_load | 36.022 | 35.500 | 1.45% | 3 | Sin mejora relevante |
| dispensing_readonly_refresh | 2761.426 | 233.947 | 91.53% | 3 | Mejora medida |
| inventory_catalog_only | 1.018 | 0.981 | 3.68% | 3 | Sin mejora relevante |
| worker_search_last | 0.123 | 0.119 | 3.59% | 100 | Sin mejora relevante |
| worker_search_common | 5.390 | 5.410 | -0.37% | 100 | Sin mejora relevante |
| nursing_98_export | 6005.277 | 4669.216 | 22.25% | 3 | Mejora medida |
| encrypted_backup_verified | 11961.688 | 9464.413 | 20.88% | 3 | Mejora medida |
| Indicador 10 hojas (**v1, otra base cc45**) | 10380.760 | 829.349 | 92.01% | 3 | Mejora Core v1; no UI |

V2 p95 búsqueda último trabajador0.124648ms y búsqueda común5.615779ms (100 muestras cada una). CPUusuario178.55→120.09s, sistema0.95→0.93s, wall179.40→120.94s; picoRSS224364→223520KiB para el workload completo, no memoria de pantalla. V1 acumulativo cc45→4daba CPU505.93→118.62s pero RSS182388→183740KiB aumenta ligeramente: no se declara una mejora universal de memoria. El formulario/historial/búsqueda común v2 no muestran mejora relevante. No se inventan cifras para apertura real, transiciones, todos los botones, guardado grande UI, renderizados, asignaciones durante guardado ni contenedor físico.

## Instruments y ampliación nativa: resultados reales

Gate4daba captura Inicio ficticio separado (idle) con éxito, artifact13201090644. No mide un guardado activo.

Captura coordinada41568095067 terminó CANCELLED por plazo del job. Primera TimeProfiler tuvo continuidad del PID y completó aserciones clínicas pero rechazó escribir ACK en una ruta cuyo contenedor del runner había cambiado al reinstalar XCTest; el guardia de propiedad falló cerrado. Segunda Allocations no terminó de finalizar. No hay comparación aprobada.9801.37ms observado bajo automatización/profiler en baseline2trabajadores NO es tiempo del iPhone ni del HEAD4daba. La nueva prueba piloto reconsulta solo el contenedor del bundle de runner del mismo simulador tras su activación; conserva validaciones de propiedad/archivo exclusivo y no cambia app/nativas selladas.17 pruebas locales de protocolo aprobadas. Piloto solo TimeProfiler actual: no sustituye comparación antes/después/Allocations.

Carga nativa grande41572032804 compiló ambas fuentes y sembró9648/1005, pero falló una aserción antes de medir: contó el borrador premium original dentro de attentions como si fuera una atención guardada (1006). La corrección3ed78cf distingue saved/draft y exige conservar todo el objeto del borrador además del estado físico/trabajadores/historia; no borra datos para aprobar. El mensaje adicional Differentfictionalclinicalsource provenía de pruebas de origen ausentes tras el fallo temprano, no demuestra bytes distintos. La nueva ejecución41630672533 aprobó; se detallan muestras e integridad en la actualización nativa al final. Son APIs nativas DEMO cifradas/Keychain real, no botón SwiftUI ni teléfono físico.

Capturas anteriores incompletas, incluidos fallos45/90s de exportación/finalización, permanecen documentadas. Exportación idle0cdc41557902626 sí obtuvo173Statistics/85496AllocationList,14,682,432bytes persistentes Heap+VM: otra fuente, otra operación, categorías superpuestas; no se reutiliza como mejora del guardado4daba.

## Compatibilidad Build14, Excel e identidad

El productor original Build14 estable9b1da6d generó respaldo y journal ficticios. El consumidor4daba leyó ambos, rectificó historia y exportó/restauró un respaldo nuevo conservando stock completo, trabajadores y visitas originales: PASS1/0. `physicalDeviceValidated:false`. Las dos familias Excel oficiales pasan generación y regresiones de datos, incluidos enfermeras98, corte mensual, consumos históricos rectificados, R0 y rectificaciones de sede. No se ha demostrado aún el recorrido UI R1/R0 completo del HEAD.

ReleaseARM64 fuente4daba41565648700 SUCCESS (orquestación f07c287). Artifact13200006208 contiene app compilada sin IPA.22 hashes comprobados, MachOARM64 real, BundleID `pe.danper.saludmovil.native.iloaderpreview`, versión0.4.2/build15/min17; hooks DEBUG ausentes. No confundir compilación Release exitosa con autorización de distribución.

## Trabajo nuevo aislado y pendientes

- ff94ee5: piloto coordinado actual, ejecución41631784691, pendiente. No comparación final.
- c1ec68d: experimento menú A/B, ejecución41631982012, pendiente. Misma pruebaR completa, mismo600s, una modificación de producción; ninguna promoción al primario antes de evidencia.
- 9b68b9b: un reintento real FaceID dentro del plazo existente, ejecución41632095913, pendiente. Pruebas biométricas dedicadas mantienen exigencia de entrada automática; no cambia código de seguridad.
- 3ed78cf: corregir clasificación de borrador del fixture grande, ejecución41630672533 SUCCESS;14controles realesPASS, ver actualización nativa.

Los candidatos se basan en4daba y conservan trazabilidad; sus resultados no aprueban el HEAD principal. Debe evaluarse cada resultado, promover solo cambios demostrados y volver a ejecutar todos los gates obligatorios en el nuevo HEAD. Falta comparación activa completa de Instruments, medición real de UI a gran escala, cierre UI14/0 y comprobación final antes de IPA. Auditoría integral aún NO terminada.

## Enlaces exactos

- [Gate actual FAILURE: 41565545738](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41565545738)
- [Release ARM64 SUCCESS: 41565648700](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41565648700)
- [Captura coordinada CANCELLED: 41568095067](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41568095067)
- [Carga nativa anterior FAILURE: 41572032804](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41572032804)
- [Carga nativa corregida pendiente: 41630672533](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41630672533)
- [Piloto Instruments pendiente: 41631784691](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41631784691)
- [Menú A-B pendiente: 41631982012](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41631982012)
- [FaceID reintento pendiente: 41632095913](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41632095913)
- [Release ARM64, NO IPA](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41565648700/artifacts/13200006208)
- [PR10 borrador](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/pull/10)

## Distribución y actualización

**No hay IPA aprobada ni artifact IPA.** Fallan dos UI obligatorias y quedan mediciones abiertas. No actualizar el iPhone con estos candidatos. Cuando exista una IPA aprobada: generar y verificar respaldo cifrado reciente de Build14 y guardar contraseña fuera del teléfono; usar mismo BundleID, AppleID y equipo de firma de iLoader y actualizar sobre la instalación existente. Nunca desinstalar, borrar contenedor ni reimportar historia para actualizar. Si iLoader propone identidad/aplicación nueva, o aparece inventario vacío, detenerse. Confirmar luego trabajadores, visitas, alergias, borradores e inventario compartido. Mismo BundleID solo no garantiza conservar acceso a Keychain si cambia equipo de firma. No se certificó contenedor físico ni downgrade.

## Commits primarios conservados

```text
4daba96 test(ios): await actual keyboard transitions and reveal protected activation control; preserve clinical assertions
0cdc760 test(storage): retain fail-closed inspection for substituted and dangling source roots
bae26cf fix(ios): verify clinical revision after active unlock and await automatic DNI keyboard dismissal
9a28363 perf(startup): defer protected inspection until active and avoid Keychain only for confirmed empty storage
1419703 chore(ci): preserve original validation script file mode
787b3ad fix(ci): validate actual 14-case UI inventory and selectors; regress real shell closure
59e6773 test(b15): bound actual delayed Face ID consent acknowledgement and record timing
0ed08d5 docs: record observed Face ID consent root cause and verified unchanged cancellation trial
7bfde6c test(ci): prepare real Face ID consent sequencing, strict 14-case UI evidence and Core budgets
bcbf7a0 test(perf): guard measured Core gains, query p95 and memory with seven regressions
9a4cad1 test(ios): isolate genuine policy cancellation in an active MainActor test window
799dc5f test(ios): fail policy preflight explicitly when availability is denied
7524c1b test(ios): await real policy cancellation asynchronously without blocking main
eeea540 test(ios): bound genuine policy cancellation preflight and avoid repeated modal keyboard queries
98c0dab test(ios): dismiss keyboard before locating form actions and recover recorded installer helper failure
67c4ec8 fix(ci): let LocalAuthentication own CoreAuthUI lifecycle and retain genuine sensor checks
6f74d66 test(v2): use the journal's required synthetic-only temporary namespace
e909ca6 test(perf): require large v2 physical stock comparison and preserve measured failures
df10938 test(ios): keep picker taps above fixed footer and validate on native ARM64 runners
bdc27f1 perf(v2): share complete snapshot audits through drafts, dispensing, backups and nursing reads
c274140 ci(b15): budget cold simulator setup and scope Instruments to owned device
9143997 perf(inventory): avoid rebuilding clinical roster for catalog-only and read-only dispensing actions
911e49e ci(auth): subscribe to diagnostic stream before observing cold UI launch
69e75ad ci(b15): isolate Instruments, prepare cold auth UI and reduce redundant XCTest queries
4079122 perf(search): narrow roster substring candidates with session-owned posting lists
```

## Actualización: carga API nativa real aprobada

[41630672533 SUCCESS](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41630672533), orquestación3ed78cf, fuentes C274/4daba. [Artifact13229163757](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41630672533/artifacts/13229163757), ZIP SHA2568d5de66ec0388526a0c69a81a238d39ccd4947e44114de3f9a642c327e8d57fc verificado tras descarga. Se comprobaron los JSON originales de cada caso y se recalcularon medianas desde las muestras.

Mismo Mac/Xcode16.4, iPhone16/iOS18.5 Simulator x86_64, compilación Debug con fixtures diagnósticos, App/Core/project sin modificar frente a cada fuente; dos Simuladores propios nuevos. Ambos parten de la misma fuente clínica ficticia plaintextSHA2566124699907f4d83ea483acc4747bd91f56870c54ad2ab25d832a25ee1449c39e. Los UUID/fechas/IV de las activaciones físicas son independientes por variante: no se afirma igualdad byte a byte entre dos contenedores cifrados. Dentro de cada variante sí se comprobó igualdad completa del estado físico, todos los trabajadores/1005 visitas guardadas originales y el objeto completo del borrador original antes/después de las siete revisiones.

| API nativa DEMO | Antes p50ms | Después p50ms | n por variante | Estado |
|---|---:|---:|---:|---|
| Confirmar revisión cifrada de alergias | 10077.757 | 4723.935 | 7 | Reducción53.13%; p95 no calculado |
| Buscar último trabajador, índice ya construido | 0.899374 | 0.677040 | 100 | Medido; p95antes5.618206/después0.773945ms |
| Primera página25, búsqueda común | 0.144267 | 0.112751 | 100 | Medido; p95antes1.017523/después0.133154ms |
| Cargar contexto inicial | 11421.428 | 6329.699 | 1 | Muestra única, no percentiles |
| Construir índice | 529.448 | 509.370 | 1 | Muestra única, no mejora robusta inferida |

Alergias actual mínimo3891.88/máximo5207.63ms: no se promete que todos los guardados sean inferiores a5s. Las APIs usan actor/bóveda/Keychain/cifrado/persistencia reales del namespace DEMO; no miden FaceID de la fuente clínica protegida ni latencia SwiftUI. **7 controles nativos por variante,14PASS/0FAIL/0SKIP**; no sustituye las29nativas o14UI del gate oficial. Conservación del borrador original verificada en las aserciones y el log final. Se mantiene FAILURE del intento anterior por clasificar mal ese borrador.

La prueba UI grande adicional [41633526985](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41633526985), commit31d9269, compiló con Xcode y está en ejecución funcional al publicar esta actualización. Conserva las dos pruebas originales de alergias (todas las aserciones) y añade búsqueda del último trabajador; exige preservar físico/historia/padrón/borrador original. Las marcas de tiempo son una muestra de automatización e incluyen consultas/scroll/typing/idle; no hay comparación equivalente ni p95 de botón. Ningún resultado pendiente se aprueba y no se habilita IPA.

## Cierre de las ejecuciones posteriores y defecto nuevo confirmado

Los siguientes estados sustituyen sus menciones anteriores de pendiente. El HEAD primario permanece4daba; ninguno de estos candidatos está promovido ni habilita IPA.

| Ejecución | Cierre | Evidencia real |
|---|---|---|
| 41631982012 menú A/B | FAILURE | Baseline29nativePASS/demo1PASS1FAIL; candidato29nativePASS/demo2PASS. Baseline muestra0visitas en Historial después de ambas atenciones y sus conteos; candidato completoPASS. Ambos0avisos de animación; duración total621.873→623.729s de recorridos distintos por fallo. No se demuestra mejora de menú: no promover como optimización. |
| 41632095913 reintento protegido | FAILURE | Native29PASS; biometría1PASS1FAIL por AXsnapshotstimeout; protegido0PASS1FAIL al aplicar límite de pie fijo a primera creación sin ese pie. Autenticación inicial avanzó realmente hasta formulario; no se aprueba creación/relaunch completo. |
| 41633526985 UI9648 | FAILURE | UI2PASS1FAIL0skip: búsqueda último trabajador por nombre y5ciclos de formularioPASS; alergias falló antes de interactuar, Home aún no encontrado dentro25s de arranque frío y sí visible en captura posterior. No hay tiempo de guardar alergias UI grande ni integridad postUI aprobados; controles post no ejecutados. Búsqueda observada9963.65ms incluye escritura/consultas/automatización,n1,sinantes/después. |
| 41631784691 piloto | FAILURE | Recorder realmente listo antesUI/PID continuo; simctlget_app_container agotó10s al comienzo de AX. Las aserciones clínicas luego terminaron pero ACK nunca aprobado y finalización falló.6815.76msdeautomatización no es una captura aprobada ni latencia iPhone. |

Defecto de Historial: al terminar de instalar la proyección se ejecuta el filtro con consulta vacía. N2SearchIndex usa String.contains("") bajo Foundation; Apple documenta que ese overload requiere argumento no vacío. El listado puede pasar de visitas correctas a0 tras el debounce. https://developer.apple.com/documentation/swift/stringprotocol/contains(_:)-40kbf . Falta una regresión de minLength0, aunque el caso roster vacío sí estaba probado. La presencia de todos los datos/stock guardados en el recorrido anterior y el código identifican una ruta de visualización, no pérdida de visitas persistidas.

Además, la pestaña retenida podía devolver la proyección anterior sin consultar revisión después de guardar otra atención. Candidato094d1da corrige la consulta vacía explícitamente, respeta el resultado0del roster por defecto y límites/orden, obtiene revisión+proyección en una misma recuperación autenticada y reutiliza solo la revisión idéntica. Añade Core2casos y nativaDarwin1, y precarga Historial en el recorrido original R antes de guardar ambas atenciones. Todos los controles físicos/R/relaunch y600s permanecen. Ajusta solo el viewport real sin pie fijo del botón first-run, manteniendo la autenticación/sensor reales de9b68b9b; no modifica la lógica de seguridad de App.

Redprobe d49e557 /41653553937 ejecuta las regresiones de búsqueda vacía contra Core SIN MODIFICAR para conservar evidencia roja por plataforma. Candidato094d1dacc1f219420b72861c9f97cbe59bd7c6fe /41654256289 ejecuta todos los gates nuevos: esperados439Swift/30native/14UI/62JS/37Python/Excel/compat14/presupuestos. Al publicar, JSjobSUCCESS, demás activos; esos recuentos no se declaran aprobados. No se reutiliza evidencia4daba para094d.

Piloto fff72169c38ba59f0548ec1b39141556f936d2dd difiere la misma consulta acotada de contenedor hasta el marcador real de fin de aserciones, antes de cualquier ACK. Mantiene10s, contenedor del mismo bundle/simulador, archivo exclusivo, PID, grabador real y todos los plazos.17pruebas localesPASS incluyendo hijo realSIGINT0/7y fases separadas de actividad/completado. Captura nueva pendiente; es pilotoTimeProfiler actual4daba, no comparación completa ni certificación094d.

El arranque frío grande continúa abierto. No se eleva25s para declarar una mejora ni se omite el fallo. El usuario debe seguir con Build14; sin IPA aprobada y sin cambios en main/Build14/datos del iPhone.
