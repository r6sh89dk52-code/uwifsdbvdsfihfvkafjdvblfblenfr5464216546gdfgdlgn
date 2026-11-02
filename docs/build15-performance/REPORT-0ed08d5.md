# Build 15: cierre de 0ed08d5

**FAILURE. No aprobación integral y ninguna IPA.** Fuente evaluada: `0ed08d514763c30f1d631ffd1d22456111d91a0b`. El siguiente candidato es `59e6773dafdc2e08d291bd7e33b5c6ffd685f1fd`, con pruebas frescas pendientes. No se reutiliza esta evidencia para aprobarlo.

Auditoría iniciada desde HEAD real `90cb0aba7b553e536c9d3ad42d65eae9f7890fd5`. Se conservan todas las optimizaciones publicadas. Build14 estable `9b1da6d4cdead4729bcade6843abcbcfc287e870`, main y el teléfono permanecen intactos. PR10 borrador, sin fusionar. Los cambios y causas de producción, módulos y regresiones están documentados en [AUDIT.md](AUDIT.md). Su inventario estático de56 archivos App/414 sitios de acción no equivale a ejecutar todos los botones.

## Resultado de las comprobaciones de esta fuente

| Comprobación | Resultado |
|---|---|
| Swift Core |433 aprobadas, 0 fallos, 0 omisiones |
| JavaScript |62 aprobadas, 0 fallos |
| Python/verificadores |33 aprobadas, 0 fallos |
| Excel oficiales |PASS indicador10 hojas/19 tablas/432 materiales y enfermeras98 productos |
| Disponibilidad FaceID nativa |1 aprobada |
| Preparación UI permiso FaceID |0 aprobadas, 1 fallo, 0 omisiones |
| Suite completa28 nativas |No ejecutada: bloqueada por permiso |
| Suite14 UI |No ejecutada: dependencia fallida |
| Core v1/v2 y9 presupuestos v2 |PASS con9648 trabajadores/1005 atenciones ficticias |
| Compatibilidad cifrada desde código original Build14 |1 aprobada, 0 fallos |
| Release iPhoneOS ARM64 |PASS;22 hashes originales verificados |
| Instruments activo antes/después |No ejecutado: falta binario con todas las nativas aprobadas |
| Gate final / IPA |No aprobado / no generada |

No se sustituye el fallo con el trial anterior41516039780: aquel aprobó una preparación y una cancelación, sin aprobar toda esta fuente.

## Fallo observado y corrección siguiente

El registro ubica el fallo en la espera de desaparición del aviso TCC, `N2BiometricInteractionTests.swift:47`. Toque de Permitir a t55,20s; espera de5s insuficiente. El vídeo del artifact nativo muestra el aviso todavía visible hacia t70s y ausente hacia t78s: persistió más de15s después del toque y desapareció hacia23s. La captura final muestra acceso clínico bloqueado, sin identidad autenticada.

El commit59e6773 cambia únicamente esa espera acotada a30s y registra su duración. Conserva la verificación de desaparición, gate real, ausencia de acceso clínico y cero eventos biométricos. App/Sources/NativeTests/project.yml idénticos0ed→59e. La prueba nativa original mantiene cancelación12s/espera18s. Este ajuste requiere validar el nuevo SHA: gate41528135555, Release41528249741. El aviso del sistema tiene latencia propia; no se presenta esto como una mejora de velocidad de la app.

## Rendimiento Core v2: evidencia actual

Mismo job Linuxx86_64, SwiftPM Release, baselinec274140→0ed08d5,9648 trabajadores/1005 atenciones ficticias; ambos con journal/core de sesión y HMAC/AEAD/lectura/revisión en cada operación. Compilación excluida de las métricas del workload. No son tiempos SwiftUI, botón ni iPhone físico. Medianas con3/7 muestras; no se calcula p95 de esas muestras escasas. Búsquedas100 muestras.

| Acción Core | Antes p50 ms | Después p50 ms | Reducción | n |
|---|---:|---:|---:|---:|
|allergy_confirmed_encrypted_save|5699.738|3793.944|+33.44%|7|
|draft_confirmed_encrypted_save|9933.533|3816.855|+61.58%|7|
|form_prepare_9648|269.378|277.631|-3.06%|7|
|history_read_1005|159.997|162.021|-1.27%|7|
|dashboard_refresh|105.416|109.625|-3.99%|7|
|correction_editor_load|56.636|60.645|-7.08%|3|
|dispensing_readonly_refresh|4915.219|391.513|+92.03%|3|
|inventory_catalog_only|1.857|1.868|-0.62%|3|
|worker_search_last|0.215|0.214|+0.38%|100|
|worker_search_common|9.513|9.477|+0.38%|100|
|nursing_98_export|10427.474|8185.318|+21.50%|3|
|encrypted_backup_verified|20635.526|16806.224|+18.56%|3|

