# Build 15 — evidencia del HEAD 0cdc760, cierre FAILURE conservado

**Cierre definitivo de0cdc: FAILURE, UI11PASS/3FAIL/0SKIP. No hay IPA nueva.**

El HEAD de aplicación avanzó posteriormente a4daba9649824b58dedc57721d8cd1ad5af035963 con tres ajustes de interacción UI; su gate41565545738 y Release41565648700 deben validar ese SHA. Este informe certifica únicamente las cifras explícitas de0cdc, cuyo cierre falló. No aprueba4daba.

Los tres fallos actuales son: geometría de teclado leída antes de desplegarse completamente, consulta AX de teclado agotada aunque captura posterior ya lo muestra oculto, y botón de activación fuera del viewport. Biometría(cancel/no-match/retry/foreground) y alergias completas aprobaron. La fuente clínica vacía ya pasa acceso/desbloqueo; no se atribuye retroactivamente toda la demora antigua a Keychain. Corte técnico: 3 de noviembre de 2026 UTC (2 de noviembre, Lima). El estado exacto de los jobs al corte está en [workflows-snapshot.json](evidence-0cdc760/workflows-snapshot.json); puede avanzar después de este documento.

## 1. Fuente y continuidad

- HEAD citado originalmente por el usuario: `cc45aa27013922a68301be01eaa1f1a16ad9e910`.
- HEAD real encontrado al retomar esta auditoría: `90cb0aba7b553e536c9d3ad42d65eae9f7890fd5`. Se conservaron sus avances. No se reinició desde cc45.
- HEAD de esta continuación antes de los cinco cambios recientes: `59e6773dafdc2e08d291bd7e33b5c6ffd685f1fd`.
- HEAD clínico actual: **`0cdc76048db778a6561a237fcb46d63d168a4f7c`**.
- Rama: `fix/indicator-historical-visit-site-build15-20261030`; PR #10 sigue borrador, sin fusionar.
- Base estable Build 14: `9b1da6d4cdead4729bcade6843abcbcfc287e870`. No se modifica main ni la versión instalada.
- Este informe y las preparaciones auxiliares no adelantan el HEAD de aplicación que está bajo prueba.

## 2. Pruebas del HEAD actual

| Comprobación | Aprobadas | Fallidas | Omitidas | Estado al corte |
|---|---:|---:|---:|---|
| Swift Linux completo | 437 | 0 | 0 | PASS; incluye comparaciones oficiales XLSX |
| Xcode nativas, iPhone 16 Simulator iOS 18.5 x86_64 / Xcode 16.4 | 29 | 0 | 0 | PASS, compilación real SwiftUI |
| Preflight disponibilidad Face ID nativo | 1 | 0 | 0 | PASS; preparación, no sumar como caso clínico nuevo |
| Consentimiento real Face ID UI previo a nativas | 1 | 0 | 0 | PASS; no concede autenticación clínica |
| Controles JavaScript | 62 | 0 | 0 | PASS |
| Regresiones Python del workflow | 37 | 0 | 0 | PASS, log 0.364s |
| Compatibilidad cifrada con productor Build 14 original | 1 | 0 | 0 | PASS |
| Presupuestos de rendimiento Core v2 | 9 | 0 | 0 | PASS; son presupuestos, no nueve casos XCTest |
| UI funcional obligatoria | 11 | 3 | 0 | FAILURE;14casos realmente ejecutados |
| Release iPhoneOS ARM64 | Compilada | 0 | — | PASS identidad, sin IPA |
| Instruments activo antes/después | 4recorridosUI;2TimeProfilertraces | 2Allocations finalización y1exportCPU | — | FAILURE; ambos perfiles empezaron DESPUÉS del guardado objetivo |
| Guardas auxiliares de empaquetado | 10 | 0 | 0 | PASS local sobre metadatos ficticios; no aprobación de app |

Las 29 nativas finalizaron con 0 fallos/omisiones: 239.262s agregados de XCTest. La cancelación genuina de LocalAuthentication devolvió appCancel -9, caso12.244s; no se envió match para hacerlo pasar. El nuevo caso de fuente vacía pasó en0.012s y comprobó cero consultas Keychain y ausencia de creación de datos. Es duración del caso, no una medición de arranque completo ni del iPhone real.

