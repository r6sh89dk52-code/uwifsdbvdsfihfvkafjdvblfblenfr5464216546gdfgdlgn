# Correcciones del rediseño nativo DANPER

Solicitud del 26 de octubre; validación final del 27 de octubre de 2026.

Rama: `feat/n2-premium-redesign-20261026`. Base: `903fe9b`. Se mantiene versión **0.4.1 (11)** y bundle ID `pe.danper.saludmovil.native.preview`. La rama estable `feat/build222-native-ui-parity-20261020` y `main` quedan fuera de esta entrega.

## Cambios

- **Teclado:** el formulario quita completamente la barra Anterior/Siguiente cuando aparece el teclado. La restaura con transición al ocultarlo, respetando Reducir movimiento. Mantiene el botón Ocultar teclado y solicita revelar el campo de diagnóstico.
- **Editor único:** Nueva atención, borradores reanudados y acceso desde Alergias presentan `DanperAttentionEditor`, con la misma NavigationStack, hoja, encabezado, controles y lógica de teclado. Ya no se navega a un formulario de borrador debajo de la cabecera y las pestañas principales. El editor se cierra al pasar a segundo plano para quedar detrás del bloqueo de la aplicación; conserva el autoguardado cifrado existente.
- **Cápsula inferior:** reserva su altura intrínseca real en el layout vertical, incluyendo sus márgenes. Los contenedores de navegación y scroll reciben el espacio restante. No depende de un padding fijo que podría fallar con texto grande o safe areas distintas. El editor se presenta encima del contenedor principal y sus pestañas no son interactuables mientras está abierto.
- **Materiales:** tarjetas secundarias, barras y hoja utilizan materiales nativos compatibles con iOS 17+, bordes finos, reflejo y sombra discretos. Reducir transparencia utiliza superficies sólidas. Es una aproximación compatible al concepto Liquid Glass mediante materiales disponibles en el SDK utilizado.
- **Acceso:** proporciones ajustadas del hero laboral, bloque biométrico y bienvenida. Conserva marca, Face ID automático, código del dispositivo, protección clínica y versión real del bundle. El recurso fotográfico original del rediseño se reutiliza.
- **Arranque:** comprueba primero la existencia de archivos de la fuente. Con fuente existente, muestra bloqueo o experiencia clínica, aunque la preferencia antigua de onboarding falte o esté explícitamente desactivada. La presencia de la fuente se guarda en un estado independiente de esa preferencia. Durante la comprobación presenta un estado neutro. La configuración vacía aparece únicamente después de verificar la ausencia de una fuente; una fuente ilegible muestra error y no habilita reemplazarla. Se elimina la entrada repetida al espacio clínico; Ajustes ofrece Bloquear aplicación.

## Optimizaciones

- Autenticación: al resolver la presencia de la fuente, la nueva renderización programa el intento automático con el ciclo de ventana actualizado. La reserva se realiza después de estabilizar la ventana y las transiciones inactivas previas no consumen el intento. Se conserva un único intento por entrada y el reintento manual tras cancelación.

- Conserva el árbol clínico tras el primer acceso durante esa ejecución; lo oculta, deshabilita y excluye de accesibilidad mientras está bloqueado. Evita reconstruir todo al regresar de segundo plano.
- Dashboard: compara revisión del diario y día local antes de recalcular contadores; no reabre contadores sin cambios. Refresca tras autenticación y cambios relevantes.
- Borradores: evita releer una revisión ya cargada y válida; vuelve a comprobar al cerrar el editor y después de eliminaciones.
- Formulario: índice de trabajadores por DNI; las sugerencias de procedimiento se recalculan solo al cambiar productos/procedimientos, no en cada carácter del diagnóstico. Conserva la preparación de contexto y borradores en una sola revisión.
- Cachea únicamente recursos JSON inmutables del bundle dentro del actor. No incorpora caché persistente de datos clínicos descifrados ni cambia llaves, cifrado, respaldo, migraciones o FEFO.
- Divide el cuerpo SwiftUI del formulario en componentes para mantener una compilación verificable sin cambiar las reglas clínicas.

## Archivos

Aplicación, bajo `native-ios/App/`:

- `DanperPremiumPresentation.swift` — nuevo contenedor compartido, señal de teclado, layout de cápsula, superficies y sesión autenticada.
- `DANPERNativeApp.swift` — arranque, conservación de sesión, bloqueo y composición del acceso.
- `N2ClinicalWorkspaceView.swift` — fuente verificada, inicio clínico directo, navegación y contadores.
- `NativeRootView.swift` — misma presentación compartida en DEMO.
- `N2NativeDraftsDashboard.swift` — borradores en el mismo editor y actualización por revisión.
- `N2NativeClinicalFormView.swift` — teclado, índice de DNI y recálculo acotado de sugerencias.
- `N2ProtectedClinicalIOSVault.swift` — consulta de presencia y caché de recursos del bundle.
- `DanperUITheme.swift`, `DanperPremiumUI.swift` — materiales en barras y tarjetas.

Pruebas:

