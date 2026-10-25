# DANPER SwiftUI: publicación y verificación del 23/10/2026

## Alcance y publicación

Se trabajó exclusivamente en `feat/build222-native-ui-parity-20261020`, repositorio de pruebas `r6sh89dk52-code/danper-salud-movil-pruebas`. Los commits `0ec2a60` y `fccce39` pertenecen a su historia. Se añadieron exclusiones de artefactos generados y el archivo de resolución de dependencias Swift en `3f2f73a`; el árbol quedó limpio antes del primer push normal. Ese push publicó ambos commits anteriores y `3f2f73a`, sin force, merge ni cambios en main.

Esta acta complementa `N2_INTEGRAL_20261023.md`: los resultados de aquella intervención no se confunden con las nuevas comprobaciones. El hash exacto final y su igualdad con GitHub se registran al terminar en la entrega local y en la respuesta; el commit que contiene esta acta no puede incluir su propio hash.

## Revisión de implementación, no solo de documentación

| Solicitud | Implementación revisada | Evidencia y límite |
| --- | --- | --- |
| Bienvenida y autenticación automática | `DANPERNativeApp`, `N2AccessSession`, entrada autenticada de `N2ClinicalWorkspaceView` | LocalAuthentication real del sistema en Simulator, con resultados biométricos simulados; cancelación, reintento y retorno al primer plano. No es Face ID físico. |
| Vencimiento DD/MM/AA | `N2ExpiryTextField`, `N2ExpiryEntry`, comandos de inventario | Pruebas gregorianas y de pegado, corrección y cursor UIKit. Persistencia ISO conservada. Esta comprobación corresponde al vencimiento, no a cambiar indiscriminadamente todas las fechas históricas/Excel. |
| Tratamiento sin elegir sede de dispensación | `N2NativeClinicalFormView`, `N2MedicationRowView`, transacciones | Revisión del formulario y captura del tratamiento; FEFO y casos de dos sedes sobre el mismo stock en el núcleo. La sede laboral sí se conserva. |
| Correspondencias oficiales y operativas | `N2OperationalMapping`, su vista y rutas de bóveda | 86 oficiales intactas. Regla operativa con evidencia, consentimiento y conversión; no pasa a ser aprobación oficial por guardarse. |
| Frascos, apertura y consumo abierto | `N2ClinicalTransactions`, reglas y evidencia de pendientes | Alcohol sintético: 2 frascos de 1000 mL, 2 usos de 5 mL, una apertura, 990 mL abiertos restantes y R contable `[1,0]`. |
| Resultado y pendientes | Formulario, `N2PendingDispensingView`, `N2PendingDispensingEvidence` | Se corrigió una carencia: poder completar cantidad/apertura después de guardar, conservando inalterados los campos clínicos originales. |
| Auxiliares e inventario único | `N2AuxiliaryInventory`, rutas clínica/DEMO, motor común | Productos AUX con evidencia y stock contado, contabilidad separada; no se agregan filas al Kardex de 98 ni un inventario por sede. |
| Exportación | Escritores y pruebas de libros originales | Indicador de 10 hojas, fórmulas y Kardex de 98 productos, conciliación, R y trazabilidad. No se usaron respaldos ni historias reales. |

## Defectos encontrados y correcciones nuevas

1. Las pruebas de pantallas dependían de un JSON clínico que ya no se incluye en la aplicación. La generación ahora deposita ese fixture en recursos exclusivos del target de pruebas; también se corrigió el test de interoperabilidad que antes omitía esa comprobación por el mismo motivo. No se volvió a introducir una base precargada en la app.
2. Un consumo pendiente por cantidad física/apertura no disponía de un mecanismo completo para aportar esa evidencia una vez guardado. Se añadió una hoja explícita con lote, cantidad, autorización de apertura, responsable, motivo y consentimiento. La evidencia se guarda separada de la atención y se aplica mediante una transacción de bóveda con revisión esperada; el movimiento conserva el ID de evidencia. No se altera la cantidad clínica original ni se crea otra atención.
3. Se reforzó la cronología de todos los reintentos, incluso del mismo día: un lote con conteo/movimientos posteriores a la hora clínica no puede descontarse otra vez del saldo actual. Una evidencia no permite saltarse esta protección. Las reglas operativas posteriores requieren evidencia explícita y siguen sujetas a esa cronología.
4. La captura del inicio protegido resultaba vacía porque el host de prueba no tenía una escena activa. El harness fija una escena activa; se conserva la protección de privacidad de la aplicación y la aserción que rechaza imágenes vacías. Los inicializadores de datos de captura son solo DEBUG y evitan leer bóvedas.
5. Se corrigió una interacción frágil de XCTest: antes de tocar el menú final se comprueba visibilidad y se pulsa su centro, evitando el fallo intermitente de desplazamiento AX. No se eliminó la comprobación del menú ni del resultado.

El log original `DANPER_N2_PARIDAD_MAC_20261022_233838.log` muestra un `ERR_ASSERTION` por una etiqueta antigua exigida literalmente por `audit-n2-build222-backup-restore.cjs`; no muestra un fallo de ejecución propio de Node 24.22.0. La auditoría actual y los scripts de lógica se ejecutaron con esa versión, sin cambiar de runtime para esconder el problema.

## Método de pruebas de interfaz

