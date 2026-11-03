# Build15 — cierre e58efd2, sin aprobación anticipada

HEAD inicial de esta continuación:8ca4b400c3d12eb43953ed148c5c3241e0fc7b23.
HEAD de aplicación:e58efd2a398b12ee196568295cb145821ed4639d.
Commit e58: solo pruebas XCTest y documentación; App/Core no cambian.
PR10 borrador, sin fusionar. Main y Build14 estables se conservan.

El run obligatorio41707072055 está EN CURSO en este checkpoint. La nueva
corrección conserva todas las assertions y el límite600s: consulta el permiso
DANPER real también durante la segunda ventana original15s (sin reiniciarla),
y reduce desplazamientos/lecturas repetidas del recorrido R. Ningún éxito
biométrico simulado por código, TCC grant por comando o cambio de seguridad.
Estos ajustes siguen pendientes de validación en el recorrido completo.

## Fallo cerrado del predecesor8ca, preservado

Run41684106094: FAILURE. Swift439/0/0, nativas30/0/0, JS62/0, Python37/0,
ambos Excel,9presupuestos, compatibilidad ficticia original14 e Instruments
idle PASS. UI11PASS/2FAIL/0SKIP y1recorrido protegido NO EJECUTADO.
Los siete resúmenes UI originales y las demás evidencias JSON están en
[evidence-8ca4b40](evidence-8ca4b40/CLOSED_GATE.json); incluye hashes de archivos.

R1/R0 guardó ambas atenciones y comprobó balances, pero las últimas
comprobaciones quedaron después de600s: FAIL, no aprobación. El helper
anterior fue insuficiente. Shell falló al sintetizar el tap Ajustes (30s);
no hay causa de código de producción demostrada y el caso sigue obligatorio.
El preflight protegido buscó el permiso15s, no lo encontró y dejó de buscarlo.
Captura35.77s: sin alerta; captura posterior: permiso Face ID real todavía
abierto y app Verificando identidad debajo. El nuevo código sigue buscando
ese permiso durante la segunda ventana ya existente. FaceID dedicado2/2 y
alergias UI2/2 PASS en8ca; no certifican e58.

## Rendimiento conservado, sin inventar línea base14

Core v2, mismo host Linux Release, C274→8ca,9648trabajadores ficticios y1005
atenciones iniciales. No son tiempos de botón ni de iPhone físico.

|Acción|Antes p50 ms|Después p50 ms|Reducción|n|
|---|---:|---:|---:|---:|
|Guardar alergias|5761.292|3752.952|34.86%|7|
|Borrador|10020.361|3811.849|61.96%|7|
|Contexto dispensación|4926.310|367.557|92.54%|3|
|Excel enfermería98|10440.939|8127.179|22.16%|3|
|Respaldo verificado|20818.001|16952.039|18.57%|3|

CPU308.48→208.66s. RSS223172→224428KiB sube ligeramente; no se declara mejora
de memoria. Búsqueda último trabajador p95=0.227365ms/común9.435524ms,n100:
rendimiento conservado, sin ganancia relevante en v2. Core v1 cc45→8ca:
indicador10hojas7066.399→511.073ms,n3. No mezclar variantes/hosts. Sin p95
para n3/7. Build14 comparable: No medido. e58: pendiente. iPhone: No medido.

Se mantienen las optimizaciones de bóveda cifrada y prueba de revisión,
guardado de alergias confirmado, concurrencia/autosave, búsquedas9648 y
paginación, consultas de inventario, rectificación por atención y exportación.
No se integra el experimento de menús ni arranque DEMO sin validación completa.

Compatibilidad8ca:1PASS/0FAIL, archivos producidos por código original14
9b1da6d; lectura de journal/backup, rectificación persistida, respaldo nuevo
restaurable, stock y trabajadores/visitas originales preservados. e58 debe
repetirlo. No se ha accedido a datos reales ni certificado contenedor físico.

## Distribución condicional real, todavía sin IPA

Rama existente:audit/b15-profile-device-9143997-20261101.
Commits570c3a5 y2cf841b. Primer run41707802926: FAILURE de configuración,
antes de ejecutar la compilación; preservado. Se corrigió el contexto runner
en env de job y la invocación Python. Run41708026547: EN CURSO,17pruebas de
protección PASS; espera los gates reales. No equivale a aprobar la app.

Solo después de SUCCESS completo de41707072055 y evidencia exacta e58,
compilará ReleaseARM64. El empaquetado vuelve a comprobar jobs/SHA/PR,
identidad, recursos y hashes. Si una prueba falla, el PR cambia o se agota
la espera de distribución, NO genera IPA. No aumenta límites de las pruebas.
Artifact previsto, aún INEXISTENTE:DANPER_BUILD15_ILOADER_UNSIGNED_e58efd2.

BundleID requerido:pe.danper.saludmovil.native.iloaderpreview; versión0.4.2,
build15; misma ubicación/claves/formato de bóveda. Para versión aprobada:
respaldo cifrado14 reciente verificado y contraseña, mismoAppleID/equipo de
firma/BundleID, actualizar encima. No desinstalar/resetear/reimportar visitas.
Detenerse ante una instalación nueva o datos vacíos. Verificar trabajadores,
atenciones, alergias, borradores y balances compartidos. Contenedor físico y
downgrade no certificados por Simulator. No instalar una versión pendiente.