No se suman preparaciones o fixtures repetidos a los casos funcionales únicos. No se usan resultados de otro SHA para aprobar 0cdc.

## 3. Módulos y acciones auditados

El artifact actual contiene `action-inventory.json`: **55 archivos Swift de App y414 sitios de acción/llamada**. El antiguo texto de AUDIT.md cita56 archivos; el JSON generado desde este HEAD es la cuenta vigente. Es un inventario estático de vistas, botones, navegación, importadores, llamadas a bóveda, tareas y MainActor: no demuestra haber pulsado cada combinación de414 acciones. El mapa original y las correcciones anteriores se conservan en `AUDIT.md`.

| Módulo / acciones significativas | Datos necesarios y coste observado | Mejora preservada o implementada | Verificación / límite |
|---|---|---|---|
| Arranque / Face ID / reanudar | Existencia de fuente y revisión; se consultaba Keychain incluso sin archivos, antes de escena activa | Omitir solo la lectura sin fuente confirmada; inspección/revisión tras escena activa y sesión permitida | 4 regresiones Core +1 nativa; UI aún pendiente; causa del antiguo spinner no probada completamente |
| Inicio / contadores / pestañas | Conteos y revisión, no reconstrucción de padrón completo | Lectura autenticada compartida, refresco excluyente | Core dashboard y layouts; latencia física No medido |
| Atención / seleccionar trabajador / evaluación / tratamiento / resultado | Contexto clínico de una revisión; auditorías repetidas y reconstrucción tras escribir | Sesión y proyecciones autenticadas, actualización de una alergia, tareas fuera de MainActor | Swift/Native, UI actual en curso |
| Guardar revisión de alergias | Escritura cifrada y lectura confirmada; conflictos con autosave y refresco posterior | Conserva confirmación real; error de persistencia distinto del fallo visual; no elimina alertas clínicas | Benchmark v2 n7; regresiones concurrencia; UI actual pendiente |
| Borradores / cambiar paso / cerrar / recuperar | Etapa y formulario capturados; escritura repetida idéntica y revisión redundante | Debounce, no reescribir estado idéntico, reintento solo ante revisión obsoleta, reprogramar tras error de alergias | Pruebas Swift; persistencia y conflictos no se desactivan |
| Trabajadores / DNI / nombre / paginar / ficha / antecedentes | Índice normalizado de sesión, sin ordenar todo el padrón por pulsación | Lista vacía sin texto,25 filas/página,5 sugerencias, diccionario DNI e índice de fragmentos con candidatos escasos | 9648 registros, equivalencia/Unicode/último registro,100 muestras de búsquedas; módulo conservado |
| Diagnósticos / procedimientos / medicamentos / selectores | Catálogos revisados y validaciones clínicas | Costes comunes de contexto reducidos; catálogos directos donde no se precisa historia | Regresiones clínicas; no se afirma una latencia individual de cada selector |
| Historial / filtros / detalle / editar / volver | Visitas e incidencias por identificador; antes recorridos repetidos | Índice de incidencias, proyección autenticada, actualizar una fila sin duplicar visita | Swift correcciones; benchmark lectura/editor; UI actual pendiente |
| Inventario / búsquedas / ingresos / conteo / consumos | Inventario único y revisión; catálogo no necesita padrón | Catálogo directo, una sola preparación de contexto en revisión de consumos | Snapshot v2 completo y saldo78 conservados; ingresos/conteos no se recalculan desde historia |
| Kardex / R1-R0 / períodos9–8 / vencimientos | Movimientos y evidencia de conteo; auditorías duplicadas | Auditorías completas reutilizadas para mismos bytes; no altera cálculo de stock ni inventa aperturas | Regresiones de primer conteo posterior, desconocido, R histórico; UI R actual pendiente |
| Excel enfermeras98productos | Movimientos rectificados, formatos/fórmulas y saldos verificables | Lectura autenticada compartida y escritura protegida fuera de MainActor | Swift compara XLSX con original TS; benchmark v1/v2 |
| Indicador10hojas / períodos / sedes / compartir | Sede histórica de cada visita; no sede actual copiada de trabajador | Rectificación explícita por atención, cadena verificada, generación/proyección compartida | Regresiones sede/Excel; exportación v1 medida; v2 indicador No medido |
| Respaldos / verificar / restaurar | Fuente cifrada y validación integral; I/O grande en interfaz | Actor I/O, seguridad scoped durante lectura,42MB, archivos regulares, atómico/protección completa | Build14 original→actual +roundtrip; compatibilidad hacia atrás/downgrade no certificada |
| Sesión / cifrado / concurrencia | Keychain, HMAC, AES-GCM/AAD, SHA y revisión en cada operación | Reutilizar solo auditorías semánticas de bytes exactos, prueba interna inmutable; caché acotada en RAM | Corrupción/cadena falsificada rechazadas;16 escrituras: una aceptada y15 obsoletas; sin índices clínicos en texto plano |

