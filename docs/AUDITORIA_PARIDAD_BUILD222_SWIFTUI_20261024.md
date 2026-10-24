# Auditoría comparativa DANPER Build 222 ↔ SwiftUI nativa
**Fecha:** 24/10/2026 · **Corte de fuente:** rama `feat/build222-native-ui-parity-20261020` hasta los cambios de vigilancia ocupacional; **baseline congelada:** `release/v0.21.12-build222-provisional-consumptions` (`09fef294d73f6a1c655dc42865b6fa5c5e1f792a`).
**Alcance:** reemplazo de Build 222 **en iPhone**. La migración SwiftUI no sustituye la versión Android.
**Naturaleza de esta auditoría:** revisión estática y comparativa de código, contratos, pantallas, scripts y pruebas existentes; **NO incluye ejecución de tests Swift, Xcode, Excel macOS ni un recorrido táctil en iPhone**.

## VEREDICTO (no confundir código implementado con paridad operativa)
**NO AUTORIZAR todavía la sustitución de Build 222 como aplicación de trabajo.** La nueva app está funcionalmente muy avanzada y en varias reglas mejora la referencia, pero no dispone en esta revisión de evidencia ejecutada que pruebe la integridad de toda la ruta real (importación/restauración → trabajador → atención → aperturas/FEFO → historial → dos exportes originales → respaldo → reinicio). La tercera exportación también es nueva y aún no pasó prueba real de Microsoft Excel. La recomendación es mantener Build 222 para la operación diaria mientras se realizan las validaciones detalladas más abajo.

### Definiciones
- **Código presente:** una ruta o regla identificable en el repositorio; no certifica que compile ni funcione.
- **Paridad lógica respaldada por tests existentes:** pruebas sintéticas y contratos presentes, pero sus resultados deben reproducirse sobre HEAD actual.
- **Pendiente:** falta evidencia de ejecución, diferencias UI o cobertura no equivalente.
- **Nueva:** capacidad añadida a SwiftUI que no era parte del contrato congelado de Build 222.

