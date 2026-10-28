# DANPER Salud Móvil — aceptación local del Kardex v2

Fecha: 27-10-2026, America/Lima.

**Implementación local completada y validada con datos ficticios.** Rama `feat/swiftui-premium-kardex-simple-v2`; código validado `e5999791d52168e3c56a1981328d1dd2fd12eec9`. El commit posterior incorpora esta acta y actualiza la guarda estructural de origen de evidencias; no cambia el binario validado. No se hizo push, merge, IPA, instalación física ni transición sobre datos reales.

Repositorio: `/Users/felipeazcarate/Downloads/DANPER-N2-Paridad`.

## Resultado funcional

Se implementó inventario consolidado por código y unidad originales, compartido entre Fundo y Planta. Las unidades descuentan cantidades clínicas reales; las presentaciones usan declaración explícita R=1/R=0. No se seleccionan lotes, calculan volúmenes internos ni cierran envases automáticamente.

La activación requiere respaldo completo cifrado, lectura/descifrado y validación, disponibilidad del archivo guardado, confirmación explícita y autenticación del sistema. Registra versión 2, UUID, hora, America/Lima, hashes, operador, autorización y auditoría. La promoción es transaccional e idempotente. Los productos no contados no se convierten en ceros supuestos.

La migración directa conserva trabajadores, visitas, cantidades clínicas, procedimientos, diagnósticos, alergias, correcciones, borradores y correspondencias. Retira del estado operativo lotes, movimientos FEFO, conciliaciones ambulatorias y evidencias antiguas. El origen permanece en el respaldo y las generaciones cifradas anteriores.

La restauración clínica selectiva conserva el inventario activo, deduplica por DNI/ID y procedencia, y rechaza conflictos sin reemplazar información parcialmente. La recuperación completa solo admite una fuente vacía. Se preserva la separación clínica/DEMO y el cifrado; los respaldos v2 no se interpretan como v1.

Una atención válida se guarda aunque falte R, conteo o stock. Su incidencia se resuelve una vez; un conteo posterior que ya cubría el consumo impide otro descuento. Los pendientes FEFO antiguos no reaparecen como incidencias activas.

El corte 9–8 es de solo lectura. Se demostró 70 + 4 − 2 = 72 con evidencia, manteniendo el stock en 70. Las evidencias incompletas, unidades incompatibles y procedencias de otros respaldos no se certifican. Una estimación nunca genera un movimiento automático.

Los conteos muestran diferencias y permiten mantener, actualizar o dejar pendiente el próximo vencimiento. Los cambios de vencimiento no alteran cantidades. Los Excel conservan las diez hojas/A–AD del ambulatorio y las 98 filas de enfermería. No se inventan lotes, no se certifican saldos desconocidos como cero, no se confunde saldo calculado con conteo físico, no se informa F/S=0 sin conteo y no se usa un vencimiento editado después de la fecha consultada.

Se conservaron las cuatro pestañas Premium, navegación, edición y protección del segundo plano. Los cambios de autenticación están separados en los commits `c547f62` y `bcc3f00`. Glass Clinical no se fusionó.

## Pruebas efectivamente ejecutadas

Los conteos de las filas siguientes **no se suman**: las pruebas dirigidas y visuales repiten casos de otras suites.

| Ejecución | PASS | FAIL final | Alcance |
|---|---:|---:|---|
| Suite Swift completa del candidato | 411 | 0 | Incluye compatibilidad antigua, cifrado, clínica, Excel y 27 casos v2 |
| Swift final dirigido | 42 | 0 | 28 casos v2 y 14 de compatibilidad de envases; incorpora la comprobación adicional de procedencia y el cero R normalizado |
| JavaScript histórico (`npm run test:logic`) | 50 scripts | 0 | Contratos antiguos, clínica, respaldo, reportes, lotes históricos y no duplicación |
| Guardas JavaScript finales | 7 scripts | 0 | v2, Premium, paridad clínica, rutas/mutaciones, respaldo y sintaxis Swift |
| XCTest nativo, simulador limpio | 16 | 0 | Incluye interoperabilidad v1, respaldo/activación DEMO v2 y layouts |
| Repetición visual tras ajustes | 2 | 0 | Inventario, conteo, vencimiento e historial en claro/oscuro; ya incluidos en los 16 casos |
| XCTest de interfaz, ejecución conjunta | 7 | 0 | Biometría, menús, Premium y recorrido de unidades/R con persistencia |
| XCTest protegido adicional | 1 | 0 | Creación de fuente cifrada ficticia y relanzamiento, con autenticación real simulada |