- `native-ios/InteractionTests/N2PremiumRedesignTests.swift` — teclado en nueva/reanudada, escritura, restauración de acciones, cápsula y segundo plano.
- `native-ios/InteractionTests/N2BiometricInteractionTests.swift` — espera explícita del permiso inicial de Face ID en simulador.
- `native-ios/InteractionTests/N3ClinicalJourneyTests.swift` — recorrido clínico y relanzamiento con fuente existente sin depender del flag de onboarding.
- `scripts/audit-n2-workspace-routing.cjs`, `scripts/test-n2-workspace-routing.cjs` — protecciones del arranque y mutaciones que deben rechazarse.
- `scripts/test-n2-build222-ui-parity.cjs`, `scripts/test-n2-premium-redesign.cjs` — invariantes del contenedor unificado y layout.

## Cómo probar en iPhone físico

Desde este repositorio, con cualquier trabajo propio previamente guardado:

```sh
cd /Users/felipeazcarate/Downloads/DANPER-N2-Paridad
git fetch origin
git switch feat/n2-premium-redesign-20261026
git pull --ff-only origin feat/n2-premium-redesign-20261026
cd native-ios
xcodegen generate
open DANPERNative.xcodeproj
```

En Xcode seleccionar esquema `DANPERNative`, el iPhone conectado y el Team que ya firma la app. Mantener el identificador del bundle y ejecutar **Run (⌘R)** para actualizar la instalación existente. No desinstalarla ni borrar sus datos. Las suites automáticas crean registros ficticios: ejecutarlas en simulador aislado, no sobre una instalación con información propia.

Comprobar en el dispositivo:

1. Con datos restaurados, abrir en frío, autenticar y volver desde segundo plano: no debe aparecer configuración vacía ni un botón para entrar al espacio clínico. Bloquear aplicación debe llevar al acceso biométrico.
2. En Nueva atención y en un borrador, escribir y copiar/pegar diagnóstico: Anterior/Siguiente desaparecen mientras está el teclado; Ocultar teclado los restaura. Ambas rutas tienen la misma hoja y botón Cerrar.
3. Desplegar productos y procedimientos, recorrer formularios largos y Ajustes: ningún control queda bajo la cápsula. Repetir con tamaño de texto grande y modos claro/oscuro.
4. Editar y cerrar un borrador, reabrirlo y verificar contenido; eliminar solo uno de prueba y comprobar que desaparece también después de relanzar.
5. Verificar contadores tras guardar, navegación y tiempos de apertura sobre el padrón real; comprobar versión 0.4.1 y compilación 11. Revisar el respaldo habitual sin reemplazar la fuente.

No se ha instalado esta actualización en un iPhone físico desde esta tarea. La mejora perceptible de rendimiento y el comportamiento de Face ID físico requieren esta comprobación; las evidencias automáticas proceden del simulador y de fuentes sintéticas.

## Validación final

- **383/383 pruebas Swift**: cero fallos (`swift-full.log`). No se modificó el núcleo clínico ni el formato cifrado.
- **61/61 comprobaciones JavaScript**: cero fallos sobre el código final (`audits-results.json`), incluidas restauración, FEFO, Excel, aislamiento y presentación.
- **22/22 pruebas nativas y de interfaz**: una ejecución completa desde un iPhone 16 Simulator nuevo, iOS 18.3.1, con cero fallos (`Acceptance.xcresult`, `acceptance-summary.json`, `acceptance.log`). Xcode terminó con `TEST SUCCEEDED`.
- Las 15 pruebas nativas incluyen interoperabilidad del respaldo cifrado, distribución en claro/oscuro y texto accesible. Las siete de interfaz cubren biometría automática/cancelación/reintento/segundo plano, navegación, menús, acceso, edición nueva/reanudada y recorrido clínico.
- El editor exige un teclado en pantalla de más de 150 puntos, comprueba escritura en diagnóstico, desaparición de acciones y cápsula interactuable, restauración de controles y cierre al entrar en segundo plano.
- El recorrido crea una fuente exclusivamente ficticia, registra lotes y atenciones, verifica bloqueo de apertura adicional, reutilización con R=0, historial, envase abierto y Kardex después de relanzar con onboarding desactivado. Una segunda prueba repite expresamente ese arranque sobre la fuente existente.

Las ejecuciones de diagnóstico detectaron y permitieron corregir el retorno después de crear la fuente, la dependencia de la preferencia de onboarding y la coordinación del intento automático tras resolver la fuente. También se hizo explícita la espera del permiso inicial de Face ID en el simulador. Esos logs se conservan separados; la aceptación final completa pasó.

Se revisaron visualmente las capturas del borrador con teclado completo, el mismo editor con barra restaurada, acceso y tamaño de texto accesible. Las imágenes de `capturas/` proceden de Simulator y contienen únicamente registros ficticios. No acreditan rendimiento ni Face ID en un iPhone físico.

## Compilación y alcance

Compilación mediante Xcode 16.2, SDK iOS 18.2 y ejecución en runtime iOS 18.3.1. Se conservan iOS mínimo 17, versión 0.4.1 (11), bundle y configuración de firma del proyecto. No se añadieron dependencias. No se creó IPA, no se instaló ni se borró una app en iPhone físico y no se accedió a una fuente clínica real para estas pruebas.

Referencias remotas preservadas: `main` en `19118cc687a65923504a304089b53997935463e8`; rama estable `feat/build222-native-ui-parity-20261020` en `9bec8e01ccbb3f1a674372cf6e48df049dc4f014`. La publicación se limita a la rama del rediseño.
