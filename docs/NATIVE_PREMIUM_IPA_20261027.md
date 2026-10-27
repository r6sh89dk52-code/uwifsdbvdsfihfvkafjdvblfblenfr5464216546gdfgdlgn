# IPA SwiftUI nativo en GitHub

## Fuente auditada

Repositorio: `r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn`.

HEAD comprobados el 27/10/2026:

| Rama | Commit |
|---|---|
| main | 19118cc687a65923504a304089b53997935463e8 |
| feat/build222-native-ui-parity-20261020 | 9bec8e01ccbb3f1a674372cf6e48df049dc4f014 |
| feat/n2-premium-redesign-20261026 | 2c776e88bc8b83e68ea85060263d204ca57025da |
| design/glass-clinical-access-home-20261027 | 4f3c0c0dec1a6dbe27988f1577d5e81bb5ffbbea |

La rama de construcción parte de Premium. No integra el PR #8 (abierto, borrador), que parte de la base anterior. Reemplazar Premium con Glass perdería el editor unificado, las cuatro pestañas, la gestión del teclado y las correcciones de arranque. Se preservan las ramas originales.

La ejecución 40519139035 terminó cancelada: Linux falló y macOS compiló para simulador antes de cancelarse durante XCTest. La 40516590929 falló: compilación correcta, Keychain -34018 con CODE_SIGNING_ALLOWED=NO y fallos de interfaz. Ninguna produjo IPA.

Los fallos Linux de la rama Glass incluyen expectativas anteriores sobre la exportación provisional y el cierre del envase. Premium ya contiene pruebas más precisas: R=1000 para una unidad individual declarada en exportación provisional; físico residual -1 y R=0 al agotar un envase previamente abierto. No se trasladan cambios del núcleo clínico desde Glass. Este pipeline ejecuta las suites completas de Premium para verificarlo de nuevo.

## Ejecución controlada

Workflow: `.github/workflows/native-premium-ipa.yml`.

Solo se activa por push en `build/native-premium-ipa-20261027` cuando cambia el propio workflow o `ci/native-ipa-request.txt`. Para solicitar otra construcción, editar ese archivo en la misma rama. También puede usarse **Re-run all jobs** sobre una ejecución existente para reconstruir su mismo SHA. `workflow_dispatch` queda declarado para un eventual registro en la rama predeterminada; no se depende de él ni se modifica main para habilitarlo.

Usa macos-15 y el Xcode seleccionado por el runner, registrando su versión y SDK reales. Instala XcodeGen si falta. Ejecuta JavaScript, auditorías nativas, todas las pruebas Swift, compila Release iphoneos ARM64 y ejecuta XCTest de aplicación/interfaz con iPhone 16. El simulador lleva firma ad hoc para Keychain; la aplicación Release del iPhone queda sin firma. Un fallo impide publicar el IPA y conserva diagnósticos.

Después empaqueta `Payload/DANPERNative.app` y verifica CRC, plataforma Mach-O iOS, ARM64, ausencia de firma y perfil, bundle ID, versión/build, storyboard, Assets.car y los ocho recursos sanitizados. Cada recurso debe coincidir exactamente con el generado. No empaqueta copias clínicas ni fixtures de trabajadores; los fixtures de XCTest viven fuera del producto Release.

Artifact `DANPER_NATIVE_PREMIUM_UNSIGNED_<run-id>` contiene IPA, `SHA256SUMS.txt` y `BUILD_PROVENANCE.json` (SHA fuente, Xcode, versión y resultado de validación). El enlace se publica en el resumen. Retención: 14 días para IPA y 7 para diagnósticos; descargar antes de su vencimiento. La rama conserva la receta para reconstruir.

## Firma y conservación de datos

Se conserva `pe.danper.saludmovil.native.preview`, versión 0.4.1 y build 11 desde project.yml. No se necesitan credenciales Apple para compilar y no se instalan aplicaciones en dispositivos físicos.

El IPA necesita firma compatible con el dispositivo. Conservar el bundle ID por sí solo no garantiza conservar acceso a la bóveda: el prefijo App ID/Team y los grupos de acceso al Keychain también dependen de la firma. Cambiar de equipo o de identificador puede dejar inaccesible una clave anterior o crear otra instalación. Antes de reemplazar la aplicación operativa, exportar desde ella un respaldo cifrado verificable y conservar su contraseña; preferir el mismo equipo e identidad de aplicación y comprobar los identificadores finales del instalador. Este pipeline no cambia Keychain, certificados, respaldos ni instalación existente.

El error de iLoader 7252 corresponde al certificado del equipo seleccionado y debe resolverse en el instalador. No se revocan certificados ni se desinstala la aplicación como parte de esta entrega.

Referencias: [GitHub workflow_dispatch](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow), [runner macos-15](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md), [Apple App ID prefixes y Keychain](https://developer.apple.com/library/archive/technotes/tn2311/).