Hay **8 casos distintos de interfaz aprobados**, en las dos ejecuciones indicadas, y **24 casos distintos XCTest** entre nativos e interfaz. No se afirma una ejecución única de ocho casos ni una repetición completa de Swift después de los últimos ajustes: esa última aceptación Swift fue dirigida (42). La suite actual contiene 412 casos; su nueva receta completa queda disponible para CI/Work.

El recorrido efectivo comprobó 70→68 unidades y 12→11 con R=1, manteniendo 11 con R=0; al relanzar permanecieron 68/11. También comprobó diagnóstico persistido, borradores, cierre del editor en segundo plano, ausencia de barras sobre el teclado y acceso protegido.

### Fallos de desarrollo resueltos

- R=0 se presentaba como `-0`: se normalizó el cero; la aserción exacta `Kardex R: 0` se conserva y pasó.
- La prueba nueva intentaba entrar a Nueva atención desde un stack aún situado en Inventario y cerraba un buscador múltiple ya abierto: se corrigió el recorrido, sin quitar las aserciones de cantidades.
- Dos pruebas nuevas usaban directorios temporales fuera del prefijo permitido del diario: se corrigieron las fixtures, sin relajar la lista de rutas.
- Una aserción comparaba el texto JSON original con la representación canónica descifrada: ahora verifica exactamente el payload autenticado y su hash, además de la conservación clínica.
- Una fixture protegida contenía el marcador DEMO «PERSONA FICTICIA»: el validador la rechazó correctamente. Se utilizó la misma identidad inventada válida del recorrido anterior; no se cambió el validador.
- La inscripción inicial incorrecta del simulador produjo la pantalla del código en la primera prueba biométrica. Con la inscripción correcta pasaron cancelación, reintento y regreso del segundo plano, sin bypass.

Los logs de ensayos previos se conservan en la carpeta local de trabajo. Los FAIL anteriores no se ocultan ni se contabilizan como resultados finales aprobados.

## Xcode y capturas

Xcode 16.2 (16C5032a), Swift 6.0.3, lenguaje del proyecto 5.9, SDK 18.2, Mac Intel. iPhone 16, runtime iOS 18.3.1 (22D8075; identificador `iOS-18-3`).

**Build genérico iOS Simulator final: PASS.** También pasó `build-for-testing`. Persisten dos advertencias de variables no utilizadas en el formulario; no hay errores de compilación. No se certifica Face ID físico ni iOS 18.5 a partir de este simulador.

Simulador final: `DANPER-Kardex-V2-Final-20261027`, UUID `11716166-487D-4B8B-A877-D7E4A690C175`. Se deja la compilación final instalada en ese dispositivo aislado, en modo DEMO. Las capturas y los `.xcresult` se conservan fuera de Git, con datos ficticios.

Capturas y logs: `/Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/kardex-simple-v2-20261027`.

Para abrir la práctica sin tocar una fuente real:

```sh
xcrun simctl launch --terminate-running-process 11716166-487D-4B8B-A877-D7E4A690C175 pe.danper.saludmovil.native.preview --danper-redesign-demo -danper.appearance dark
open -a Simulator --args -CurrentDeviceUDID 11716166-487D-4B8B-A877-D7E4A690C175
```

## BLOCKED / NOT RUN

**BLOCKED: 1.** Validación del código nuevo en GitHub Actions/iOS 18.5. Requiere transferir/publicar la rama con autorización y actualizar la selección de tests de la receta remota. El run `40576668230` se auditó; no se declaró que sus fallos fueran exclusivamente de infraestructura.

**NOT RUN: 4 comprobaciones externas o deliberadamente fuera del desarrollo local.** Transición de una base real; Face ID/código e instalación en dispositivo físico; diálogo de Archivos y disponibilidad de un proveedor real/iCloud de extremo a extremo (sí se probaron archivo cifrado, relectura y verificación en pruebas nativas); generación/firma/distribución del IPA en GitHub.

La receta nueva de aceptación se comprobó con `bash -n`; sus componentes se ejecutaron como se detalla arriba, no como una única invocación de ese script. No hay otra falla funcional local conocida en los casos ejecutados. Los respaldos corruptos o incompatibles se rechazan; no se flexibilizan validadores para forzar una recuperación.

## Protección de referencias y commits