## Matriz de paridad por función
| Área / comportamiento | Referencia Build 222 | Código actual SwiftUI | Resultado de auditoría |
|---|---|---|---|
| Acceso nativo y cuatro pestañas | `src/main.tsx`, navegación híbrida | `DANPERNativeApp`, `N2ClinicalWorkspaceView` | **Código presente**, falta prueba de safe area, gestos y teclado |
| Pantalla de bienvenida/animaciones | UI React Build 222 | `DanperUITheme`, `N2ClinicalWorkspaceView` | **Pendiente paridad visual**; no existe comparación visual completa de HEAD |
| Face ID/código y desbloqueo al entrar | Bridge iOS y acceso Build 222 | `N2AccessSession`, gate `LocalAuthentication` | **Código presente**, solo dispositivo firmado verifica Face ID/Keychain |
| Inicio: contadores de hoy/semana/borradores | `src/main.tsx` | `N2DashboardMetrics`, `refreshHomeCounts` | **Cobertura lógica**, comparar contra atenciones reales tras restauración |
| Trabajadores por Excel PERSONAL | `src/workbookPersonal.ts`, `PersonalImporter.tsx` | `N2PersonalWorkbookReader`, `N2NativePersonalImportView` | **Implementado**, falta padrón real grande, duplicados y correcciones |
| Alta y edición de trabajador | `src/workerRules.ts`, búsqueda/edición web | `N2NativeWorkerEditorView`, `N2WorkerSearchSheet` | **Implementado**, equivalencia visual e historial laboral no certificadas |
| 10.000 trabajadores y páginas de 25 | Búsqueda/roster y paginación | `N2NativeHistoryView` página 25 | **Código presente**; medir iPhone 16 y 10.000 registros |
| Autocompletar áreas oficiales | `src/organizationDirectory.ts` y `OfficialAreaField.tsx` | `N2AreaAutocomplete`, recurso `n2-organization-areas.json` | **Parcial**: código/jerarquía organizativos no se trasladan necesariamente al trabajador ni a cada visita |
| Flujo de atención 4 pasos | `src/main.tsx`, `attentionStepValidation.ts` | `N2NativeClinicalFormView`, `N1hClinicalValidator` | **Lógica presente**; verificar pasos, teclado y foco en iPhone |
| Alergias documentada/negada/desconocida | `src/allergyRules.ts` | `N2NativeClinicalFormView`, `N2MedicationAllergyTextMatch` | **Presente**, probar trabajador nuevo y persistencia por DNI |
| Fecha/hora, tipo, sistema, segmento | Build 222 | `N2ClinicalFormOptions`, `N2NativeFormDraft` | **Presente**, probar mapeo de valores y exporte A–AD |
| Diagnóstico libre y sugerencias | `src/main.tsx` | `N2NativeClinicalFormView` | **Presente**, contraste de autocompletado con teclado abierto pendiente |
| Procedimientos 12 y sugerencias contextuales | `src/procedureRules.ts` | `N2ProcedureRules`, `N2Build222ProcedureParityTests` | **Paridad de algoritmo documentada**, reejecutar fixtures del HEAD |
| Búsqueda de 432 materiales, edición de múltiples líneas | `src/main.tsx` | `N2NativeCatalogIndex`, `N2MedicationRowView` | **Presente**, interacción y rapidez pendientes |
| Frecuencia 1.ª–5.ª por trabajador/fecha | `src/ambulatoryRows.ts` | `N2NativeSnapshotReader`, `N2VerifiedIndicatorWorkbook` | **Código y tests sintéticos**, validar orden/selección parcial |
| Envío foto SI/NO según lesión | Build 222, campo AA | `N2NativeClinicalFormView` / `hasWound` | **Código presente**, evaluar combos herida/sutura |
| 86 equivalencias anteriores | `reviewedKardexAssociations.ts` | `N2NativeCatalogIndex`, `N2ClinicalTransactions` | **Paridad base de 86**, no asumir identidad sin cotejar fijaciones |
| Seis asociaciones adicionales del usuario | No es requisito congelado | `N2UserReviewedKardexLinks` | **Nueva**; presentación/capacidad exige evidencia |
| Seis NO CORRESPONDE en Kardex 98 | Catálogo original completo | `N2NursingReportBuilder`, escritor de 98 | **Conservados**; no confundir no asociar con excluir |
| FEFO y no stock negativo | `src/automaticClinicalDispensing.ts` | `N2ClinicalTransactions` | **Motor presente**; prueba transaccional multilote/estados reciente pendiente |
| Confirmar atención + consumo sin duplicados | `automaticClinicalDispensing.ts` | `N2AtomicClinicalCoordinator` y writer | **Pruebas sintéticas existentes**, prueba de persistencia tras cierre forzado pendiente |
| Aperturas 1/0 y reutilización | Apertura manual dentro de fila | Ventana automática al guardar + `N2ContainerAccounting` | **Nueva UX**; no equivalencia ejecutada del nuevo código |
| Agotamiento de envase al abrir otro | Cierre de envase en otro flujo | Evento `containerState` cuando usuario confirma | **Nuevo**, comprobar R=0 cierre previo + R=1 apertura única |
| Registro stock inicial vs contado hoy | Formularios/movimientos Build 222 | `N2StockRegistrationChoice` y alerta en Inventario | **Nueva**, 9–8 contable sin doble débito; prueba E2E pendiente |
| Corte 9–8 y reconstrucción retrospectiva | `dailyKardex.ts` / indicadores | `N2AutomaticCutAccounting`, `N2NursingReportBuilder.reconstructedCut` | **Extendido**, requiere prueba con datos anteriores y posterior conteo |
| Inventario único Fundo/Planta | Configuración consolidada actual | `N2NativeInventoryView` y motor central | **Implementado**, verificar que no se segrega por sede |
| Registro de ingresos/ajustes/conteos | `KardexMovementsPanel.tsx` | `N2NativeInventoryView`, `N2ReconciliationView` | **Parcial en UI**: falta cotejar listado navegable completo y opciones operativas de cada movimiento |
| Historial, pendientes, rectificaciones | `AttentionDeliveryPanel.tsx`, edición segura | `N2NativeHistoryView`, `N2ClinicalCorrectionView` | **Implementado parcialmente**, simulación de corrección y retroactividad imprescindible |
| Eliminación segura de atención sin salidas | `safeAttentionDeletion.ts` | Borradores y correcciones protegidas | **No se acreditó equivalencia de control para toda atención guardada** |
| Borradores automáticos 650 ms | `draftRules.ts`, `src/main.tsx` | `N2NativeDraftRecovery`, autosave | **Código presente**, recuperación tras cierre forzoso pendiente |
| Avisos locales de borradores | `nativeReminders.ts` (hasta 50 próximos) | `N2DraftReminder` (UNUserNotificationCenter) | **Parcial**: reglas y programación difieren; revisar permisos, actualización y cancelación |
| Excel Indicador 10 hojas/432/19 tablas | `ambulatoryExcel.ts`, `AmbulatoryExportPanel.tsx` | `N1sFullExcelWriter`, `N2VerifiedIndicatorWorkbook` | **Estructura existente**, **NO equivalencia final de fórmulas/estilos/resultados** |
| Excel Kardex Enfermeras 1 hoja/98 | `KardexDailyExport.tsx`, `dailyKardex.ts` | `N1sNursingExcelWriter`, `N2VerifiedNursingWorkbook` | **Código presente**, cortes/fecha/fórmulas y salida Excel real deben contrastarse |
| Excel Vigilancia osteomuscular A–Q | No exigido en Build 222 congelada | `N2OccupationalVigilanceWorkbook`, `N2OccupationalVigilanceExportView` | **NUEVO**: solo hoja visible, filtro estricto, estilos principales replicados; todavía no hay comparación en Microsoft Excel |
| Respaldar .danperbackup cifrado | `portableBackup.ts`, `BackupSettingsPanel.tsx` | `N2NativePortableBackupMaker`, `N2NativeBackupExportView` | **Compatible en código**, restaurar→exportar→restaurar y comparar nueve colecciones |
| Restaurar Build 222 con contraseña | `BackupSettingsPanel.tsx` | `N2NativeActivationView`, `PortableBackupInspector` | **Ruta existente**, faltan pruebas con un respaldo autorizado real e integridad posterior |
| Control datos ficticios vs reales | Webview Build 222 | `N2SyntheticTrialIOSVault` y `N2ProtectedClinicalIOSVault` | **Mejora arquitectónica**, fuente real aún en validación |
| UI claro/oscuro, hápticos, Dynamic Type | estilos/bridges híbridos | `DanperUITheme`, `DANPERNativeApp` | **Código presente**, falta contraste real/VoiceOver/teclado |
| Funcionamiento offline | almacenamiento local Build 222 | Journal cifrado nativo y exportes locales | **Estructura presente**, prueba de reinicio, espacio libre y error de escritura pendiente |

