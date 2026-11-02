# DANPER Build 15 — auditoría de rendimiento de c274140

Estado de esta edición: validación UI en curso; **no versión aprobada y sin IPA**. Este informe se actualizará con las conclusiones de las ejecuciones enlazadas. Fecha: 2 de noviembre de 2026, UTC.

## Identidad y continuidad

- HEAD real encontrado al retomar: `90cb0aba7b553e536c9d3ad42d65eae9f7890fd5`, posterior al cc45aa2 citado por la solicitud.
- HEAD candidato: `c274140aa631a7e9c262381dbff3f6a1f9a62582`.
- Rama: `fix/indicator-historical-visit-site-build15-20261030`; [PR #10](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/pull/10), borrador, sin merge. Su base estable Build 14 permanece en `9b1da6d4cdead4729bcade6843abcbcfc287e870`.
- Los resultados de SHAs anteriores solo sirven para diagnóstico/comparación, nunca para certificar el candidato.
- Este documento y sus JSON se guardan en una rama auxiliar de evidencia; no modifican el HEAD de la aplicación.

## Cambios nuevos publicados en la rama de aplicación

| Commit | Cambio |
|---|---|
| [4079122](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/commit/40791229751b9a2dfed4c38c14a015895d595776) | Índice de búsqueda por fragmentos de dos caracteres; candidatos del fragmento menos frecuente, verificación completa de subcadena, Unicode, orden y límites. Dos regresiones Swift, incluida carga 9.648 y último registro. |
| [69e75ad](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/commit/69e75adb818ef9dd1d1551fa83c0c062e2f6e3b3) | Separación del perfilado y pruebas UI; selección del proceso propio con cuatro regresiones de aislamiento; preparación del servicio CoreAuthUI y reducción de consultas XCTest repetidas. |
| [911e49e](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/commit/911e49eddbd30219c825461df1fab80e214acc8e) | Suscripción al log antes de arrancar CoreAuthUI para observar su evento inicial. |
| [9143997](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/commit/9143997ddab5fe31b50fc540fb2e3dc50a451434) | Un contexto de formulario al revisar consumos; catálogo estático directo en registro auxiliar y asociación operativa. Trece operaciones de benchmark y equivalencia de catálogos. |
| [c274140](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/commit/c274140aa631a7e9c262381dbff3f6a1f9a62582) | Presupuesto global UI45/Instrumentos35 minutos y cuatro runners independientes; xctrace selecciona el UDID del simulador propio. Los límites XCTest y las aserciones clínicas permanecen. |

Las optimizaciones anteriores de bóveda, alergias, borradores, exportación y sede histórica se conservaron. El error de vinculación opcional y la aceptación de sede vacía ya estaban corregidos en e0f4dcc antes de retomar; no se atribuyen a los cinco commits nuevos.

## Mapa de módulos y acciones

[Inventario estático](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/blob/c274140aa631a7e9c262381dbff3f6a1f9a62582/docs/build15-performance/action-inventory.json): 56 archivos Swift de App y 414 sitios de acción detectados. [Análisis de recorridos](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/blob/c274140aa631a7e9c262381dbff3f6a1f9a62582/docs/build15-performance/AUDIT.md). Un inventario estático no acredita que se haya pulsado cada combinación de controles ni medido cada acción.

| Módulo | Acciones y causa revisadas | Solución o resultado |
|---|---|---|
| Inicio/sesión/navegación | Apertura, Face ID, panel, contadores, pestañas, bloqueo y segundo plano; recuperaciones duplicadas para datos pequeños | Revisión y contadores en una lectura autenticada; refresco excluyente; descarte de sesión y ocultación clínica al bloquear/segundo plano. Apertura física no medida. |
| Nueva atención | Formulario, trabajador, evaluación, tratamiento, resultado, procedimientos, medicamentos, aperturas R, confirmación | Preparación/contexto desde una revisión; catálogos y controles clínicos conservados. Menos contexto redundante al revisar consumos. |
| Alergias | Guardar, commit cifrado, refresco, error, revisión clínica y autosave simultáneo | Confirmación real de persistencia; actualización COW de una alergia y revisión sin reconstruir padrón. Fallo visual posterior distinguido del commit. Revisión modificada sin confirmar bloquea tratamiento. |
| Borradores | Debounce, etapas, cerrar/reabrir, recuperación y conflictos | Guardado optimista/deduplicación, etapa capturada con formulario, reintento acotado ante revisión obsoleta, reprogramación tras fallo de alergias. No se elimina el borrador para ganar velocidad. |
| Trabajadores | DNI/nombre, directorio, alta, ficha e historial; 9.648 registros | Cero resultados sin consulta; debounce y búsqueda fuera del hilo principal; 25 resultados por página/cinco sugerencias. Índice en memoria de sesión; sin índice clínico persistido en claro. Alta y corrección laboral conservadas. |
| Inventario/Kardex | Consolidado, búsquedas, conteos, ingresos, consumos, movimientos, vencimientos, R1/R0, corte9–8, filtros y Excel98 | Conserva cálculo físico, desconocidos, contabilidad y períodos. Las dos acciones auxiliares que solo necesitan catálogo dejan de construir trabajadores/alergias/lotes completos. |
| Historial | DNI/nombre, fechas, detalle, tratamiento, edición, R, sede y retorno | Incidencias por visita, contexto único de editor, actualización de una atención; firmas de rectificación preservadas; sin segundo descuento físico. |
| Indicador/Excel | Períodos/sedes, validación, diez hojas, compartir | Sede histórica explícita por atención, sin copiar automáticamente la ficha actual. Exportaciones usan la rectificación; no duplican visita ni alteran stock. Escritura protegida del archivo fuera de MainActor. |
| Respaldos/importar/restaurar | Bóveda, revisiones, cifrado, verificación, archivos, estado tras restaurar | I/O en actor dedicado; security scope, límite42MB, archivos regulares sin symlinks, protección completa y escritura atómica. Admisión de fuentes nuevas conserva auditoría completa. |
| Diagnósticos/catálogos/procedimientos/vigilancia | Búsquedas, selectores, validación y reportes | Rutas y validaciones conservadas; se aplican mejoras compartidas de bóveda y archivos. No se atribuyen tiempos individuales sin medición. |

Cada recuperación sigue leyendo archivo y comprobando HMAC, AES-GCM/AAD y SHA. Solo se reutilizan auditorías semánticas para bytes descifrados exactamente iguales a una generación ya auditada, con máximo dos entradas de8MiB por diario. Cada actor/dominio mantiene su sesión y comprueba Keychain por llamada. Los cambios de datos no heredan automáticamente la prueba anterior. Las escrituras mantienen revisión y serialización; la prueba nativa de16 escrituras acepta una y rechaza quince obsoletas.

## Mediciones incrementales: trabajo nuevo frente al HEAD real de entrada

[Run41366898067](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41366898067), [artefacto exacto](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41366898067/artifacts/13107787602). Comparación90cb0ab→c274140, Swift6.0.3 Release/Linux x86_64, mismos9.648 trabajadores/1.005 atenciones ficticias, stock/movimientos/alergias/borrador. Ambos conservan el diario/core de sesión que ya existía al retomar. El diff del arnés reproduce únicamente las dos rutas previas de contexto/catálogo; no cambia archivos de App. No es latencia de iPhone o SwiftUI.

| Acción Core | Antes p50 ms | Después p50 ms | Reducción | n |
|---|---:|---:|---:|---:|
| Guardar alergias confirmado | 2208.444 | 2232.858 | -1.1% | 7 |
| Guardar borrador | 3604.508 | 3549.845 | 1.5% | 7 |
| Preparar formulario | 171.788 | 167.111 | 2.7% | 7 |
| Leer historial | 97.121 | 101.009 | -4.0% | 7 |
| Contadores de Inicio | 67.210 | 77.502 | -15.3% | 7 |
| Abrir editor histórico | 34.626 | 39.236 | -13.3% | 3 |
| Revisar consumos | 362.792 | 275.986 | 23.9% | 3 |
| Catálogo auxiliar de inventario | 135.236 | 1.067 | 99.2% | 3 |
| Buscar último trabajador | 4.767 | 0.126 | 97.4% | 100 |
| Búsqueda común | 5.398 | 5.541 | -2.7% | 100 |
| Excel enfermeras 98 | 1710.779 | 1682.515 | 1.7% | 3 |
| Indicador diez hojas | 499.243 | 515.840 | -3.3% | 3 |
| Respaldo cifrado verificado | 7606.113 | 7548.135 | 0.8% | 3 |

Reducción negativa significa que el tiempo observado aumentó. No se declara significación estadística ni mejora de las rutas no cambiadas con3/7 muestras. Todos los blobs Core salvo N2SearchIndex son idénticos entre90cb0ab y c274140, incluidos contadores/correcciones; esto no elimina los tiempos más altos observados. Alergias no demuestra mejora incremental: su optimización principal ya estaba publicada.

Búsquedas100 muestras: último trabajador p95 4,821→0,132ms; común5,794→5,701ms. Construcción del índice23,706→52,180ms (una preparación por lado, separada de consultas): coste adicional28,474ms. No se inventa p95 con3/7 muestras.

Workload preparado sin compilador: CPU usuario83,47→82,78s; sistema0,79→0,87s; wall84,12→83,54s; RSS184.116→184.368KiB (+252KiB). Incluye Core/XCTest/SwiftPM, no RAM de iPhone.

## Mediciones acumuladas de Build 15

[Run41366450170](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41366450170), [artefacto exacto](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41366450170/artifacts/13107862907), [lectura independiente](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41367997728). Comparación cc45aa2→c274140 en el mismo runner y workload. Incluye mejoras ya publicadas antes de esta continuación; no se atribuye toda la ganancia a los cinco commits nuevos. El adaptador inicial creaba el diario por llamada; el candidato lo conserva durante la sesión manteniendo verificaciones criptográficas.

| Acción Core | Antes p50 ms | Después p50 ms | Reducción | n |
|---|---:|---:|---:|---:|
| Guardar alergias confirmado | 10455.455 | 2461.241 | 76.5% | 7 |
| Guardar borrador | 11646.698 | 4032.561 | 65.4% | 7 |
| Preparar formulario | 1694.878 | 218.528 | 87.1% | 7 |
| Leer historial | 5118.210 | 129.825 | 97.5% | 7 |
| Contadores de Inicio | 3005.833 | 87.566 | 97.1% | 7 |
| Abrir editor histórico | 10267.902 | 47.349 | 99.5% | 3 |
| Revisar consumos | 6116.351 | 312.839 | 94.9% | 3 |
| Catálogo auxiliar de inventario | 1532.162 | 1.145 | 99.9% | 3 |
| Buscar último trabajador | 12.198 | 0.125 | 99.0% | 100 |
| Búsqueda común | 12.687 | 6.140 | 51.6% | 100 |
| Excel enfermeras 98 | 3092.068 | 1834.795 | 40.7% | 3 |
| Indicador diez hojas | 6755.166 | 590.074 | 91.3% | 3 |
| Respaldo cifrado verificado | 9381.764 | 8212.863 | 12.5% | 3 |

CPU usuario348,82→92,22s; sistema1,23→0,94s; wall349,97→92,96s; RSS178.440→181.492KiB. Construcción del índice candidato52,821ms. Muestras completas en el artefacto y resúmenes JSON junto a este informe.

## Pruebas actuales y Excel

| Control de c274140 | Estado verificado en esta edición |
|---|---|
| Swift Linux | 430 PASS, 0 FAIL, 0 SKIP;424,399s de XCTest |
| TypeScript/JavaScript | Compilación y62 controles PASS |
| Python de aislamiento/evidencias | 19 PASS |
| Xcode16.4/iOS18.5/iPhone16 | Compilación real SwiftUI PASS; preflight1PASS y27 pruebas nativas PASS, 0fallos/omisiones |
| UI funcional | Ocho suites/13 casos en curso, sin certificación adelantada |
| Benchmark |13 operaciones y aserciones de integridad PASS |
| Compatibilidad cifrada Build14 |1PASS,0 FAIL |
| IPA | No generada |

Indicador: diez hojas,19 tablas y432 materiales; comparaciones TS/Swift de contenidos/fórmulas originales PASS. Kardex enfermeras:98 filas/siete columnas verificadas, fórmulas/celdas combinadas/impresión PASS. La suite incluye sede histórica, rectificaciónR1→R0, una atención visible, conservación física, aperturas desconocidas y cortes mensuales.

La prueba de compatibilidad usa archivos cifrados producidos por código original congelado Build14 `9b1da6d`. El candidato abre diario/respaldo, guarda alergias y rectificación histórica, verifica respaldo nuevo y conserva stock/trabajadores/atenciones originales. Es compatibilidad hacia delante con datos ficticios; no certifica el contenedor del iPhone ni que Build14 interprete todos los campos nuevos al volver atrás.

## Perfilado de interfaz e Instruments: límites reales

En9143997, dos casos UI de alergias pasaron, pero su job terminó CANCELLED al límite global30min; no se presenta verde. El límite global ahora es45min; las aserciones y tiempos de cada caso no se ampliaron.

Ese caso midió cinco ciclos abrir/cerrar formulario con dos personas ficticias: media reloj5,803s, CPU3,011s, memoria física máxima media55.810,458kB. Incluye automatización; no tiene comparación UI previa, no equivale a latencia del botón Guardar ni prueba UI de9.648. Ciclos/instrucciones cero del simulador: **No medido**. Estas cifras anteriores no certifican el nuevo HEAD.

Instruments sin selección de dispositivo no encontraba un PID real propio (salida21). El diagnóstico con UDID explícito [41364605278](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41364605278) grabó ambas plantillas sobre app9143997 intacta; [trazas](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41364605278/artifacts/13106878239). El [exportador](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41367056032) encontró cuatro stackshots, cero filas ponderadas de time-profile y ningún dato cuantitativo CLI de asignaciones en Inicio inactivo. No prueba cero CPU ni ausencia de bloqueos.

El candidato tiene su captura propia de Inicio y un [diagnóstico activo separado](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41368239478) que espera y verifica los binarios exactos de c274140, ejecuta el recorrido ficticio de guardar alergias bajo cada plantilla y conserva el diff del arnés. Esos tiempos incluyen sobrecarga de Instruments y no sustituyen la certificación UI sin perfilador. Sus resultados están pendientes en esta edición.

Arranque frío físico, latencia completa de guardado en iPhone, todas las combinaciones de414 sitios, distribución de asignaciones por acción y conservación física del contenedor: **No medido/no validado** cuando no exista evidencia concreta posterior.

## Fallos anteriores, entorno y trazabilidad

- 41110840235: FAILURE real de Xcode por if-let sobre valor no opcional.
- 41110840139: FAILURE definitivo de Linux,422 pruebas con aserción real por sede vacía. Ambos ya corregidos antes de retomar.
- [Historial de17 fallos Linux](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/blob/c274140aa631a7e9c262381dbff3f6a1f9a62582/docs/build15-performance/previous-linux-failures.json):15 aserciones de sede, una sintaxis y un crash139 interno de planificación SwiftPM antes de pruebas. La causa ambiental exacta de ese crash no está demostrada.
- 41173716294 en90cb0ab: FAILURE;428Swift/27nativas/JS62/Python15/Excel/rendimiento/compatibilidad PASS, UI9PASS/4FAIL. Logs: CoreAuthUI después de watchdog5s, formulario aún en Inicio y recorridoR agotando600s. Se conservan los fallos y se corrigen sus causas concretas.
- 41359698220/41359782656/41360378278: sustituidos al publicar nuevos commits; resultados anteriores no certifican c274140. La captura9143997 falló y su job UI de alergias fue cancelado pese a casos aprobados.
- 41366834869: workflow auxiliar no inició jobs por contexto runner.temp inválido a nivel de entorno del job. Corregido en41366898067, que terminó SUCCESS. No fue fallo de código clínico.
- La comprobación local de identidad inicialmente usó el valor Build14 por defecto; al establecer DANPER_EXPECTED_BUILD=15 pasó. GitHub actual ejecutó y aprobó los62 controles con Build15. El entorno local se desconectó después; el trabajo y las pruebas continuaron en GitHub.

## Datos, distribución y actualización

Se conserva Bundle ID `pe.danper.saludmovil.native.iloaderpreview`, servicios Keychain, esquema/diario v2 y codec de respaldo. No se reinicia inventario, importa/descuenta automáticamente historial, convierte pendientes en verificados ni accede al iPhone real. Build14 instalada y main permanecen intactos.

El empaquetador anterior verifica ARM64 iPhoneOS, mismo Bundle ID, lanzamiento a pantalla completa, recursos aprobados sin datasets clínicos/fixtures de prueba, ausencia de reloj de tests y de firma/perfil embebidos, manifiesto y SHA-256. Está fijado a Build14; no se ejecuta ni se usa para declarar una IPA15 aprobada.

**Sin IPA de Build15 en esta edición.** No actualizar ahora. Para una futura entrega aprobada: conservar el respaldo cifrado original de Build14 y su contraseña fuera del iPhone; verificar el paquete y su SHA, mismo Bundle ID y misma identidad/cuenta de firma en iLoader; actualizar sobre la instalación existente sin desinstalar. Si iLoader propone otra identidad o una app separada, detenerse. Al abrir, comprobar historial, borrador, alergias, conteos, ingresos y saldos; no reimportar ni volver a descontar atenciones para resolver una actualización. La conservación real del contenedor depende además de la firma/provisión de iLoader y no se garantiza con Simulator.