## 4. Cambios recientes y causas demostradas

1. **787b3ad +1419703:** descubrimiento UI ya tenía14 casos, pero cierre shell exigía13. Rechazaba un inventario completo y podía aceptar el anterior incompleto. Nuevo verificador coteja suites, clases, selectores y cuentas con fuente actual. Cuatro regresiones ejecutan descubrimiento/cierre shell reales: antes2PASS/2FAIL; después37PythonPASS. Se conserva modo100644 del script.
2. **9a28363 +bae26cf +0cdc760:** inspección de fuente vacía hacía lectura Keychain innecesaria y podía comenzar fuera de escena activa; se difiere inspección/revisión y se omite Keychain solo ante ausencia/raíz real vacía confirmada. Errores, permisos, archivo no directorio, enlaces simbólicos y enlaces rotos mantienen el recorrido protegido. No cambia claves, formatos, archivo, stock ni servicios Keychain. Cuatro regresiones Core y una nativa nueva pasan. Nuevos signposts técnicos fijos sin datos personales. El antiguo caso UI mostró loading después de autenticar, pero no existía una traza para atribuir todo ese tiempo a Keychain: corrección de trabajo redundante verificada, resolución del spinner pendiente de UI.
3. **bae26cf, arnés R:** la selección automática de trabajador cerraba el teclado entre el exists y el tap del botón de ocultarlo durante la segunda atención. Ahora se espera la desaparición real después de escribir DNI. Se conservan R1/R0, saldos, relanzamiento, no duplicación y límite600s; no se relaja la función clínica.
4. **3adfff5, auxiliar:** el perfilado anterior aprobó sus4 recorridos UI, pero las4 capturas fallaron consultando `ps` con timeout5s. No produjo métricas utilizables. Nuevo selector observa el lanzamiento de la app en el log del simulador propio y valida PID/ruta con libproc;8 regresiones locales y probe macOS obligatorio. Conserva binarios y escenarios idénticos en ambos lados; captura activa terminóFAILURE; selecciónPIDfuncionó, pero hubo finalización/exportación incompleta y se perdió el guardado inicial.
5. **48cc3d6, auxiliar:** preparación de empaquetado fijada a0cdc,437Swift/29Native/14UI, Release actual y perfil41555957508. Rechaza fuentes, cuentas, UI, skips, compatibilidad física y presupuestos incorrectos;10 pruebas locales aprobadas. No tiene workflow de IPA habilitado.

## 5. Mediciones antes/después

No son tiempos del iPhone. Workloads SwiftPM Release x86_64 Linux,9.648 trabajadores,1.005 visitas ficticias, mismos datos/host por comparación; compilador excluido del recurso medido. Las variaciones entre ejecuciones no se atribuyen automáticamente al host. Se comparan SHAs concretos, no la modificación del último commit de forma aislada.

### Estado físico v2: c274140 →0cdc760

Diario de sesión en ambos lados; cada operación mantiene lectura, HMAC, AEAD y revisión. Snapshot2.154.425bytes, estado físico completo igual y saldo78. Índice inicial actual76.167ms, separado de consulta caliente. Siete muestras en operaciones habituales, tres en editor/Excel/backup;100 en búsquedas. No se estima p95 de3/7 muestras.

