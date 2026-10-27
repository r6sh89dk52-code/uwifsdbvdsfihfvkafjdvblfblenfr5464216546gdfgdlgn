# DANPER Salud Móvil — rediseño nativo

Rama de entrega: `feat/n2-premium-redesign-20261026`, creada desde `9bec8e0` de `feat/build222-native-ui-parity-20261020`. Versión empaquetada conservada: **0.4.1, compilación 11**. Bundle Identifier conservado: `pe.danper.saludmovil.native.preview`.

## Implementación

- Acceso SwiftUI con fotografía original, logotipo corporativo existente, degradados y curva roja, Face ID automático, reintento y alternativa del sistema iOS mediante `LocalAuthentication`.
- Inicio clínico y DEMO con los mismos componentes: bienvenida, Nueva atención, Hoy/Esta semana/Este mes y herramientas. Los entornos conservan sus fuentes separadas y DEMO permanece identificado.
- Cápsula flotante con material nativo, cuatro pestañas Inicio/Historial/Borradores/Ajustes, estado independiente, hápticos opcionales y adaptación a movimiento/transparencia reducidos. Se oculta con el teclado; la barra nativa queda oculta en cada árbol de navegación.
- Accesibilidad: controles con nombres completos, selección anunciable y visor ampliado nativo; herramientas y métricas pasan a una columna con los tamaños de accesibilidad. Se revisaron capturas de Inicio a 375 × 667 puntos y letra máxima.
- Contadores autenticados de atenciones confirmadas. Calendario gregoriano, lunes como inicio de semana y zona America/Lima. Se excluyen borradores y fechas posteriores al día local actual. El mes se calcula en el mismo recorrido optimizado, sin reconstruir ni ordenar el padrón.
- Trabajadores, Kardex, Indicadores/exportaciones y Estadísticas accesibles desde Inicio. Importación PERSONAL, inventario/lotes, corte, vigilancia y respaldo siguen en Ajustes.
- Estadísticas incluye selector Mes/Año y las tres secciones preparadas, con estados vacíos explícitos. No se añadieron indicadores ni cifras ficticias.
- Versión/build obtenidos del bundle por un componente compartido.
- Recuperación de borradores y eliminación optimista conservadas. Al volver del autoguardado, la eliminación obtiene la revisión autenticada actual antes de la comprobación atómica de revisión y estado draft; el rollback permanece activo si falla.
- El autocompletado centra las primeras sugerencias y vuelve a ajustarse al terminar de cambiar el tamaño del teclado. Pasó tres repeticiones consecutivas sin desplazamiento manual.
- Historial presenta la búsqueda visible. Los mensajes de éxito habituales se abreviaron; advertencias, errores, validaciones y confirmaciones destructivas permanecen.

## Componentes y archivos

| Área | Archivos principales |
|---|---|
| Sistema visual | `DanperPremiumUI.swift`, `DanperUITheme.swift` |
| Acceso/autenticación | `DANPERNativeApp.swift`, `AccessHero.imageset` |
| Navegación y módulos | `N2ClinicalWorkspaceView.swift`, `NativeRootView.swift` |
| Formularios/listas | `N2NativeClinicalFormView.swift`, `N2NativeDraftsDashboard.swift`, `N2NativeHistoryView.swift` |
| Métricas de lectura | `N2HomeCalendarPeriod.swift`, `N2DashboardMetrics.swift`, `N2ProtectedClinicalVaultCore.swift`, adaptadores de workspace |
| Validación | pruebas de calendario/lector rápido, layouts, autenticación, shell, recorrido clínico y rediseño; scripts de paridad y auditoría |

