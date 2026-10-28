# Auditoría independiente Glass Clinical + Clinical Pro / Kardex v2

## Entradas verificadas

- Repositorio: `r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn`.
- Entrega: `feat/swiftui-v2-glass-clinical-pro`, HEAD `20b8ae6cc799dd88f952f6b6dc04316a51ac97b4`, árbol `ce8150e0bffe6267769ebfeb19cc590abe279734`.
- Padre/código local comunicado: `6869b526a7158c55fbb09f939a549028091e2166`. HEAD añade exclusivamente `docs/GLASS_CLINICAL_PRO_CORRECCIONES_FIDELIDAD.md`, 42 líneas, sin cambios de aplicación.
- Base/ancestro Kardex v2: `1c131e1e3b46b704b9621914369f9fdf7138a1b9`. Comparación: 23 commits, 34 archivos. Sin cambios de `native-ios/Sources/DanperCore`.
- Correcciones exclusivamente en `audit/glass-pro-iloader-20261028`, creada desde HEAD publicado. Sin merge ni modificación de entrega/main/estables/Premium/Glass originales.

## Revisión de cambios

Se inspeccionó el diff completo desde la base, incluyendo las rutas Swift de aplicación, recursos, pruebas y documentación. Núcleo clínico, esquemas, validadores, journals cifrados, respaldos, migración, restauración selectiva, escritores Excel y catálogos conservan sus blobs. Los cambios de las hojas de exportación asignan únicamente `overrideUserInterfaceStyle` al controlador de compartir. El flujo LAContext y N2AccessSession conserva su implementación; acceso y bloqueo en segundo plano mantienen sus controles.

Las cuatro pestañas y los destinos existentes se conservan. Ver todas reutiliza Herramientas. El nombre visible usa UserDefaults y no sustituye la identidad clínica. La clasificación depende de correspondencias autorizadas; Todos devuelve todos los productos registrados. No se reintroducen rutas FEFO, lotes automáticos ni conversiones. El vencimiento es referencia manual independiente del saldo.

Esta revisión estática no equivale a aprobar ejecución en Xcode ni restauración real. Los informes originales contienen resultados locales y enlaces absolutos al Mac del autor, no evidencia CI accesible.

## Hallazgos y cambios

- El workflow antiguo exigía `App/N1sDemoResources/n2-synthetic-clinical.json`, pero el generador lo elimina expresamente de la aplicación y lo coloca en NativeTests. Se sustituyen las exigencias obsoletas por comprobaciones de ambos lugares.
- `glass-final-audit.yml` centraliza la validación; el workflow Xcode anterior delega al nuevo. Descubre todas las clases UI desde código, sin exclusiones, y exige 11 casos. Simuladores nuevos por clase y prerequisitos DEMO nativos explícitos.
- La suite nativa de activación vacía corre antes de poblar DEMO, en su propio simulador limpio.
- Nueva prueba exhaustiva: 432 códigos, 38 medicamentos, 53 insumos, 341 pendientes visibles en Todos. Suite nativa: 22 (21 originales + 1 nueva); no se elimina ningún caso.
- Variante iLoader: `pe.danper.saludmovil.native.iloaderpreview`, versión `0.4.2`, build `12` (entrega: `0.4.1` / `11`). Ambos targets de pruebas ajustados.
- Cinco servicios Keychain separados; se conservan cuentas, AES, WhenUnlockedThisDeviceOnly y no sincronización. Directorios Application Support relativos al sandbox; sin App Groups ni grupos Keychain explícitos. El aislamiento físico depende también del application-identifier y entitlements aplicados por iLoader.

- Fallo reproducido en control adicional PERSONAL: esperaba `N1eLegacyClinicalAudit.inspect(next)`, sustituido antes de la base por `N2VersionedSnapshotAudit.inspect(next)` en `32dc07d`. Se actualiza el guard para exigir auditoría de entrada y salida, rechazo de versión desconocida/booleana, auditor v2 y fallback legado estricto. Se conserva N1fLosslessFieldGate. Sin cambio de producción para conseguir PASS.

## Suites reproducibles

