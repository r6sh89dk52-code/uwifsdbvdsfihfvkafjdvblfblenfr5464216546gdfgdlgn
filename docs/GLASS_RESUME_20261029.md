# DANPER Glass Pro — cierre de validación y entrega

Estado: **SUCCESS**. Ejecución final [40861610616](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40861610616).
Código construido y validado: `2b76453cd51b2998ac300d9c6d435ec871b56cc1`.
Rama exclusiva: `audit/glass-pro-iloader-20261028`.

## IPA publicado

- Archivo: `DANPER_GLASS_PRO_0.4.2_12_ILOADER_UNSIGNED.ipa`.
- Versión 0.4.2, compilación 12.
- Bundle `pe.danper.saludmovil.native.iloaderpreview`.
- Plataforma iPhoneOS, arquitectura única ARM64, sin firma ni perfil provisionado.
- [Artefacto IPA y manifiestos · 12896935229](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40861610616/artifacts/12896935229).
- SHA-256 del **IPA interno**, no del ZIP contenedor de Actions:

```text
8bc9810b0d26dd7d9498e06c4935de2724866f22c16649325f4ecb9e7fecba3d
```

Incluye `SHA256SUMS.txt`, manifiesto del IPA, `APP_SHA256.json`,
`VALIDATION_MANIFEST.json`, `DIAGNOSTIC_GATE.json`, `SCOPED_REUSE.json`
y límites de validación. El empaquetador comprobó versión/bundle/plataforma,
ARM64, ausencia de firma/perfil, integridad ZIP, hashes de todos los archivos
del Payload y procedencia del código antes de publicar. No se modificaron
main, la rama original SwiftUI, modelos/pruebas nativas, src, datos clínicos
ni lógica Kardex v2.

## Controles obligatorios aprobados

| Control | Resultado | Procedencia |
|---|---:|---|
| Swift | 412 PASS, 0 fallos | Ejecución nueva ARM64; 242.286 segundos |
| Nativas | 23 PASS, 0 fallos/omitidas | Ejecución nueva ARM64 |
| JavaScript | 62 PASS | 61 reutilizados por identidad de entradas y runtime; identidad del SHA actual ejecutada de nuevo |
| Libros Excel | 2 controles PASS | Archivos nativos producidos por Swift actual |
| UI completas | 11 PASS, 0 fallos/omitidas | Ejecución completa nueva en el código corregido |
| Cierre de controles | PASS | Todos los marcadores y resúmenes corresponden al SHA construido |
| IPA ARM64 sin firmar | PASS | Build Release nuevo; integridad y manifiestos comprobados |

Runtime UI: Xcode 16.4 (16F6), iOS Simulator 18.5 (22F77), ARM64.
La caché de binarios se rechazó por una diferencia de bytes en un ZIP generado;
se reconstruyó realmente. No se reutilizó ningún veredicto de las 11 UI finales.
El cambio de arquitectura y el host App invalidaron los resultados Intel de
Swift/nativas, por lo que se repitieron ambas suites.

Los 61 resultados JS proceden del run `40857793155`, core `12891281001`,
source `cb49f7048a8f3bd4a358e4af7c77f1d625432ef4`. Ese run falló en el
orden de preparación XLSX; no se relabeló como exitoso. Se verificó la igualdad
de todos los blobs/modos/rutas de entradas fuera de los cambios de pipeline
revisados y Node v22.23.2/darwin/arm64. El control de identidad volvió a ejecutarse
y los dos controles de libros siempre consumieron archivos Swift nuevos.

### Inventario UI final

| Resultado | Casos PASS |
|---|---:|
| N2BiometricInteractionTests | 1 |
| N2Build222ShellTests | 1 |
| N2GlassClinicalTests | 3 |
| N2MenuInteractionTests | 1 |
| N2PremiumRedesignTests | 2 |
| N3ClinicalJourneyTests — DEMO | 2 |
| N3ClinicalJourneyTests — fuente protegida | 1 |
| Total | 11 |

## Evidencias conservadas

- [UI completas, xcresult, capturas y logs · 12896810525](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40861610616/artifacts/12896810525).
- [Core, resultados y prueba de reutilización · 12893306113](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40861610616/artifacts/12893306113).
- [Prueba de entrada de los tres diagnósticos · 12890594882](https://github.com/r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn/actions/runs/40861610616/artifacts/12890594882).
- Diagnóstico previo de los tres métodos originales: run `40835749202`,
  source `2bb98bf9bf52f35f9711350d40ce00d2db097060`, SUCCESS 3/3,
  compact `12881741798`, raw Bio `12880573559`, Premium `12881775105`,
  Protected `12881731821`.

La recuperación inicial `40806554927` y sus cuatro artefactos permanecen
preservados; no se repitió esa recuperación ni la auditoría completa.
Historial detallado: `docs/GLASS_TARGETED_DIAGNOSTIC_20261028.md` y versiones
anteriores de este archivo en Git. Los artefactos de Actions tienen retención
configurada de 14 días.

## Correcciones y límites de las conclusiones

La instrumentación prueba que los eventos biométricos se envían después de un
sensor real activo y de un contexto nuevo; atiende únicamente el consentimiento
Face ID real cuando aparece tarde. No concede éxito ni permisos de aplicación
desde el host. La corrección de producción se limita al cierre explícito del
LAContext completado y su limpieza de ciclo de vida, conservando política,
authCycle, cancelación, reintento, reautenticación y cobertura de privacidad.
No se forzó ningún toque ni se relajaron aserciones. Las trazas aprobadas no
demuestran una duración concreta de retención ni aíslan por sí solas el mecanismo
exacto de la carrera de CoreAuthUI.

La aserción inmediata original de Premium sobre teclado/barra de pasos se
conservó y aprobó repetidamente. El fallo original dejó de reproducirse; su
causa exacta no quedó demostrada y no se atribuye una corrección de teclado
que no se realizó.

El primer intento final falló antes de Swift/nativas/UI por consumir el XLSX
antes de su productor Swift. Se corrigió el orden y se reanudó con prueba de
reutilización; no hubo repetición de una validación completa de 11 UI aprobada.
El experimento de instancias separadas de Simulator se descartó y retiró;
tampoco se lanza/termina CoreAuthUI manualmente.

Este es un candidato unsigned con controles automatizados aprobados. No se
validaron instalación/firma iLoader, iPhone físico, VoiceOver manual, Reducir
transparencia/movimiento manuales ni migración clínica real. Solo se usaron
datos sintéticos. No afirmar esas validaciones adicionales.

## Reanudación

No queda pendiente repetir las suites descritas ni generar el IPA. Antes de
cualquier cambio futuro, verificar este source SHA, sus manifiestos y los
artefactos. Reutilizar resultados únicamente con entradas y runtime demostrados
idénticos; repetir solo las suites que un cambio invalide. No activar la
auditoría completa automática ni modificar main o la rama SwiftUI original.