Reducciones negativas no se etiquetan como mejoras. Variaciones pequeñas y3 muestras no prueban causalidad ni una regresión de producción, pero se conservan. No hubo cambios productivos en los commits de preparación del permiso.

Último trabajador:p95 0,227→0,225ms; nombre común:p95 9,686→9,920ms. CPUusuario304,43→208,76s;wall306,19→209,61s;RSS223528→222996KiB. Los9 límites Core aprobaron. Datos/muestras/recursos adjuntos.

La comparación v1 cc45aa2→0ed mide el efecto acumulado de índices/ciclo de sesión/otras optimizaciones; no se atribuye al último cambio UI. Son13 operaciones, incluido el indicador diez hojas: ver v1-comparison.json.

| Acción de aplicación/dispositivo | Antes | Después | Estado |
|---|---|---|---|
| Guardar alergias, toque→confirmación visual |No medido |No medido |Captura activa pendiente |
| Abrir/transicionar pantalla en iPhone físico |No medido |No medido |Sin acceso al dispositivo |
| Consultar Kardex, interfaz completa |No medido |No medido |No confundir con Core |
| Allocations del recorrido actual |No medido |No medido |Sin captura válida |

## Módulos auditados y límites

Inicio/autenticación/navegación; nueva atención y sus4 pasos, alergias/medicamentos/autosave; trabajadores/búsqueda/ficha/antecedentes; historial y rectificacionesR/sede; inventario físico/Kardex compartido/corte9–8; indicador10 hojas/Kardex98; importación/exportación; respaldos/restauración; bóveda, concurrencia y cachés de sesión. AUDIT.md describe componentes, causas, cambios y pruebas. La UI de esta fuente no se ejecutó completa: no se declara validación de todos los botones.

## Integridad y actualización

El fixture v2 conserva todo el estado físico y saldo78 antes/después (conteo70+ingreso10−salida2), con9648 trabajadores/1005 atenciones. No equivale a miles de movimientos físicos ni98 stocks no cero. El ensayo de compatibilidad usa archivos realmente producidos por código Build14 original: journal y backup leídos, R1→R0 histórica persistida, nuevo respaldo verificado, stock/trabajadores/atenciones originales intactos. Fuente0ed y productor9b1 figuran en compatibility.json. No se accedió al teléfono ni se certificó migración física/downgrade.

Release:BundleID `pe.danper.saludmovil.native.iloaderpreview`,0.4.2/build15/iOSmínimo17/ARM64, sin firma/datasets clínicos/reloj de prueba.22 hashes exactos verificados. Igual BundleID no garantiza conservación del contenedor con otro equipo de firma.

**No instalar esta fuente fallida.** Cuando exista candidato aprobado: respaldo cifrado reciente de14 verificado y contraseña fuera del teléfono; mismo AppleID/equipo de firma/BundleID; actualizar sobre la app existente sin desinstalar/borrar/reimportar historia. Detenerse si iLoader propone otra instalación/identidad o aparecen datos vacíos. No se garantiza volver a14.

## Workflows y evidencia

- Gate completo41521115084:FAILURE. Fuente0ed08d5. Swift/JS/Python/Excel/performance/compatPASS; permisoUIFAIL; suite nativa/UI/Instruments/final bloqueados.
- Release41521323672:SUCCESS. Workflowc6363720470be289430e0085beef18c51b85062e, fuente real0ed08d5. Artifact13178206861.
- Comparación activa41523046901 y41523194683:FAILURE al exigir binarios con nativas completas. Cero journeys/capturas; JSON vacíos no son métricas.
- Siguiente gate41528135555/Release41528249741:fuente59e6773, pendientes al redactar.

- [Workflow 41521115084](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41521115084)
- [Workflow 41521323672](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41521323672)
- [Workflow 41523046901](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41523046901)
- [Workflow 41523194683](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41523194683)
- [Workflow 41528135555](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41528135555)
- [Workflow 41528249741](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41528249741)
- [Artifact Swift](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41521115084/artifacts/13178955547)
- [Artifact JS](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41521115084/artifacts/13177842443)
- [Artifact Nativo/vídeo](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41521115084/artifacts/13178383336)
- [Artifact v1/compatibilidad](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41521115084/artifacts/13178536732)
- [Artifact v2/presupuestos](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41521115084/artifacts/13177903840)
- [Artifact Release ARM64, NO IPA](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/41521323672/artifacts/13178206861)

No existe enlace de IPA: no se generó.
