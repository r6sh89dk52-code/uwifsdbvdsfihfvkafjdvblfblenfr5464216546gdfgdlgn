# Entrega para auditoría de Work y futuro IPA

## Fuente de trabajo

Repositorio local: `/Users/felipeazcarate/Downloads/DANPER-N2-Paridad`.

Rama local: `feat/swiftui-premium-kardex-simple-v2`. Base Premium: `2c776e88bc8b83e68ea85060263d204ca57025da`. No se fusionó Glass Clinical ni la recuperación remota. No se hace push, merge ni publicación sin autorización del usuario. Work no verá los commits locales en GitHub hasta que el usuario autorice su publicación o transfiera el parche.

Consultar `KARDEX_SIMPLE_V2_AUDITORIA_ARQUITECTURA.md`, `KARDEX_V2_TRANSICION_SEGURA.md`, `KARDEX_V2_AUTENTICACION_CI.md` y el informe final de aceptación. El hash final y los resultados se registran en ese informe una vez concluidas las pruebas.

## Cambios remotos incorporados de forma selectiva

De `ca95650a3ab5a47675f59677eb4249e37e48c511` se adopta únicamente la comparación JSON canónica para cierres históricos (incluye prueba contra modificaciones ajenas) y la selección explícita del texto en la prueba Premium. No se fusionan workflows ni artefactos IPA. Los consumidores v1 permanecen para lectura/pruebas de compatibilidad y no constituyen las rutas cotidianas del inventario nuevo.

## Reproducción local

Requiere Xcode, xcodegen, Swift y dependencias JavaScript del lockfile. Los fixtures se generan con el procedimiento de `scripts/run-n2-full-synthetic-tests-macos.sh`; pueden reutilizarse los ficticios de `work/premium-redesign/fixtures` si existen. No usar respaldos reales como fixtures.

```sh
export DANPER_N1_FIXTURE_DIR="$PWD/work/premium-redesign/fixtures"
swift test --package-path native-ios --jobs 2
npm run test:logic
node scripts/test-n2-simple-inventory-v2.cjs
node scripts/test-n2-build222-ui-parity.cjs
node scripts/test-n2-premium-redesign.cjs
node scripts/audit-n2-workspace-routing.cjs
node scripts/audit-n2-build222-backup-restore.cjs
node scripts/audit-n2-swift-string-concatenations.cjs
xcodegen generate --spec native-ios/project.yml
```

Crear un iPhone 16 aislado; no borrar simuladores del usuario. Configurar la biometría del dispositivo creado:

```sh
xcrun simctl spawn "$danper_test_sim" notifyutil -s com.apple.BiometricKit.enrollmentChanged 1
xcrun simctl spawn "$danper_test_sim" notifyutil -p com.apple.BiometricKit.enrollmentChanged
```

Compilar con `xcodebuild build-for-testing`, destino `platform=iOS Simulator,id=$danper_test_sim`, scheme `DANPERNative`, `-jobs 2` y un DerivedData dedicado. Ejecutar primero `DANPERNativeTests` en el dispositivo nuevo y después `DANPERInteractionTests` con `test-without-building`, `-parallel-testing-enabled NO` y un `.xcresult` por ejecución. Así cada dispositivo recibe explícitamente las fixtures DEMO y el borrador Premium; ningún test de interfaz depende del resultado de otro test de interfaz para crear la fuente.

`N2SimpleInventoryNativeTests` guarda/descifra/verifica un respaldo DEMO antes de activar y comprueba persistencia. Si se repite en el mismo simulador, puede devolver los conteos DEMO a 70/12 mediante conteos auditados; nunca opera sobre la bóveda clínica. El recorrido clínico exige esa precondición, comprueba 70→68 y 12→11→11 y relanzamiento claro/oscuro. Las pruebas de autenticación usan la política real de LocalAuthentication y notificaciones biométricas del simulador; no hay éxito biométrico simulado en producción.

## CI pendiente de contrastar

Run auditado: `40576668230`, Xcode 16.4/iOS 18.5. Local: Xcode 16.2/SDK 18.2, runtime iOS 18.3.1 en Intel. Revisar específicamente el contexto de autenticación, la inscripción del simulador, cancelación/reintento y el cierre/guardado del editor tras un segundo plano real. No declarar que el fallo es exclusivamente de infraestructura sin una ejecución reproducible en CI.

No reintroducir las antiguas pruebas operativas FEFO para conseguir que el nuevo flujo haga lotes o cierres automáticos. Conservar las pruebas v1 de integridad, compatibilidad, contenedores y Excel, y utilizar el nuevo recorrido para el modelo activo. Si iOS 18.5 cambia selección de texto, menús o visibilidad, corregir la sincronización y mantener las aserciones de datos y privacidad.

## Antes del IPA

1. Obtener autorización para publicar la rama local, revisar diff y hashes protegidos.
2. Repetir las suites en CI sobre el commit exacto, conservando `.xcresult`, logs ficticios y capturas.
3. Revisar interoperabilidad de respaldos v1, rechazo de v2 por lectores antiguos, reinicio protegido y restauración clínica sin reemplazar stock.
4. Confirmar identidad de la aplicación y conservación de su acceso al contenedor/Keychain. Elegir versión/build y firma para el canal autorizado; este desarrollo conserva los identificadores actuales y no distribuye un IPA.
5. Verificar en dispositivo compatible Face ID/código y Archivos, exportación y relectura real del destino elegido, retorno del segundo plano y recuperación de una interrupción. Las pruebas del simulador no certifican Face ID físico ni un respaldo real del usuario.
6. No ejecutar una transición sobre datos reales sin el respaldo guardado/verificado y la confirmación explícita del propietario.

## Selección de tests en la receta remota

La receta remota que seleccionaba `testProtectedClinicalJourneyAndRelaunch` y `testRelaunchExistingClinicalSourceWithoutSetup` debe actualizarse. Sus equivalentes operativos son `N3ClinicalJourneyTests/testConsolidatedClinicalUnitsAndManualRThenRelaunch` y `N3ClinicalJourneyTests/testIndependentRelaunchShowsConsolidatedSourceWithoutReactivation`. Cada dispositivo de esos tests requiere primero `N2SimpleInventoryNativeTests`; Premium requiere `N2PremiumDemoFixtureTests`. No aceptar una ejecución de cero tests como un PASS.

El script nuevo `scripts/run-n2-simple-v2-acceptance-macos.sh` crea un dispositivo aislado, ejecuta Swift/JavaScript, compila y ejecuta primero 16 pruebas nativas y después ocho de interfaz, comprobando esos conteos. Exige fixtures ficticias ya generadas, no elimina dispositivos existentes ni publica nada. Su sintaxis se comprueba localmente; el informe final distingue las ejecuciones efectivas de los comandos equivalentes de aceptación.

Se conserva además `N3ClinicalJourneyTests/testProtectedClinicalSourceCreationAndRelaunch`: crea únicamente una fuente protegida ficticia en el simulador aislado, mantiene las aserciones de autenticación y verifica el relanzamiento sin onboarding. El recorrido operativo consolidado DEMO no sustituye esta verificación del acceso protegido. Son ocho pruebas de interfaz en el conjunto actual.