| Operación | Antes p50 ms | Después p50 ms | Reducción | n | p95 antes/después ms | Estado Core |
|---|---:|---:|---:|---:|---|---|
| `allergy_confirmed_encrypted_save` | 5632.766 | 3583.092 | 36.39% | 7 | No medido (n pequeño) | PASS sintético |
| `draft_confirmed_encrypted_save` | 9881.800 | 3289.327 | 66.71% | 7 | No medido (n pequeño) | PASS sintético |
| `form_prepare_9648` | 301.192 | 209.135 | 30.56% | 7 | No medido (n pequeño) | PASS sintético |
| `history_read_1005` | 172.938 | 123.250 | 28.73% | 7 | No medido (n pequeño) | PASS sintético |
| `dashboard_refresh` | 121.670 | 86.884 | 28.59% | 7 | No medido (n pequeño) | PASS sintético |
| `correction_editor_load` | 65.805 | 44.899 | 31.77% | 3 | No medido (n pequeño) | PASS sintético |
| `dispensing_readonly_refresh` | 4809.849 | 297.823 | 93.81% | 3 | No medido (n pequeño) | PASS sintético |
| `inventory_catalog_only` | 1.855 | 1.441 | 22.31% | 3 | No medido (n pequeño) | PASS sintético |
| `worker_search_last` | 0.205 | 0.172 | 16.29% | 100 | 0.216 / 0.191 | PASS sintético |
| `worker_search_common` | 9.482 | 7.823 | 17.50% | 100 | 9.813 / 9.164 | PASS sintético |
| `nursing_98_export` | 10267.755 | 6916.383 | 32.64% | 3 | No medido (n pequeño) | PASS sintético |
| `encrypted_backup_verified` | 19809.617 | 13722.225 | 30.73% | 3 | No medido (n pequeño) | PASS sintético |

Recursos de todo el workload v2, no memoria de la app iPhone: CPU usuario299.07→186.24s; sistema1.41→0.93s; pared300.56→187.20s; picoRSS224272→223516KiB. Los9presupuestos de ratios/CPU/RSS/búsqueda pasaron. La exportación del indicador v2 **No medido**; no se sustituye por una cifra del indicador v1.

### Comparación acumulada v1: cc45aa2 →0cdc760

El adaptador inicial reconstruía diario/núcleo por operación; el actual es de sesión. Se declara esa diferencia y no se presenta como comparación entre las cinco últimas correcciones.

| Operación | Antes p50 ms | Después p50 ms | Reducción | n | p95 antes/después ms | Estado Core |
|---|---:|---:|---:|---:|---|---|
| `allergy_confirmed_encrypted_save` | 14851.965 | 3747.230 | 74.77% | 7 | No medido (n pequeño) | PASS sintético |
| `draft_confirmed_encrypted_save` | 16945.503 | 3839.383 | 77.34% | 7 | No medido (n pequeño) | PASS sintético |
| `form_prepare_9648` | 2490.143 | 276.760 | 88.89% | 7 | No medido (n pequeño) | PASS sintético |
| `history_read_1005` | 7950.516 | 157.256 | 98.02% | 7 | No medido (n pequeño) | PASS sintético |
| `dashboard_refresh` | 4525.554 | 107.413 | 97.63% | 7 | No medido (n pequeño) | PASS sintético |
| `correction_editor_load` | 15844.256 | 55.939 | 99.65% | 3 | No medido (n pequeño) | PASS sintético |
| `dispensing_readonly_refresh` | 9602.374 | 380.041 | 96.04% | 3 | No medido (n pequeño) | PASS sintético |
| `inventory_catalog_only` | 2405.577 | 1.885 | 99.92% | 3 | No medido (n pequeño) | PASS sintético |
| `worker_search_last` | 20.881 | 0.206 | 99.01% | 100 | 21.149 / 0.218 | PASS sintético |
| `worker_search_common` | 20.688 | 9.031 | 56.35% | 100 | 20.838 / 9.170 | PASS sintético |
| `nursing_98_export` | 5021.676 | 2875.013 | 42.75% | 3 | No medido (n pequeño) | PASS sintético |
| `indicator_10_sheets_export` | 10827.684 | 807.419 | 92.54% | 3 | No medido (n pequeño) | PASS sintético |
| `encrypted_backup_verified` | 14880.711 | 12670.156 | 14.86% | 3 | No medido (n pequeño) | PASS sintético |

Recursos completos v1: CPUusuario523.78→122.85s; sistema2.52→1.29s; pared525.96→123.81s; RSS182092→182636KiB. La memoria v1 subió ligeramente; no se afirma mejora en esa métrica.