No se modificaron AES-GCM, Keychain, formato de respaldo, modelos clínicos persistidos, FEFO, lotes, consumo, reglas de alergias, vigilancia ni el exportador Excel. Las pruebas de exportación se actualizaron para describir el comportamiento provisional ya existente: comprimidos con R declarada y envases pendientes sin R inventada; la salida oficial sigue bloqueada sin entrega verificada. La prueba de inventario usa la referencia visible del lote porque SwiftUI aplana los hijos de DisclosureGroup en el árbol de accesibilidad; conserva las verificaciones de Abiertos: 1, estado de envases y Kardex después de relanzar.

## Verificación

| Validación | Resultado |
|---|---|
| Swift Package, clínica e integridad | **383/383**, cero fallos |
| Scripts JavaScript de pruebas y auditoría | **61/61**, cero fallos |
| Familias de fixtures sintéticos | **12/12**, cero fallos |
| Xcode, iPhone 16 Simulator / iOS 18.3.1 | **TEST SUCCEEDED: 21/21** (15 nativas + 6 de interacción) |
| Ajuste final de contraste del acceso y autenticación | **3/3**, cero fallos, tras la suite completa |
| Autocompletado sobre teclado, repetición focalizada | **3/3**; también correcto en la suite completa final |

El recorrido final comprobó Face ID automático/cancelación/reintento/retorno, las cuatro pestañas, Nueva atención y teclado, búsqueda en Historial, recuperación/eliminación persistente de borradores, versión/build, registro de lotes y atenciones, conciliación, apertura bloqueada cuando corresponde, reutilización R=0 y persistencia de historial, envases y Kardex tras relanzar.

Se revisaron capturas claras/oscuras y de letra máxima en tamaño pequeño. Las etiquetas de accesibilidad, selección, Reducir movimiento y Reducir transparencia se revisaron en el código y mediante los elementos accesibles de las pruebas. No se realizó un recorrido manual con VoiceOver ni una prueba en iPhone físico; el código real del dispositivo tampoco se introdujo en el simulador. La alternativa usa la autenticación segura de iOS, sin PIN propio.

No quedan fallos de compilación o pruebas en la entrega final. Estadísticas permanece deliberadamente como estructura visual sin analítica nueva. El último ajuste, exclusivamente visual, mejora el contraste de la barra del sistema en el acceso claro/oscuro y se recompiló y verificó con tres pruebas focalizadas de acceso y autenticación. La evidencia definitiva está en `xcode-acceptance.log`, `premium-acceptance.xcresult`, `xcode-access-contrast.log`, `premium-access-contrast.xcresult`, `swift-full.log`, `audits-results.json` y `validation-results.json`; los intentos de diagnóstico anteriores están separados en `diagnostics/`.

Las imágenes en `screenshots/` son capturas del simulador. Los recorridos usan exclusivamente registros ficticios de prueba; no contienen datos de pacientes. Las capturas de layout con métricas inyectadas son pruebas de presentación, no resultados de una fuente clínica real.

## Capturas principales

- [Acceso oscuro](/Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/premium-redesign-20261026/screenshots/Acceso-oscuro.png)
- [Acceso claro](/Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/premium-redesign-20261026/screenshots/Acceso-claro.png)
- [Inicio clínico oscuro — fuente sintética con atenciones guardadas](/Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/premium-redesign-20261026/screenshots/Inicio-clinico-oscuro.png)
- [Estadísticas — estructura sin cifras ficticias](/Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/premium-redesign-20261026/screenshots/Estadisticas-oscuro.png)
- [Inicio pequeño con letra máxima](/Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/premium-redesign-20261026/screenshots/Premium-Inicio-SE-letra-grande.png)
- [Autocompletado y teclado](/Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/premium-redesign-20261026/screenshots/Autocompletado-teclado.png)

## Reproducir desde Xcode

Con el árbol local limpio (guardar previamente cualquier trabajo propio):

```sh
cd /Users/felipeazcarate/Downloads/DANPER-N2-Paridad
git fetch origin
git switch feat/n2-premium-redesign-20261026
git pull --ff-only origin feat/n2-premium-redesign-20261026
cd native-ios
xcodegen generate
open DANPERNative.xcodeproj
```

