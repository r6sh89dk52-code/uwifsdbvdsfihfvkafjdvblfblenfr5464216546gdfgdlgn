# Glass Clinical + Clinical Pro — auditoría de partida

Base verificada: `1c131e1e3b46b704b9621914369f9fdf7138a1b9`; rama exclusiva `feat/swiftui-v2-glass-clinical-pro`; árbol inicialmente limpio. Se contrastó el SHA completo del paquete con el HEAD local, sin reset. Paquete extraído fuera del repositorio; siete archivos coinciden con su manifiesto SHA256.

## Referencias

01: estilo de vidrio oscuro; 02: funciones reales de Inicio; 03: composición de acceso; 04 y 05: retrato y avatar exactos. La especificación final sustituye los diseños anteriores. No se importan cifras, ubicación, nombre ni alertas ilustrativas.

## Componentes y rutas que se conservan

- DanperUITheme: header, botones, paneles, campos, menús, búsqueda en línea, fechas, progreso y enlaces.
- DanperPremiumPresentation: material compartido, región propia de pestañas y editor modal seguro; oculta barras con teclado y cierra al fondo.
- Acceso: DanperAccessView; autenticación LAContext y ciclo N2AccessSession intactos.
- Inicio DEMO y clínico: Nueva atención; Hoy/Semana/Mes calculados por las mismas consultas; Trabajadores, Kardex, Estadísticas, Indicadores en el mismo orden. Ver todas conserva el destino Ajustes.
- Pestañas: Inicio, Historial, Borradores, Ajustes.
- Ajustes: personal, alergias, importación PERSONAL, inventario, corte 9–8, exportación Kardex/ambulatorio/vigilancia, respaldo cifrado, restauración selectiva, bloqueo; en DEMO también recuperación y restablecimiento expresos.
- Kardex: detalle, movimientos, ingreso, salida, conteo, vencimiento, incidencias, activación protegida y restauración.
- Formularios: mismos pasos, campos, validaciones, catálogos y reglas.

## Categorización verificada

El catálogo clínico de 432 productos solo ofrece código/nombre/unidad. El catálogo de enfermería tiene grupos TABLETAS, AMPOLLAS, JERINGAS e INSUMOS. Los filtros visuales usarán exclusivamente correspondencias aprobadas o revisadas ya presentes: TABLETAS/AMPOLLAS → Medicamentos; JERINGAS/INSUMOS → Insumos. Las filas sin correspondencia inequívoca permanecen en Todos, con clasificación pendiente visible; nunca se deduce una categoría por palabras o presentación. Iconos ilustrativos no alteran dicha clasificación.

La comprobación del catálogo completo identifica 38 medicamentos y 53 insumos mediante 91 códigos distintos con correspondencia. Los otros 341 códigos no tienen categoría autorizada: se mantienen en Todos con la marca Clasificación pendiente; no se modifica el catálogo ni se presume que sean medicamentos. Los filtros actúan sobre los productos realmente registrados en el inventario, no crean existencias para los 432 códigos.

El umbral de próximo vencimiento conserva los 30 días de la UI v2; fecha de Lima, hoy vigente, límite inclusivo. Fecha no verificada no se presenta como comprobada. Existencia cero es independiente. Ningún cambio de esquema ni de contabilidad.

## Inventario de archivos de presentación auditados

- `native-ios/App/BackupPreviewView.swift`
- `native-ios/App/DANPERNativeApp.swift`
- `native-ios/App/DanperPremiumPresentation.swift`
- `native-ios/App/DanperPremiumUI.swift`
- `native-ios/App/DanperUITheme.swift`
- `native-ios/App/N1gClinicalWorkspace.swift`
- `native-ios/App/N1nInactivePreparationView.swift`
- `native-ios/App/N1sDemoExportView.swift`
- `native-ios/App/N2AuxiliaryInventoryView.swift`
- `native-ios/App/N2Build222ExportStages.swift`
- `native-ios/App/N2Build222KardexHub.swift`
- `native-ios/App/N2ClinicalCorrectionView.swift`
- `native-ios/App/N2ClinicalWorkspaceView.swift`
- `native-ios/App/N2ContainerStateView.swift`
- `native-ios/App/N2DemoResetView.swift`
- `native-ios/App/N2FirstManualWorkerView.swift`
- `native-ios/App/N2HealthMascot.swift`
- `native-ios/App/N2InteractionProbe.swift`
- `native-ios/App/N2KardexCutPreviewView.swift`
- `native-ios/App/N2MedicationRowView.swift`
- `native-ios/App/N2NativeActivationView.swift`
- `native-ios/App/N2NativeBackupExportView.swift`
- `native-ios/App/N2NativeClinicalFormView.swift`
- `native-ios/App/N2NativeDraftsDashboard.swift`
- `native-ios/App/N2NativeHistoryView.swift`
- `native-ios/App/N2NativeInventoryView.swift`
- `native-ios/App/N2NativePersonalImportView.swift`
- `native-ios/App/N2NativeWorkerEditorView.swift`
- `native-ios/App/N2OccupationalVigilanceExportView.swift`
- `native-ios/App/N2OperationalMappingView.swift`
- `native-ios/App/N2PendingDispensingView.swift`
- `native-ios/App/N2ReconciliationView.swift`
- `native-ios/App/N2SimpleCutView.swift`
- `native-ios/App/N2SimpleInventoryView.swift`
- `native-ios/App/N2SimpleMigrationViews.swift`
- `native-ios/App/N2SimpleProductEditor.swift`
- `native-ios/App/N2VerifiedIndicatorExportView.swift`
- `native-ios/App/N2VerifiedNursingExportView.swift`
- `native-ios/App/N2WorkerSearchSheet.swift`
- `native-ios/App/NativeFirstRunOnboarding.swift`
- `native-ios/App/NativeRootView.swift`
- `native-ios/App/NativeStorageLabView.swift`

## Decisiones de presentación

- Tema principal carbón oscuro incluso si el sistema está en claro. Las preferencias de paleta y de apariencia al compartir se conservan. La interfaz clínica solicita esquema oscuro desde la raíz SwiftUI para mantener legibles los indicadores del sistema incluso con iOS en modo claro. La opción alternativa Salud azul permanece en Ajustes y no cambia las unidades, reglas ni datos. La referencia aprobada corresponde al valor predeterminado DANPER rojo.
- La campana es decorativa, sin alerta/badge ni acción, y queda oculta a accesibilidad. El engranaje conserva su acción Ajustes con área de 44 pt.
- El saludo es Hola: no se obtiene ni infiere un nombre personal a partir del responsable clínico fijo. No se añade una sede ilustrativa.
- Material ultraThin real con tinte negro, borde fino y reflexión discreta. Reducir transparencia utiliza superficie carbón opaca legible; movimiento reducido suprime animación de pestañas y bienvenida.
- Kardex conserva el detalle y las cuatro acciones reales; filtros y búsqueda ocupan una región superior fija, fuera del desplazamiento. El rótulo de fecha es referencia manual; las fechas no verificadas quedan pendientes y no se presentan como comprobadas.
- Las métricas sin datos continúan mostrando —; Estadísticas conserva sus avisos honestos de resumen no disponible y no publica números de las maquetas.
