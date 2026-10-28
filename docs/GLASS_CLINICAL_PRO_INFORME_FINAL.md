# DANPER — Glass Clinical + Clinical Pro

Implementación SwiftUI real sobre Kardex v2. Repositorio: `/Users/felipeazcarate/Downloads/DANPER-N2-Paridad`. Rama exclusiva: `feat/swiftui-v2-glass-clinical-pro`. Base verificada: `1c131e1e3b46b704b9621914369f9fdf7138a1b9`. Último cambio de la app: `7585049`. Última comprobación de regresión: `668f02b`.

## Implementación

- Vidrio negro con Material real, reflejos discretos, bordes finos y fallback de Reducir transparencia. Fondos carbón con esquema oscuro solicitado desde la raíz SwiftUI, incluso si iOS está en claro, sin cabecera roja opaca. La preferencia existente de apariencia permanece operativa en las hojas nativas de compartir.
- Acceso con el retrato exacto, logo real, lema, curvas nativas translúcidas, Face ID y código del dispositivo. Versión/build del Bundle. No se cambia LAContext ni el ciclo de bloqueo.
- Inicio con avatar ilustrado exacto, saludo genérico, Nueva atención, cifras reales Hoy/Semana/Mes, cuatro herramientas originales y Ver todas conectado a Ajustes. DEMO permanece señalizada discretamente. Campana decorativa sin acción ni alertas inventadas.
- Inicio / Historial / Borradores / Ajustes conservan destinos y estado funcional. La barra tiene región de layout propia y se oculta con teclado.
- Formularios, trabajadores, historial, ajustes, exportaciones, activación, respaldos y restauración comparten las mismas superficies; campos, orden, reglas y acciones permanecen.
- Kardex mantiene filtros fijos Todos / Medicamentos / Insumos y búsqueda por nombre/código/presentación. Filas con icono coherente, unidad original, saldo grande, vencimiento visible y cuatro estados con texto. Stock cero es una indicación separada. Detalle/movimientos/ingreso/salida/conteo/vencimiento y acciones generales continúan disponibles.

## Categorías y vencimientos

El catálogo clínico de 432 códigos no contiene una categoría para todos sus productos. Los grupos y correspondencias autorizados permiten clasificar 38 medicamentos y 53 insumos (91 códigos distintos). Los otros 341 se mantienen en Todos con Clasificación pendiente; no se inventan asignaciones. Los filtros operan sobre productos registrados, sin crear existencias. Se conserva el umbral inclusivo de 30 días en Lima; hoy no se trata como vencido. Una fecha sin verificar se muestra Pendiente de verificar.

## Seguridad y regresión

No hay cambios en `native-ios/Sources/DanperCore`, bóvedas, router de fuente, cifrado, Keychain, autenticación ni formatos clínicos. La categorización es un helper de presentación sin acceso de escritura. No se reintroducen FEFO, lotes operativos, aperturas automáticas ni conversión de unidades. Se preservan declaración manual R=1/R=0, corte 9–8, migración no destructiva, respaldo cifrado, restauración selectiva y exportaciones.

Todos los tests y capturas usan fixtures ficticios y simuladores creados para esta tarea. No se abrió ni modificó una fuente clínica real. No hubo push, merge, IPA ni instalación física.

## Resultados finales

| Comprobación | Estado | Evidencia |
|---|---|---|
| Compilación Xcode build-for-testing | PASS | Compilación sobre el último código |
| XCTest nativo | PASS | 21/21, 0 fallos, 0 omitidos; 58 capturas nativas |
| Suite JavaScript | PASS | 50 scripts, exit 0, repetidos tras el último cambio |
| Controles adicionales nativos/JS | PASS | 8 controles, incluido SHA256 de retrato/avatar exactos |
| Suite Swift completa | PASS | 412/412, 0 fallos; ejecución íntegra después del último cambio de código y pruebas |
| XCTest de interfaz | PASS | 10/10, 0 fallos, 0 omitidos; incluye R=1/R=0, teclado, borradores, relanzamiento y fuente protegida ficticia |
| Auditoría de datos reales | PASS | Solo simuladores aislados y fixtures |
| VoiceOver manual / dispositivos físicos | NOT RUN | No se afirma comprobación manual ni instalación física |

La aceptación definitiva corresponde a `668f02b2f447bbf82401e2c9a78b982df380f61b`. Registros persistentes: `/Users/felipeazcarate/Downloads/DANPER-N2-Paridad/work/glass-clinical-pro-acceptance-668f02b`. Todas las suites terminaron con código de salida 0.

## Capturas y alcance de la evidencia

[Índice de capturas y comparación antes/después](</Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/glass-clinical-pro-20261027/CAPTURAS.md>).