### Interfaz, Instruments y dispositivo

- Medición UI actual0cdc:2alergiasPASS;5ciclos abrir/cerrar, media5.487s/reloj y2.231s/CPU, memoria absoluta54157.312kB y pico56041.472kB. n5,2trabajadores, automatización incluida; sin baseline comparable no hay mejora UI demostrada. La app funcional usa binarios sellados del mismo HEAD; no se inyectan resultados.
- Comparación activa41555957508 terminóFAILURE: misma máquina Mac, antesC274/después0cdc, dos trabajadores ficticios por escenario, una instancia de Simulator nueva por template para que la revisión realmente se escriba. TimeProfiler yAllocations deben producir trazas/tablas reales; sin captura, métrica No medido.
- Antecedente59e, no certifica0cdc: XCTest de5 ciclos abrir/cerrar formulario,2 trabajadores, media reloj4.993s/CPU2.339s y pico memoria medio55729.357kB. Incluye automatización y cierre; no es tiempo exacto hasta formulario ni guardado. Contadores ciclos/instrucciones0 del simulador no son evidencia de CPUcero. Sin antes comparable no se declara mejora UI.
- iPhone físico: latencia de alergias, inicio/pantallas, CPU, asignaciones y contenedor **No medido**. No se accedió a datos reales.

## 6. Excel, sedes, inventario y Build14

Swift437 y las comparaciones oficiales TS/Swift pasaron para ambos libros. El indicador conserva10hojas y solo incluye visitas con las verificaciones necesarias; una sede pendiente se confirma explícitamente en esa atención, no cambiando repetidamente la ficha laboral, duplicando visita ni moviendo stock. R=0 sigue representando consumo clínico de presentación abierta; no se convierte en ausencia de tratamiento. La rectificación histórica R no genera segundo descuento físico ni exige motivo escrito obligatorio.

La prueba del candidato lee diario y respaldo cifrado producidos por el **código original9b1da6d**, persiste una rectificación, genera/lee el respaldo nuevo y comprueba stock, trabajadores y visitas originales iguales. Todos los flags relevantes sontrue;physicalDeviceValidatedfalse. Compatibilidad hacia delante aprobada con datos ficticios; no certifica la actualización física por firma iLoader ni que una Build14 pueda leer campos nuevos de Build15.

Bundle ID permanece **pe.danper.saludmovil.native.iloaderpreview**; Release0.4.2/build15, ARM64, mínimoiOS17, sinfirma, sin datos clínicos ni reloj de prueba. Se verificaron22 hashes de archivos originales. Compilar Release no autoriza distribución con UI pendiente.

## 7. Fallos conservados y pendientes

- **59e, run41528135555: FAILURE definitivo.** Swift433/Native28/JS62/Py33/Excel/compat/benchmarks aprobaron. UI14ejecutados:11PASS/3FAIL/0SKIP; además el cierre obsoleto13 falló en todos los shards. No se ocultan los tres fallos reales: loading tras autenticar, carrera del teclado en segunda atención y activación de CoreAuthUI -1000 con consulta AXagotada antes de match. La invalidación LA registrada volvió en milisegundos; no se declara bloqueo de147s en invalidate. El tercer problema sigue sin causa completamente demostrada hasta repetir UI.
- **41535822144: FAILURE.** Cuatro recorridos UI aprobados, cuatro capturas sin PID/trace; noCPU/alloc antes/después disponible. Se conserva el fallo, nuevo selector no se declara aprobado solo por sus tests.
- Los antiguos errores SwiftPM139 ocurrieron en planificación antes de casos; causa exacta no establecida para todos. No se borran ni se renombran como PASS. Los resultados nuevos de437pruebas no reescriben esos logs.
- UI14 terminó11PASS/3FAIL; cierre finalSKIPPED por dependencia fallida; perfil activoFAILURE. No hay aprobación integral niIPA.
- No se afirma haber medido cada botón/selector/render del mapa estático. Los escenarios de UI perfilada tienen2trabajadores; la carga9648 se mide en Core. Reproducir ese volumen con Instruments de UI sigue siendo una limitación.
- Ningún cambio requiere reiniciar bóveda, reimportar historia, generar stock, repetir consumos o eliminar Trabajadores. Si la validación actual detecta regresión se conserva su fallo y se corrige antes de IPA.