- 50 scripts originales de `npm run test:logic`, inventario exacto en package.json.
- Ocho controles iniciales enumerados en `scripts/glass-audit/javascript.cjs`, ampliados a 12 con PERSONAL, indicador conjunto, consentimiento e identidad. Logs y estado individuales JSON. No hay manifiesto publicado que permita demostrar que los «8 controles» locales eran exactamente los mismos ocho comandos.
- 412 Swift esperados con las doce familias de fixtures; cero omisiones.
- Dos verificaciones adicionales tras Swift: `test-n1r-native-xlsx.cjs` y `test-n1s-full-native-workbooks.cjs`, sobre archivos realmente exportados por Swift.
- Xcode build-for-testing y target nativo completo: 22 casos (21 originales + 1 nuevo).
- UI: N2BiometricInteractionTests (1), N2Build222ShellTests (1), N2GlassClinicalTests (3), N2MenuInteractionTests (1), N2PremiumRedesignTests (2), N3ClinicalJourneyTests (3): 11. Las siembras nativas se registran aparte, sin inflar el total.
- Cada resumen xcresult exige conteo esperado, cero fallos y cero omitidos. Capturas reales se extraen de attachments.

## Repetición local macOS

Requisitos: Xcode completo seleccionado, runtime iOS con iPhone 16, Node 22.12+, npm, XcodeGen (`brew install xcodegen` si falta).

```bash
git clone https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn.git DANPER-AUDITORIA
cd DANPER-AUDITORIA
git switch audit/glass-pro-iloader-20261028
git status --short
git rev-parse HEAD
export DANPER_AUDIT_OUT="$HOME/Downloads/DANPER-GLASS-AUDITORIA-$(date +%Y%m%d-%H%M%S)"
bash scripts/glass-audit/validate-macos.sh
# Solo tras salida 0 de la validación:
bash scripts/glass-audit/package-macos.sh
```

Solo crea y elimina sus propios simuladores nuevos; no borra existentes ni conecta iPhone. El empaquetador exige VALIDATED_SHA idéntico a HEAD y ausencia de cambios rastreados de fuentes. Falla ante identidad, versión, arquitectura, firma, recursos o hash incorrectos.

Salida: logs individuales, SOURCE_SHA/TREE, versión Xcode, inventario UI, xcresult, JSON y attachments. El IPA se publica solo tras validación completa, con DANPER_BUILD.json incrustado, manifiesto por archivo y SHA-256. Compila el nuevo SHA de variante, nunca se atribuye al SHA anterior.

Estado de ejecución se documentará al terminar CI. Este documento no es un PASS. Pendientes: iPhone físico, firma iLoader, VoiceOver manual, Reducir transparencia, Reducir movimiento y migración clínica real. Solo datos sintéticos.

## Segunda ejecución independiente y corrección de entorno

Run 40782758469 / SHA 47f946c9faee7179ae9bfcac905b26fcec54af24: 412 Swift, 50 JS + 12 controles, dos comparaciones XLSX y build-for-testing aprobados. XCTest nativo 22/22, cero fallos/omisiones, iPhone 16 ARM64 / iOS 26.2. Artefacto 12858729958, SHA256 c8c3ed91b672a4a29dc0b33f712a2e38ec871c8df72a5dbf1373b658b7d0a06e. El paquete descargado coincide con ese hash.

Primer caso UI falló en N2BiometricInteractionTests.swift:31: el sistema presentó un botón «cancelar» minúsculo en la pantalla de código; el selector esperaba Cancel/Cancelar. Los otros diez casos no se ejecutaron porque el script se detenía al primer fallo. No hubo IPA.

Se corrige únicamente el selector de Cancelar para admitir las mismas dos palabras sin distinguir mayúsculas; se mantienen todas las aserciones y la política LAContext. Se selecciona el runtime coincidente con el SDK de Xcode (18.5 en este runner), en lugar de escoger silenciosamente el mayor instalado (26.2). iOS 26.2 no queda aprobado por esta corrida fallida.

Se añade una comprobación nativa real de canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics) y biometryType Face ID: el total final esperado pasa a 23 (21 originales + catálogo exhaustivo + disponibilidad biométrica). No se permite pasar con solo el código ni simulando un éxito en la aplicación. Se publican resultados nativos antes de iniciar UI. Cada clase UI conserva su resultado y attachments incluso cuando falla, y las restantes clases continúan para no perder cobertura diagnóstica. El empaquetado sigue bloqueado si falla cualquier caso.

El run 40787275025 (24c03fc) permaneció en cola macos-15 ARM64 sin iniciar pruebas. Se cambia a macos-15-intel estándar, que el inventario oficial actions/runner-images documenta con Xcode 16.4 e iOS Simulator 18.5. El IPA sigue compilándose para iphoneos ARM64 mediante ARCHS=arm64; la arquitectura del host no se confunde con la del producto. La sustitución cancela la corrida pendiente para evitar duplicar validaciones. No se atribuyen pruebas al SHA que quedó en cola.