## Brechas que impiden reemplazar Build 222
**P0 – deben cerrarse antes de mover el trabajo clínico a SwiftUI:**
1. `swift test` completo, tests Node/TypeScript, compilación Xcode 16, instalación iPhone 16 Simulator, pruebas de interacción y recuperación del journal, sobre el **HEAD posterior a todos los cambios del 24/10**. Estas ejecuciones **no se realizaron en esta auditoría**.
2. Comparación **campo por campo y fila por fila** de un conjunto sintético idéntico entre TS Build 222 y SwiftUI: 432 materiales, responsables, fechas, DNI, frecuencia, T/U/AA, R 1/0, FEFO, incidencias, F/S, 9–8.
3. Guardar varias atenciones con frascos: abrir→reutilizar→abrir segundo→ver cierre R=0 + apertura R=1 sin movimiento duplicado; reiniciar app, reexportar y verificar idempotencia.
4. Abrir en Microsoft Excel dos reportes tradicionales; comparar 10 hojas, 19 tablas, estilos, columnas, celdas F/H y todas las fórmulas con el modelo de referencia y sin `#REF!`.
5. Restaurar respaldo `.danperbackup` original a bóveda de prueba **vacía**, verificar cantidades del snapshot, modificar y exportar nuevo respaldo, restaurar otra vez; verificar que nunca se cambie Build 222.
6. Prueba real de Face ID/Keychain firmados y persistencia al ir al fondo, cerrar o reinstalar; no presentar un simulador sin entitlements como PASS.
7. Confirmar que casos históricos de stock/conciliación no producen cambios retroactivos en existencias físicas ni duplican consumos, y que alerta de stock inicial/actual muestra saldos matemáticamente coherentes.

**P1 – para equivalencia de uso y reporte:**
8. Paridad de la **lista de movimientos completos** de Build 222 (`KardexMovementsPanel.tsx`) frente al hub SwiftUI: búsqueda/filtrado histórico, tipos de movimiento, ajustes y detalle.
9. Completar o mapear explícitamente los **códigos de subdivisión, unidad organizativa y PLANILLA** del padrón en el tercer Excel; al día de hoy se dejan en blanco cuando faltan, sin inventar valores. El Excel de vigilancia **reproduce la hoja visible y sus características principales**, pero aún falta una revisión visual comparativa de estilos, impresora y anchuras contra el original.
10. Completar la matriz UX de cada paso, menús tipo chip, búsquedas, permisos, adaptación iPhone 16, focus/teclado, scroll, Dynamic Type, VoiceOver y vuelta a los módulos inferiores.
11. Auditar la cobertura de avisos locales frente a `nativeReminders.ts` (permisos, 50, eventos de edición, cancelación).
12. Confirmar equivalente nativo de eliminación segura de **atenciones ya guardadas sin salida** conforme a `safeAttentionDeletion.ts`, sin afectar movimientos históricos.