Seleccionar esquema `DANPERNative` y un **iPhone 16 Simulator**, ejecutar Run. Para Product → Test usar un simulador nuevo y aislado: los tests generan exclusivamente registros ficticios y esperan fuentes inicialmente vacías; no ejecutarlos en un simulador que contenga información propia. Los argumentos `--danper-redesign-access` y `--danper-redesign-demo` son inspecciones visuales exclusivas de DEBUG en simulador; no forman parte de Release ni habilitan acceso a una fuente clínica.

Validaciones rápidas:

```sh
node scripts/test-n2-build222-ui-parity.cjs
node scripts/test-n2-premium-redesign.cjs
DANPER_N1_FIXTURE_DIR="$PWD/work/premium-redesign/fixtures" swift test --package-path native-ios --jobs 2
danper_test_sim=$(xcrun simctl create DANPER-Premium-Pruebas com.apple.CoreSimulator.SimDeviceType.iPhone-16 com.apple.CoreSimulator.SimRuntime.iOS-18-3)
xcrun simctl boot "$danper_test_sim"
xcrun simctl bootstatus "$danper_test_sim" -b
xcrun simctl spawn "$danper_test_sim" notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
xcrun simctl spawn "$danper_test_sim" notifyutil -p com.apple.BiometricKit.enrollmentChanged
xcodebuild -project native-ios/DANPERNative.xcodeproj -scheme DANPERNative -configuration Debug -destination "platform=iOS Simulator,id=$danper_test_sim" -parallel-testing-enabled NO -jobs 2 test
```

Antes de la suite Swift, desde la raíz del repositorio:

```sh
export DANPER_N1_FIXTURE_DIR="$PWD/work/premium-redesign/fixtures"
mkdir -p "$DANPER_N1_FIXTURE_DIR"
for fixture_script in generate-native-compat-fixtures generate-n1e-clinical-fixtures generate-n1f-lossless-fixtures generate-n1h-clinical-parity generate-n1p-excel-parity generate-n1q-reconciliation-fixtures generate-n1r-stored-xlsx-template generate-n1s-official-excel-fixtures generate-n2-approved-fixture generate-n2-nursing-parity generate-n2-procedure-parity generate-n2-stock-commands-fixtures; do
  node "scripts/$fixture_script.cjs" || exit 1
done
```

Las doce familias se generaron sin errores; lista y resultados en `fixtures-results.json`. Se escribieron en `work/premium-redesign/fixtures`, sin utilizar fuentes clínicas. Para ejecutar las 61 comprobaciones JavaScript:

```sh
for check_script in scripts/test-*.cjs scripts/audit-*.cjs; do
  node "$check_script" || exit 1
done
```

## Procedencia del recurso visual

Fotografía generada con la herramienta integrada **image_gen**, modo generación, como recurso de fondo original con persona ficticia. No se incorporó el mockup del teléfono a la interfaz. El logotipo procede del recurso corporativo ya existente.

Recurso incorporado: [access-hero.png](/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/native-ios/App/Assets.xcassets/AccessHero.imageset/access-hero.png). Si falta la fotografía, la pantalla conserva su composición con el degradado de respaldo.

Prompt final de generación:

> Use case: photorealistic-natural. Asset type: background photograph for the top hero of a native occupational-health iPhone login screen. Create an original editorial photograph of a fictional adult Latina agrifood worker wearing a clean white lab coat and translucent white hairnet, calm confident expression, looking slightly upward to the left. Medium close-up shoulders and head, subject occupies right 55% of a wide 3:2 composition. Left 45% is soft deep burgundy negative space for a separately implemented white wordmark and short text. Soft natural window light, authentic skin texture, shallow depth of field, subtle blurred agricultural packing facility, luxurious dark crimson grading that fades into near black at the bottom. No text, logos, watermarks, devices, UI or phone frame. Standalone background photo only, not an app mockup. Original fictional person, do not reproduce a real face.