Base Premium conservada: `2c776e88bc8b83e68ea85060263d204ca57025da`. Estable conservada: `9bec8e01ccbb3f1a674372cf6e48df049dc4f014`. Se verificaron por lectura remota main `19118cc687a65923504a304089b53997935463e8` y Glass `4f3c0c0dec1a6dbe27988f1577d5e81bb5ffbbea`. No se modificaron referencias protegidas ni la URL del remoto.

| Etapa | Commit | Cambio |
|---|---|---|
| A | `e471084` | Auditoría y arquitectura |
| B | `32dc07d` | Modelo consolidado, auditor y núcleo puro |
| C | `e449f97` | Bóveda, reinicio y recuperación selectiva |
| D | `c82c3df` | Declaración manual y retirada de acciones FEFO |
| E | `43cde75` | Corte y vencimientos |
| F | `d541f51` | Interfaz Premium y Excel |
| G | `c547f62` | Pruebas de ciclo de vida y selección de texto |
| Compatibilidad | `480e007` | Igualdad JSON portátil y prueba contra alteraciones |
| G adicional | `bcc3f00` | Creación/relanzamiento de fuente protegida |
| H | `e599979` | Aceptación, correcciones verificadas, fixtures y guías |

Las etapas tienen dependencias entre capas; la aceptación corresponde al conjunto final, no a una certificación de cada checkout intermedio.

## Transición y entrega a Work

Consultar `KARDEX_V2_TRANSICION_SEGURA.md` antes de usar datos reales. Incluye copia previa, validación, autorización, conteo inicial, restauración selectiva, incidencias, cortes y revisión posterior.

Consultar `KARDEX_V2_WORK_HANDOFF.md` para reproducir las pruebas, actualizar los nombres de los casos de CI y preparar el IPA posteriormente. Se mantienen versión 0.4.1/build 11 e identificadores existentes; Work deberá elegir versión/build y firma del canal autorizado. La rama local no existe automáticamente en GitHub.

## Archivos modificados desde la base Premium