## 8. Workflows y artifacts verificables

- [Actual0cdc: Linux, Xcode, UI, Excel, benchmarks, compatibilidad y cierre](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41552268684).
- [Actual0cdc: ReleaseARM64; orquestaciónf73e251](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41552987131).
- [Comparación activaC274→0cdc; orquestación3adfff5](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41555957508).
- [Focalizado0cdc:4Swift+37Python, no aprobación de App completa](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41542632575).
- [59e definitivo FAILURE, no aprobación de0cdc](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41528135555).
- [Perfil anterior FAILURE sin capturas](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41535822144).

Artifacts actuales, sinIPA:

- [Swift437](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41552268684/artifacts/13191974645).
- [JS62 e inventario estático](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41552268684/artifacts/13192043006).
- [Xcode nativas29 y preflights](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41552268684/artifacts/13194146589).
- [Binarios sellados del mismoHEAD](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41552268684/artifacts/13194101507).
- [Benchmark v1 y compatibilidad Build14](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41552268684/artifacts/13192734796).
- [Benchmark físico v2 y9presupuestos](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41552268684/artifacts/13193368750).
- [ReleaseARM64 identidad NOIPA](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41552987131/artifacts/13192689008).

## 9. Distribución e iLoader

**IPA: no generada. No actualizar aún con un candidato no aprobado.** Los artifacts de compilación/pruebas enlazados no son IPA instalable. El helper auxiliar no tiene trigger de distribución y exige todos los gates actuales y la comparación activa válida. El packager antiguo de Build14 no se usa para15.

Cuando exista una IPA aprobada: verificar antes un respaldo cifrado reciente de14 y conservar la contraseña fuera del iPhone; usar el mismo AppleID/equipo de firma y BundleID; actualizar sobre la app existente **sin desinstalar, borrar ni reimportar atenciones antiguas**. Detenerse si iLoader propone una app nueva/identidad diferente o si aparecen datos vacíos. Comprobar trabajadores, historial, alergias, borradores y saldo compartido Fundo/Planta. La conservación del contenedor físico depende también de la identidad de firma y no queda certificada por Simulator; no se garantiza downgrade.

## 10. Commits publicados desde el HEAD real de auditoría

- `40791229751b9a2dfed4c38c14a015895d595776` — perf(search): narrow roster substring candidates with session-owned posting lists
- `69e75adb818ef9dd1d1551fa83c0c062e2f6e3b3` — ci(b15): isolate Instruments, prepare cold auth UI and reduce redundant XCTest queries
- `911e49eddbd30219c825461df1fab80e214acc8e` — ci(auth): subscribe to diagnostic stream before observing cold UI launch
- `9143997ddab5fe31b50fc540fb2e3dc50a451434` — perf(inventory): avoid rebuilding clinical roster for catalog-only and read-only dispensing actions
- `c274140aa631a7e9c262381dbff3f6a1f9a62582` — ci(b15): budget cold simulator setup and scope Instruments to owned device
- `bdc27f1ef6778d64568ada971729ba5d330e9a68` — perf(v2): share complete snapshot audits through drafts, dispensing, backups and nursing reads
- `df109381d02f9e00e01c59935c714e96ca027247` — test(ios): keep picker taps above fixed footer and validate on native ARM64 runners
- `e909ca6269fe3d8ae703b55683ccffb59544db13` — test(perf): require large v2 physical stock comparison and preserve measured failures
- `6f74d66e8c327d96e7a9bcbae049eb67e706519d` — test(v2): use the journal's required synthetic-only temporary namespace
- `67c4ec8d8d7a382471945e88a59f3e499a11f555` — fix(ci): let LocalAuthentication own CoreAuthUI lifecycle and retain genuine sensor checks
- `98c0dab7f7e8138b799062d5aefc894bcafefd9e` — test(ios): dismiss keyboard before locating form actions and recover recorded installer helper failure
- `eeea540c94b6023684f56598c709cd8498d9bff8` — test(ios): bound genuine policy cancellation preflight and avoid repeated modal keyboard queries
- `7524c1b48ae27ac3f1a8a4ea857484fa61713ef3` — test(ios): await real policy cancellation asynchronously without blocking main
- `799dc5f9a2812ed01f82ed28c78eb90d0750e09f` — test(ios): fail policy preflight explicitly when availability is denied
- `9a4cad1d1463eee5b0ae118b3c14fe58b73a7710` — test(ios): isolate genuine policy cancellation in an active MainActor test window
- `bcbf7a0ff07d6bcaa745c52e6acf804e03d208dc` — test(perf): guard measured Core gains, query p95 and memory with seven regressions
- `7bfde6c3262cc29c29632eea013f078fd7728a7d` — test(ci): prepare real Face ID consent sequencing, strict 14-case UI evidence and Core budgets
- `0ed08d514763c30f1d631ffd1d22456111d91a0b` — docs: record observed Face ID consent root cause and verified unchanged cancellation trial
- `59e6773dafdc2e08d291bd7e33b5c6ffd685f1fd` — test(b15): bound actual delayed Face ID consent acknowledgement and record timing
- `787b3ad5159de487b76c5a3900268cb8cef6b55b` — fix(ci): validate actual 14-case UI inventory and selectors; regress real shell closure
- `1419703700007e4f4add28aec8ebf5453fa5694b` — chore(ci): preserve original validation script file mode
- `9a283632b8f6b9e064c8b54f4dac9173197b1374` — perf(startup): defer protected inspection until active and avoid Keychain only for confirmed empty storage
- `bae26cf116eef116cf0830cba4e706d1e9186f9b` — fix(ios): verify clinical revision after active unlock and await automatic DNI keyboard dismissal
- `0cdc76048db778a6561a237fcb46d63d168a4f7c` — test(storage): retain fail-closed inspection for substituted and dangling source roots