## Validación reproducible en macOS del usuario (sin Actions)
```bash
cd ~/Downloads/DANPER-N2-Paridad
git pull --ff-only origin feat/build222-native-ui-parity-20261020
node scripts/test-n2-build222-ui-parity.cjs
bash scripts/audit-build222-excel-parity-macos.sh
bash docs/N2_PROBAR_PARIDAD_MAC_SIN_ACTIONS.command
```
Registrar y conservar el output de cada comando. Si falta el último script en el checkout, usar la ruta local existente de compilación/verificación y no dar por pasada esa etapa. Tras compilar, ejecutar el proyecto `native-ios/DANPERNative.xcodeproj` con iPhone 16 Simulator, activar una fuente **ficticia**, crear atenciones osteomusculares y no osteomusculares, generar y abrir el tercer XLSX; confirmar una hoja `VIGILACIA OCUPACIONAL`, 17 columnas, riesgo y recomendaciones del modelo, fecha/hora y preservación de DNI y responsable. Solo después probar en dispositivo real (Face ID, notificaciones, compartir y respaldo).

## Precauciones y decisión
- **No generar IPA final ni fusionar el PR #7** en `main` mientras falten las puertas P0.
- Mantener Build 222 como referencia y app operativa; no migrar automáticamente su bóveda a esta versión de prueba.
- Las funciones nuevas no compensan fallos en una función base. El criterio de sustitución es **paridad demostrada + integridad de datos + uso diario verificable**, no número de módulos.
- Esta auditoría compara implementaciones disponibles y brechas concretas. Es exhaustiva **en cobertura del inventario funcional revisado**, pero no puede certificarse como auditoría de ejecución integral sin simulador/iPhone ni Excel. El estado correcto sigue siendo **«implementación avanzada, reemplazo no aprobado»**.

## Ampliación del 24/10 · Historial, edición y lotes
**Implementación en rama N2, SIN ejecución nueva de Xcode/Swift en este corte.**
1. Historial separado del directorio PERSONAL: únicamente atenciones guardadas, orden cronológico descendente, filtro por trabajador/DNI/diagnóstico/fecha, quince filas por página y navegación directa a la ficha.
2. La ficha clínica abre sus datos y tratamientos con un toque; solo el botón explícito «Editar atención» solicita confirmación SI/NO y abre el editor auditado.
3. El contador de borradores de Inicio abre el listado de borradores. La opción «Trabajadores» conserva su buscador paginado y separado.
4. Inventario agrupado por código y nombre del producto, con lotes independientes ordenados por vencimiento (FEFO visual), referencia, existencias y acciones individuales.
5. Editar lote permite **solo corregir referencia y vencimiento en lotes sin movimientos**, con responsable y motivo. No altera cantidades. Para ajustar existencias está «Actualizar conteo», que conserva un movimiento auditado. En lotes con movimientos queda expresamente prohibida la reescritura de la referencia/vencimiento que está dentro de los documentos de movimiento.
6. Las cantidades clínicas de un producto registrado pueden rectificarse en una atención pasada mediante `itemClinicalQuantities`: quedan como `correctedClinicalQuantity` en la proyección clínica, conservando `quantity` original, `dispenseRef`, lotes y stockMovements intactos. La discrepancia entra automáticamente al conjunto que bloquea exportar esa atención al Indicador oficial hasta revisión física/documental, sin fabricar compensación de inventario.
7. **Límite consciente**: todavía NO se ha implementado cambiar libremente la identidad de un producto, insertar o quitar medicamentos ya vinculados, cambiar trabajador/fecha/hora de una atención vinculada o reescribir movimientos pasados. Esos casos requieren una cadena documentada de anulación/ajuste/dispensación y su verificación integral con Excel, por lo que siguen como **paridad no aprobada**.

### Puertas de prueba adicionales
- Crear >15 atenciones ficticias; verificar páginas 1/2, orden descendente, filtros y acceso directo sin elegir primero al trabajador.
- Pulsar contador de borradores y recuperar el seleccionado.
- Dos lotes del mismo medicamento; desplegable único con vencimientos/saldos separados; cambiar metadatos de un lote SIN movimientos; rechazar metadatos en lote CON movimientos.
- Corregir la cantidad clínica de una atención antigua y confirmar que la pantalla histórica muestra el valor corregido y el valor físico original, que R/movimientos/saldo no cambian, que la rectificación aparece en el registro auditado y que el Excel oficial pide revisión en vez de exportar un dato incongruente.
- Verificar el esquema de firmas para dispositivo real, restauración y rendimiento tras actualizar. **No sustituir Build 222** antes de completar las puertas originales P0 y estas nuevas.