- [docs/KARDEX_SIMPLE_V2_AUDITORIA_ARQUITECTURA.md](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/docs/KARDEX_SIMPLE_V2_AUDITORIA_ARQUITECTURA.md)
- [docs/KARDEX_V2_AUTENTICACION_CI.md](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/docs/KARDEX_V2_AUTENTICACION_CI.md)
- [docs/KARDEX_V2_INFORME_FINAL.md](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/docs/KARDEX_V2_INFORME_FINAL.md)
- [docs/KARDEX_V2_TRANSICION_SEGURA.md](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/docs/KARDEX_V2_TRANSICION_SEGURA.md)
- [docs/KARDEX_V2_WORK_HANDOFF.md](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/docs/KARDEX_V2_WORK_HANDOFF.md)
- [native-ios/App/N2Build222KardexHub.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2Build222KardexHub.swift)
- [native-ios/App/N2ClinicalWorkspaceView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2ClinicalWorkspaceView.swift)
- [native-ios/App/N2FirstManualWorkerView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2FirstManualWorkerView.swift)
- [native-ios/App/N2MedicationRowView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2MedicationRowView.swift)
- [native-ios/App/N2NativeClinicalFormView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2NativeClinicalFormView.swift)
- [native-ios/App/N2NativeHistoryView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2NativeHistoryView.swift)
- [native-ios/App/N2NativePortableBackupMaker.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2NativePortableBackupMaker.swift)
- [native-ios/App/N2ProtectedClinicalIOSVault.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2ProtectedClinicalIOSVault.swift)
- [native-ios/App/N2SimpleCutView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2SimpleCutView.swift)
- [native-ios/App/N2SimpleInventoryView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2SimpleInventoryView.swift)
- [native-ios/App/N2SimpleMigrationViews.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2SimpleMigrationViews.swift)
- [native-ios/App/N2SimpleProductEditor.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2SimpleProductEditor.swift)
- [native-ios/App/N2SyntheticTrialIOSVault.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2SyntheticTrialIOSVault.swift)
- [native-ios/App/N2VerifiedIndicatorExportView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2VerifiedIndicatorExportView.swift)
- [native-ios/App/N2VerifiedNursingExportView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2VerifiedNursingExportView.swift)
- [native-ios/App/N2WorkspaceVault.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/N2WorkspaceVault.swift)
- [native-ios/App/NativeRootView.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/NativeRootView.swift)
- [native-ios/InteractionTests/N2BiometricInteractionTests.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/InteractionTests/N2BiometricInteractionTests.swift)
- [native-ios/InteractionTests/N2PremiumRedesignTests.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/InteractionTests/N2PremiumRedesignTests.swift)
- [native-ios/InteractionTests/N3ClinicalJourneyTests.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/InteractionTests/N3ClinicalJourneyTests.swift)
- [native-ios/NativeTests/N2ClinicalLayoutTests.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/NativeTests/N2ClinicalLayoutTests.swift)
- [native-ios/NativeTests/N2PremiumDemoFixtureTests.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/NativeTests/N2PremiumDemoFixtureTests.swift)
- [native-ios/NativeTests/N2SimpleInventoryNativeTests.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/NativeTests/N2SimpleInventoryNativeTests.swift)
- [native-ios/Sources/DanperCore/N1sNursingExcelWriter.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N1sNursingExcelWriter.swift)
- [native-ios/Sources/DanperCore/N2AutomaticCutAccounting.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2AutomaticCutAccounting.swift)
- [native-ios/Sources/DanperCore/N2AuxiliaryInventory.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2AuxiliaryInventory.swift)
- [native-ios/Sources/DanperCore/N2ClinicalCorrections.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2ClinicalCorrections.swift)
- [native-ios/Sources/DanperCore/N2ClinicalTransactions.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2ClinicalTransactions.swift)
- [native-ios/Sources/DanperCore/N2ContainerAccounting.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2ContainerAccounting.swift)
- [native-ios/Sources/DanperCore/N2EncryptedClinicalJournal.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2EncryptedClinicalJournal.swift)
- [native-ios/Sources/DanperCore/N2InventoryBackupCodec.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2InventoryBackupCodec.swift)
- [native-ios/Sources/DanperCore/N2NativeDraftRecovery.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2NativeDraftRecovery.swift)
- [native-ios/Sources/DanperCore/N2NativeFormContext.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2NativeFormContext.swift)
- [native-ios/Sources/DanperCore/N2NativeInventoryCommands.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2NativeInventoryCommands.swift)
- [native-ios/Sources/DanperCore/N2NativeReconciliationEditor.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2NativeReconciliationEditor.swift)
- [native-ios/Sources/DanperCore/N2NativeSnapshotReader.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2NativeSnapshotReader.swift)
- [native-ios/Sources/DanperCore/N2NursingReportBuilder.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2NursingReportBuilder.swift)
- [native-ios/Sources/DanperCore/N2OccupationalVigilanceWorkbook.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2OccupationalVigilanceWorkbook.swift)
- [native-ios/Sources/DanperCore/N2PendingDispensingEvidence.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2PendingDispensingEvidence.swift)
- [native-ios/Sources/DanperCore/N2PersonalRosterImport.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2PersonalRosterImport.swift)
- [native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift)
- [native-ios/Sources/DanperCore/N2SimpleClinicalTransaction.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2SimpleClinicalTransaction.swift)
- [native-ios/Sources/DanperCore/N2SimpleInventoryCommands.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2SimpleInventoryCommands.swift)
- [native-ios/Sources/DanperCore/N2SimpleInventoryCut.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2SimpleInventoryCut.swift)
- [native-ios/Sources/DanperCore/N2SimpleInventoryMigration.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2SimpleInventoryMigration.swift)
- [native-ios/Sources/DanperCore/N2SimpleInventoryModel.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2SimpleInventoryModel.swift)
- [native-ios/Sources/DanperCore/N2SnapshotEditor.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2SnapshotEditor.swift)
- [native-ios/Sources/DanperCore/N2VerifiedIndicatorWorkbook.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2VerifiedIndicatorWorkbook.swift)
- [native-ios/Sources/DanperCore/N2VerifiedNursingWorkbook.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Sources/DanperCore/N2VerifiedNursingWorkbook.swift)
- [native-ios/Tests/DanperCoreTests/N2SimpleInventoryTests.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Tests/DanperCoreTests/N2SimpleInventoryTests.swift)
- [native-ios/Tests/DanperCoreTests/N3DeclaredContainerTests.swift](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/Tests/DanperCoreTests/N3DeclaredContainerTests.swift)
- [scripts/audit-n2-build222-backup-restore.cjs](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/scripts/audit-n2-build222-backup-restore.cjs)
- [scripts/audit-n2-workspace-routing.cjs](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/scripts/audit-n2-workspace-routing.cjs)
- [scripts/run-n2-simple-v2-acceptance-macos.sh](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/scripts/run-n2-simple-v2-acceptance-macos.sh)
- [scripts/test-n2-build222-ui-parity.cjs](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/scripts/test-n2-build222-ui-parity.cjs)
- [scripts/test-n2-simple-inventory-v2.cjs](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/scripts/test-n2-simple-inventory-v2.cjs)
