# Diagnóstico local N2 · 22 de octubre de 2026

Rama: `feat/build222-native-ui-parity-20261020`. Base: `75b207e`.

## Causas y correcciones

- El registro `DANPER_N2_PARIDAD_MAC_20261022_233838.log` termina en una aserción sobre dos etiquetas antiguas. Los destinos SwiftUI seguían presentes. La auditoría ahora exige el destino y su identificador de accesibilidad en el mismo enlace, sin depender de la redacción visible. Se comprobó mediante mutaciones en memoria que eliminar cualquiera de los dos destinos hace fallar la auditoría.
- El consumo histórico escribía el movimiento con la fecha clínica y `dispenseRef.confirmedAt` con la fecha actual. La auditoría exige igualdad: la transacción terminaba en `inconsistentHistory`. Ambos campos ahora usan la fecha del evento, manteniendo las restricciones cronológicas de los lotes y la idempotencia.
- Dos pruebas conservaban expectativas anteriores a los commits `a2ca747`, `2f72b5d` y `82b4713`. Se actualizaron para verificar inventario único entre sedes y las presentaciones confirmadas UND/CJA. Los catálogos originales y las 86 asociaciones no se modificaron.
- Otra expectativa de reporte Kardex seguía separando los saldos por sede. Ahora comprueba el mismo inventario conocido en ambos reportes.
- Los fixtures del indicador Planta y conjunto consumían el material `16000013` sin apertura verificada para Planta. Se agregaron apertura y conteo exclusivamente sintéticos; se conservó el rechazo de exportaciones sin conciliación. Con dos materiales contados, las ausencias esperadas pasan de 431 a 430.
- La prueba de alcance DEMO construía una URL de directorio como archivo. Ahora especifica `isDirectory:true`, igual que el destino esperado; no se modificó el permiso de borrado de producción ni se ejecutó un borrado.

## Entorno y límites

Node.js 24.22.0, Xcode 16.2 y Swift 6.0.3. La versión Node satisface `^20.19.0 || >=22.12.0`; el fallo inicial es una aserción de contenido, sin evidencia de incompatibilidad del runtime.

Los 50 scripts de `npm run test:logic`, `npm run build`, las auditorías N2, la generación de fixtures sintéticos y la generación de recursos e icono finalizaron correctamente. Vite informa advertencias de tamaño e importaciones mixtas, sin fallar.

La primera ejecución Swift compiló con `swift test --disable-sandbox --jobs 2`, pero el `TMPDIR` forzado a `/private/tmp` provocó errores de ubicación en los laboratorios sintéticos. No se alteraron sus controles de aislamiento: se recompilaron las pruebas y se ejecutó XCTest con `env -u TMPDIR`, conservando `DANPER_N1_FIXTURE_DIR` con todas las referencias sintéticas generadas. Las primeras ejecuciones fallidas se conservan como evidencia y no se contabilizan como aprobadas.

XcodeGen generó el proyecto. Los intentos de `xcodebuild` sin firma para simulador y dispositivo genérico quedaron bloqueados al evaluar paquetes por `sandbox-exec: sandbox_apply: Operation not permitted`. CoreSimulator también informó conexión rechazada. El acceso concedido a red y cachés no resuelve esa restricción del proceso. No se ha verificado la compilación de la aplicación iOS, ni su ejecución visual, ni su funcionamiento en un iPhone.

No se ejecutaron pruebas que acceden al Keychain, ni restauraciones clínicas reales. No se creó ni instaló un IPA. No hubo merge ni modificaciones en main, Build 222 operativa, respaldos o datos reales. Los artefactos locales de compilación quedan sin incluir en los commits.

## Resultado Swift al cierre · 23 de octubre

La última ejecución completa terminó: 307 pruebas, 5 aserciones fallidas en cuatro casos que aún usaban los fixtures anteriores. No se declara una ejecución completa única en verde.

Todos esos casos se corrigieron y verificaron después: las cuatro pruebas de inventario/provisional pasaron sin fallos; Planta pasó con el fixture completo; las tres pruebas de alcance DEMO pasaron; el libro conjunto pasó tras corregir las dos expectativas de materiales pendientes. Las seis pruebas de transacciones, incluida la regresión explícita de fecha histórica, pasaron; las ocho pruebas del formulario también pasaron. No quedan fallos observados sin corrección y repetición específica, pero falta repetir la suite completa sobre la revisión final y compilar la aplicación fuera de la restricción externa de Xcode.

Los registros completos distinguen compilaciones, ejecuciones iniciales fallidas y regresiones posteriores. El resultado de Swift Testing de cero pruebas no se usa como evidencia: los conteos anteriores proceden de XCTest.
