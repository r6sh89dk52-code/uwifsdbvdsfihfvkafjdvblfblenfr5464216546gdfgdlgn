# DANPER Salud Móvil — correspondencia nativa con Build 222 (20-10-2026)

## Referencias congeladas
- Build 222: `release/v0.21.12-build222-provisional-consumptions` (React/TypeScript/Capacitor). Solo fuente de contraste, no modificar.
- B11 base: `fix/b11-personal-sedes-seguras-20261020` (SwiftUI, bóvedas independientes).
- Rama de esta mejora: `feat/build222-native-ui-parity-20261020`.
- ID de beta: `pe.danper.saludmovil.native.preview` (mantenerlo distinto del original).
- GitHub Actions agotadas: validar en Mac local con Xcode 16+, sin afirmar CI.

## Cambios de interfaz ya implementados en esta rama
1. Navegación **Inicio, Registrar, Historial, Ajustes** (cuatro pestañas, como Build 222), conservando el motor SwiftUI nativo.
2. Inicio con identidad DANPER compacta, saludo del Departamento de Salud, acceso rápido a Nueva atención, métricas y seis herramientas: Historial, Trabajadores, Pendientes, Alergias, Kardex y Exportar.
3. Aviso de modo ficticio visible pero contraíble; se mantiene el bloqueo de uso asistencial de la beta.
4. Nuevo hub nativo de Kardex con accesos a lotes, conciliación, informe de 98 productos e Indicador de 10 hojas.
5. La navegación de la bóveda clínica separada también usa cuatro pestañas, sin unir ni migrar automáticamente los datos; borradores, Personal y reportes siguen accesibles.

## Matriz de equivalencias y puertas pendientes

| Build 222 | Ruta SwiftUI existente | Situación |
| --- | --- | --- |
| Inicio, acceso rápido, seis herramientas, cuatro pestañas | NativeRootView | Estructura adaptada en esta rama; pendiente prueba visual y accesibilidad |
| Registrar atención (4 pasos) | N2NativeClinicalFormView + DanperUITheme | Nativa; pendiente contraste visual de cada paso y E2E del flujo |
| Alta/búsqueda/edición de trabajadores y DNI | N2NativeWorkerEditorView / N2NativeHistoryView | Parcial: probar acceso, retorno, filtros y edición con datos ficticios |
| Historial, borradores y rectificaciones | N2NativeHistoryView / N2NativeDraftsDashboard / N2ClinicalCorrectionView | Nativos; comparar navegación, filtros, corrección y datos de origen |
| Alergias, categorías, permiso, medicamentos y procedimientos | N2NativeClinicalFormView | Lógica existente; pendiente paridad visual, menús, animaciones y teclado |
| Kardex: 98 productos, lotes y movimientos | N2Build222KardexHub / N2NativeInventoryView / N2ReconciliationView | Enlaces nativos; prueba manual y datos clínicos verificados pendientes |
| Excel Indicador ambulatorio (10 hojas, A–AD) | N2VerifiedIndicatorExportView | Generador nativo existente; comparar binario y fórmulas contra plantilla original |
| Excel Kardex por día/rango | N2VerifiedNursingExportView | Generador nativo existente; validar 98 productos, sedes y cortes |
| Respaldo cifrado build222 | N2NativeBackupExportView / N2NativeActivationView | Pruebas sintéticas parciales, faltan respaldo original y restauración auditada |
| Ajustes, apariencia, hápticos | NativeRootView / DanperUITheme | Controles nativos; pendiente contraste de animaciones y accesibilidad |
| Face ID / Keychain | DANPERNativeApp / bóvedas N2 | Validar firma, reinicio, segundo plano, Keychain y iPhone físico |

## Condiciones de aceptación
- No convertir a WebView ni recuperar la interfaz React dentro del ejecutable SwiftUI.
- No alterar la Build 222, el branch `main`, el bundle ID clínico, ni sus claves/archivos.
- No cruzar bóvedas ficticias/reales ni borrar datos al actualizar.
- Validar `swift test` con fixtures completas en Mac, compilar con `xcodebuild`, ejecutar XCTest en simulador, probar navegación y capturar pantallas reales.
- No declarar paridad completa ni IPA clínica lista mientras resten apartados pendientes.

## B11 — Origen de datos y borrado verificado (revisión 2026-10-21)
- En Inicio sin demostración activa se ofrecen **cuatro acciones explícitas**: crear demostración vacía, crear ejemplo sintético, importar Excel PERSONAL a la bóveda clínica independiente, o restaurar respaldo original .danperbackup mediante verificación.
- El paquete de demostración original contiene cinco identidades ficticias y atenciones sintéticas **estables entre ejecuciones**. Volver a cargar ese paquete después de borrarlo recrea las mismas fichas; **no es persistencia residual**.
- `N2EmptyDemoSnapshot` prepara nueve colecciones vacías (trabajadores, atenciones, alergias, lotes, movimientos, asociaciones, incidencias, conciliación y notificaciones desactivadas); no lee el fixture precargado.
- La compatibilidad de apertura vacía es **exclusiva para lecturas del origen vacío exacto**; `N1BackupAdmission.preview` sigue rechazando un respaldo vacío y `N1eLegacyClinicalAudit.inspect` mantiene el rechazo por defecto.
- El borrado de demostración comprueba la eliminación de carpeta allowlisted y Keychain de prueba; actualiza Inicio inmediatamente, borra únicamente recordatorios DEMO y nunca toca la bóveda clínica.
- La importación XLSX utiliza `N2PersonalWorkbookReader`: hoja `PERSONAL`, validación de DNI y nombres, detección de duplicados, sexo/sede, previa de tres registros y conciliación de los existentes. Tras confirmar muestra acceso al espacio clínico protegido. No mezcla empleados reales con DEMO.
- No se ha ejecutado en este entorno una compilación macOS/iOS de esta revisión; el script local realiza `swift test --filter N2EmptyDemoSnapshotTests`, XcodeGen, compilación firmada, instalación y apertura, deteniéndose si una prueba o compilación falla.
- Pendiente antes de uso real: validar con libro PERSONAL real autorizado, restauración del respaldo Build 222, persistencia tras reinicio, importación repetida, recuentos tras borrado, UI y seguridad en dispositivo físico. No introducir datos laborales o clínicos reales en una beta todavía no validada.