La entrega reúne 159 capturas: 46 de la base, 58 de diseño nativo final, 51 de interacción y cuatro comprobaciones manuales de modos del sistema. Las 46 de la base y las 58 de diseño nativo fueron generadas por XCTest en iPhone 16 Simulator. Las variantes pequeñas se alojan en ventanas de 375 × 667 pt con Dynamic Type de accesibilidad sobre el simulador; no se presentan como ejecución de un iPhone SE físico. Las capturas de interfaz incluyen la aplicación completa y sus controles reales durante los diez casos aprobados.

La base no tenía los tres filtros ni las cuatro indicaciones nuevas: no existen equivalentes anteriores de esos controles. La primera automatización de interfaz anterior se interrumpió por SimRenderServer/VideoToolbox; se conservan sus logs, sin presentar una captura inexistente de Ver todas desplazado antes del cambio. La configuración inicial de herramientas sí está documentada y Ajustes tiene captura nativa anterior.

## Incidencias resueltas durante la validación

- Cierre de servicios del simulador por un error de lectura de VideoToolbox: servicio reiniciado y simulador nuevo; ejecución posterior recuperada.
- Un test que exige una DEMO inicialmente vacía falló al reutilizar la fixture ya poblada: la aceptación se repitió desde un simulador ficticio limpio y pasó 21/21.
- Revisión visual: logo recortado, icono de venda genérico, placeholder poco legible y título negro en modo claro; corregidos y recapturados.
- Se corrigió la barra del sistema al solicitar esquema oscuro desde la raíz: la captura real con preferencia clara ya muestra hora e indicadores blancos. La opción de apariencia se conserva en las hojas nativas de compartir.
- El recorrido v2 esperaba cantidad acompañada de unidad en accesibilidad. Se restauró esa lectura manteniendo la unidad debajo del número en la fila visual.
- Swift se repitió íntegramente después del último ajuste de automatización; la corrida final aprobó 412/412 sin fallos.
- Se corrigieron los gestos de automatización: desplazamientos acotados por el margen vacío evitan saltar el buscador o abrir por error el control de fecha. El recorrido específico R=1/R=0 y relanzamiento ya pasó con esta versión del test, sin relajar las comprobaciones de saldos ni pulsabilidad.

## Commits locales por etapas

| Commit | Cambio |
|---|---|
| `0ef1134` | docs(ui): audit Glass Clinical scope and preserve Kardex v2 routes |
| `6825a28` | feat(ui): apply dark clinical glass and exact access portrait across native shell |
| `b84e79b` | feat(kardex): add verified category filters and visible stock expiry glass rows |
| `1dd460e` | style(ui): refine Clinical Pro forms glass contrast and access framing |
| `bf3b630` | test(ui): cover Glass navigation catalog filters expiry and native layouts |
| `67bdde2` | fix(ui): improve glass search expiry field and light-mode navigation contrast |
| `17d9de2` | fix(a11y): include original unit in spoken consolidated stock balance |
| `f0f61f0` | test(ui): stabilize bounded scrolling through inline medication fields |
| `8c54985` | test(ui): drag form gutter without activating date and menu controls |
| `13de81e` | fix(ui): keep system status indicators readable over dark glass |
| `7585049` | fix(ui): request consistent dark glass chrome and retain share appearance preference |
| `48b222e` | test(ui): protect readable dark chrome and sharing appearance preference |
| `668f02b` | test(ui): settle keyboard responder before switching clinical input fields |

## Entorno y alcance de accesibilidad

Xcode 16.2 (16C5032a), Swift 6.0.3, SDK iOS Simulator 18.2 y runtime iOS 18.3.1 (22D8075), iPhone 16 x86_64. Se capturaron acceso e Inicio con los modos claro y oscuro reales de iOS; la superficie clínica conserva Glass oscuro. Las ventanas pequeñas y Dynamic Type están documentadas en las capturas nativas.

VoiceOver y los ajustes de Reducir transparencia / Reducir movimiento no se comprobaron manualmente; sus etiquetas, selección, tamaños y ramas de fallback se revisaron en el código. No se afirma validación física ni de hardware biométrico real.

## Evidencia reproducible

[Resúmenes estructurados y registros](</Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/glass-clinical-pro-20261027/evidencia/RESULTADOS.json>). [Manifiesto SHA256 de capturas](</Users/felipeazcarate/Documents/Codex/2026-10-24/files-pasted-by-the-user-misi/outputs/glass-clinical-pro-20261027/evidencia/CAPTURAS_SHA256.json>).

Para repetir la aceptación, utiliza un simulador nuevo con datos ficticios: la preparación nativa exige una fuente DEMO inicialmente vacía. Los comandos registrados contienen el UDID de este entorno aislado.

Las pruebas heredadas de compatibilidad FEFO permanecen en el repositorio; la interfaz operativa v2 continúa usando solo existencias consolidadas y declaración manual R. No se añadieron rutas FEFO.

El recorrido final verificó 70 → 68 UND y 12 → 11 FCO con R=1; R=0 conservó 11 FCO, también después del relanzamiento. Las historias clínicas de estos escenarios son ficticias.