Se creó un iPhone 16 Simulator independiente con iOS 18.3.1. Las capturas de pantallas usan las vistas SwiftUI reales alojadas en UIKit con proyecciones ficticias: bienvenida, inicio clínico, registro/evaluación, tratamiento, inventario y lote, Kardex, historial, revisión, atención guardada y conciliación pendiente; modos claro/oscuro y algunos tamaños de texto accesible. Prueban renderizado, no una atención persistida por el usuario de extremo a extremo.

Los tests de interacción lanzan DANPERNative: los probes DEBUG existentes prueban cuatro pestañas, accesos, menús anclados, desplazamiento, teclado y selección de Paracetamol/Diclofenaco. No se contabilizan como prueba de autenticación ni de persistencia clínica. Por separado, el test biométrico no usa esos probes ni un desbloqueo ficticio: salta únicamente el onboarding, espera el intento automático de LocalAuthentication sin tocar Ingresar, simula no coincidencia, cancela el diálogo del sistema, verifica ausencia de bucle, reintenta, simula coincidencia y verifica la selección segura de fuente; vuelve al inicio del dispositivo y repite la entrada automática.

## Comparación visual con Build 222

Se navegó la referencia web local del código original, versión 0.21.12 Build 222, sin añadir pacientes ni lotes. Se guardaron capturas de inicio, registro, Kardex, inventario e historial. El código y los recursos de referencia no se modificaron.

Se conservan identidad DANPER rojo/blanco, cabecera con logotipo, acción Nueva atención, contadores, herramientas y cuatro pestañas inferiores. Hay diferencias observables: tipografía y escala/espaciado nativos, tamaño de cabecera, controles de selección, tarjetas del Kardex y distribución del historial; el inicio protegido no muestra el saludo personal del shell DEMO. La referencia web y las capturas UIKit no tienen idéntico viewport ni los mismos datos. Las pantallas aisladas no demuestran por sí solas la presencia de la barra inferior durante todos los flujos.

No se declara paridad visual completa, igualdad píxel a píxel ni comparación contra la Build 222 operativa instalada en un iPhone. No se dispone de evidencia visual equivalente para todos sus diálogos, resultados, transiciones o teclado físico. Las diferencias se documentan, no se atribuyen falsamente al simulador ni se ocultan con tests estáticos.

## Preservación y aceptación pendiente

Sin cambios versionados en `src` ni `App/N1sDemoResources`: se preservaron catálogos, presentaciones, 432 productos clínicos, 98 de Enfermería, 86 correspondencias y 155 áreas. Se verificaron FEFO, apertura, cajas abiertas, lotes agotados/insuficientes, ambigüedad, pendientes e idempotencia con fixtures, no con datos reales. No se tocó main, Build 222 operativa, respaldos reales ni Keychain de producción; no se generó ni instaló IPA.

La aceptación física sigue requiriendo una app firmada en iPhone: Face ID real y código, interrupciones de LocalAuthentication, Keychain con sus entitlements, ciclo de vida y persistencia tras relanzar, teclado/desplazamiento y un flujo clínico ficticio completo de varias medicaciones. Las equivalencias y capacidades de uso real requieren aprobación del responsable; las reglas sintéticas de pruebas no se precargan en producción.

## Resultados finales verificables

| Comprobación | Resultado |
| --- | --- |
| Núcleo Swift completo sobre el motor final | 320 pruebas, cero fallos; 563,365 segundos. |
| Regresión específica de transacciones, reglas y evidencia | 14 pruebas superadas, cero fallos, con aserciones adicionales de persistencia cifrada y revisión atómica; 2,307 segundos. Se ejecutó después de la suite completa al ampliar estas aserciones, sin nuevos cambios en el motor. |
| Suite completa Xcode / iPhone 16 Simulator | 16 casos: 15 superados, 1 omitido, cero fallos. `TEST SUCCEEDED`, compilación sin firma incluida. |
| Biometría simulada | Un test de interacción superado: solicitud automática, cancelación, reintento y vuelta al primer plano. |
| Node 24.22.0 | `npm run test:logic`: 50 scripts superados. Tres auditorías N2 adicionales superadas, incluidas 34 rutas de bóveda y 13 vistas. |
| TypeScript/Vite | `npm run build` superado; advertencias no bloqueantes de imports/chunks. |
| Recursos | Generación sintética y validaciones de catálogos superadas; ocho recursos de app sin padrón clínico precargado, fixture clínico exclusivo del target de pruebas. |
| Preservación | `git diff --exit-code fccce39 -- src native-ios/App/N1sDemoResources` y `git diff --check` satisfactorios. |

El caso omitido es `testExplicitSyntheticN2ActivationEnablesClinicalTabsWithoutRealBackup`: Security.framework devolvió `errSecMissingEntitlement (-34018)` al acceder al Keychain de la aplicación de pruebas sin firma. Es un bloqueo externo concreto para verificar en este entorno la activación/persistencia clínica completa por interfaz. No se deshabilitó cifrado/autenticación ni se sustituyó Keychain por un almacén inseguro. Los escenarios transaccionales ficticios sí se ejecutaron en el núcleo y los flujos visuales/interactivos descritos sí se probaron, pero no equivalen a una atención completa persistida desde la UI sobre una app firmada. No se contabiliza la prueba omitida como éxito.
