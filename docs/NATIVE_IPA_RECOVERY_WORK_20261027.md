# Recuperación de distribución Premium nativa

Rama: `ci/premium-native-ipa-work-20261027`.
Base auditada: `1e00b8721037cdd2d0c90e4220ce3b18095f2e1e`, descendiente de Premium `2c776e88bc8b83e68ea85060263d204ca57025da`.

## Auditoría previa (27/10/2026)

HEAD verificados con GitHub:

| Rama | SHA |
|---|---|
| main | 19118cc687a65923504a304089b53997935463e8 |
| feat/build222-native-ui-parity-20261020 | 9bec8e01ccbb3f1a674372cf6e48df049dc4f014 |
| feat/n2-premium-redesign-20261026 | 2c776e88bc8b83e68ea85060263d204ca57025da |
| design/glass-clinical-access-home-20261027 | 4f3c0c0dec1a6dbe27988f1577d5e81bb5ffbbea |
| build/native-premium-ipa-20261027 | 1e00b8721037cdd2d0c90e4220ce3b18095f2e1e |
| ci/native-unsigned-device-ipa-20261027 | 465299fa0ae2731b69423953e2877fe888dceaf2 |

No había ejecuciones activas ni en cola. La base añade automatización, documentación y edición explícita del borrador a Premium; no integra Glass ni PR #8.

- Run 40521728126: logs reales y artifact 12743174061 descargados. JavaScript PASS, Swift 383/383 PASS; Release iphoneos BUILD SUCCEEDED; XCTest nativo 15/15 PASS; interacción 3/7 PASS, cuatro fallos. Xcode 16.4 (16F6), SDK 18.5, Apple Swift 6.1.2. Empaquetado NOT RUN por dependencia secuencial de XCTest.
- Biometría: el árbol de SpringBoard contiene entrada de código de iPhone. La inscripción simulada estaba ausente en ese run; el cambio posterior de inscripción aún no se había ejecutado. No demuestra un fallo del Face ID físico.
- Premium: falla la comprobación del sufijo del diagnóstico (línea 59 del SHA antiguo). La selección explícita de todo el texto ya incorporada se conserva; su eficacia sigue pendiente de XCTest real.
- N3 creación: se queda en «Verificando identidad…» y no llega al inicio. No hay evidencia para alterar bóveda o claves.
- N3 relanzamiento: el árbol muestra onboarding 1/4. Dependía de que el método anterior hubiese creado la fuente; al fallar ese método, la precondición no existe. Ahora cada método prepara su propio recorrido ficticio antes de probar la persistencia.
- Run 40522185478: Swift Linux 6.4 falla al verificar el agotamiento previo; la lista de eventos queda vacía y el test accede a `closings[0]`. Se sustituye por XCTUnwrap manteniendo cantidad, R=0, residual -1 y rechazo de adulteración. No se modifica la regla clínica. El nuevo job Linux conserva el fallo y ejecuta la suite completa.
- La comparación de diccionarios Foundation `NSDictionary.isEqual(to:)` en N2ContainerAccounting es una hipótesis de portabilidad a investigar con evidencia; no se declara causa demostrada ni se cambia producción sin prueba.
- Run 40526585973: CANCELLED sin pasos ni artefactos. El log del job no existe (BlobNotFound). El documento previo de la base registra cancelación por el propietario y aviso de capacidad arm64; la respuesta actual del run por sí sola no permite atribuir la cancelación. No es una corrección verificada.
- La conexión rechaza el endpoint `/actions/permissions`; permisos administrativos y restricciones de facturación: BLOCKED para auditoría por API. No se cambian configuraciones sensibles.

## Pipeline

Workflow `.github/workflows/native-premium-ipa.yml`, activado solo en esta rama por cambio del workflow o `ci/native-ipa-request.txt`. Checkout del SHA exacto, lock npm, lock SwiftPM, Xcode 16.4 y XcodeGen 2.46.0 comprobados. Si el runner deja de ofrecer esas versiones, falla explícitamente.

A compila Release iPhoneOS ARM64 sin firma, empaqueta y verifica el ZIP, Mach-O, AppIcon, storyboard, bundle/version/build, recursos sanitizados exactos, ausencia de firma/perfil/datos personales/certificados y checksum. Publica `CANDIDATE_UNSIGNED_NOT_CLINICALLY_VALIDATED_<SHA>` antes de cualquier gate clínico. Procedencia del candidato: pruebas NOT RUN en el momento de publicación, nunca valores PASS prefabricados.

B ejecuta JavaScript y Swift macOS con fixtures sintéticos. B2 ejecuta Swift Linux y deja visibles sus fallos. C compila una sola vez para pruebas y crea un iPhone 16 efímero por método; elimina únicamente esos dispositivos. El borrador Premium se prepara con un fixture explícito en su propio simulador. No hay dependencia entre métodos de interacción. Conserva todos los xcresult, screenshots exportados y logs; también intenta exportar las capturas históricas con xcresulttool.

Los jobs macOS A, B y C se encadenan para no competir. Los fallos de B no ocultan C; las pruebas fallidas conservan salida de error. No se usa continue-on-error. D requiere éxito de A, B, B2 y C, verifica checksum y SHA y añade un manifiesto VALIDATED_UNSIGNED con resultados reales de los jobs. No cambia los bytes del IPA. Si falla un gate, el candidato permanece descargable y D no lo promueve.

Comprobaciones locales: sintaxis Bash, compilación sintáctica Python, estructura YAML y diff sin errores. Verificador probado con paquete sintético aceptado y seis variantes inválidas rechazadas (firma, plataforma, versión, perfil, certificado y Excel privado). No equivalen a compilar iOS. Los resultados actuales de Apple y del motor clínico deben consultarse en el run del SHA final.

## Archivos y alcance

- Workflow: separar candidato, clínica, portabilidad, interacción y promoción.
- `ci-native-prepare.sh`: recursos sanitizados y dependencias resueltas.
- `ci-native-clinical.sh`: generación común de fixtures y suite Swift.
- `ci-native-ui.sh`: XCTest por método con simuladores nuevos y evidencia exportada.
- `package-native-premium-ipa.sh`: nombre inequívoco y versión/build obligatorios.
- `verify-native-ipa.py`: eliminar PASS fijos, comprobar iconos y rechazar formatos privados o certificados.
- `N3ClinicalJourneyTests.swift`: precondiciones propias para el método de relanzamiento.
- `N3DeclaredContainerTests.swift`: informar el evento ausente sin abortar toda la suite.

No se modifican producción SwiftUI, reglas FEFO, Kardex, cifrado, Keychain, grupos de acceso, Bundle ID, cuatro pestañas ni formatos persistidos. No se instala ni desinstala nada en un iPhone.

## Actualización posterior segura

El IPA sigue necesitando firma. Mantener `pe.danper.saludmovil.native.preview` no garantiza acceso a la clave de la instalación actual: también deben coincidir el prefijo App ID/Team y grupos Keychain de la firma efectiva. Antes de cualquier reemplazo, disponer de respaldo cifrado exportado y verificado, contraseña conservada y ruta de recuperación comprobada. No se recomienda uso clínico de un candidato sin completar D. La instalación física queda fuera de esta misión.