Auxiliares nuevos, sin fusionar ni cambiar main:

- `3adfff513c09decb33430e2d767af0c32477cd15` — selección de PID propio y captura activa comparativa.
- `48cc3d6accf5e567a45edae9311df65660496d5c` — preparación de guardas de distribución0cdc, sin trigger niIPA.

Los JSON adjuntos son evidencia cruda del HEAD indicado. La fixture de empaquetado es ficticia y está en otra rama: no forma parte de esta evidencia medida.


## Cierre de interfaz y mediciones complementarias

| Suite0cdc | PASS | FAIL | SKIP |
|---|---:|---:|---:|
| Build222Shell |1|0|0|
| AllergySave |2|0|0|
| GlassClinical |3|0|0|
| Biometric |2|0|0|
| Menu |1|0|0|
| PremiumRedesign |1|1|0|
| N3demo |1|1|0|
| N3protected |0|1|0|

Los campos previos de diagnóstico/contexto de este informe reflejan el estado de evaluación inicial; esta tabla y workflows-snapshot.json cierran el resultado real, sin ocultar fallos. Los cambios posteriores están en4daba/docs/build15-performance/UI_TRANSITION_EVIDENCE.md.

La exportación auxiliar41557902626 SUCCESS recuperó173filasStatistics y85496filasAllocationList del Inicio ficticio0cdc. Heap+VM:14682432bytes persistentes,15078480bytes asignados totales,85496asignaciones persistentes. No son fugas demostradas, RSS ni costo de alergias; categorías solapadas no se suman. Artifact13196690048.

El análisis parcial del perfil41555957508 encontró31marcadores de posible bloqueo antes y44después (no se afirma mejora):256.773–11801.324ms y255.193–2806.671ms. Requieren correlación con stacks de automatización/AX/UI. Los intervalos completos del journal no representan el botón: el caso guardó a01:20:34UTCantes de que TimeProfiler iniciara01:20:44; después guardó01:44:22UTCantes de que iniciara01:44:25. Falta por diseño una sincronización entre recorder y recorrido. La latencia de guardado SwiftUI en esas trazas es **No medido**, no cero. Los4recorridos UI sí aprobaron; dosTimeProfilertraces existen, baselineexportCPUagotado y ambasAllocationsdetenidas por timeout tras Target app exited/Stopping recording. Artifact13198113880 conserva evidencia parcial; no se cambia suFAILURE.

Los nuevos JSON incluyen resúmenes UI actuales, métricasXCTest y datos de ambas trazas parciales. No reemplazan la obligación de probar4daba. La preparación de empaquetado48cc3d6, fijada a0cdc, ahora falla deliberadamente si se intenta usar con4daba; no se habilitó distribución.
