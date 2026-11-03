# Cierre de Build15 —8ca4b40, validación pendiente

HEAD recibido al continuar:5e570b449c56a8716e405aba51baeb093d8043a8.
Commit publicado:8ca4b400c3d12eb43953ed148c5c3241e0fc7b23.
PR10 sigue borrador, sin fusionar. Main y Build14 no se modifican.

Se conserva toda optimización de producción validada. El nuevo commit ajusta
solo consultas redundantes de XCTest en N3ClinicalJourneyTests y documenta los
resultados reales del predecesor. No cambia App/Core, autenticación, datos,
esquema, stock, claves, ubicación de bóveda ni BundleID. No elimina casos,
assertions de resultado ni incrementa los600s. La geometría cacheada se
invalida por lanzamiento; el frame del control y su hittability son actuales.

El workflow41684106094 corresponde exactamente a8ca y sigue EN CURSO en
este checkpoint. No se certifica usando5e ni se habilita la IPA.

## Resultado cerrado5e

Workflow41664865130: FAILURE.439Swift/30nativas/62JS/37Python PASS,
Excel oficiales,9presupuestos y prueba de compatibilidad14 PASS.
UI:12PASS/1FAIL/0SKIP y1caso NO EJECUTADO. Se conservan los JSON originales
en evidence-5e570b4, ver CLOSED_GATE.json; no confundir preflight y recorrido.

El caso R1/R0 excedió600s. Sus dos guardados se observaron, pero faltó terminar
stock/relanzamiento/historial; no se declara aprobado. El log registra también
un bloqueo de notificación de animación de60s de XCTest. El nuevo helper
elimina la consulta duplicada de hittability, los app.frame repetidos por tap,
la espera tras existencia ya confirmada y lecturas repetidas de identifier.
La mejora de tiempo aún NO está comprobada; requiere completar el nuevo caso.

El job protegido falló antes de su recorrido: la consulta al texto del permiso
Face ID en SpringBoard agotó los snapshots AX. No se envió evento biométrico
en ese preflight. La prueba dedicada de Face ID aprobó2/2, incluyendo cancelar,
reintentar y nueva autenticación tras volver del segundo plano. La prueba UI
de alergias aprobó2/2. Se conserva el permiso y el flujo real completos para
la ejecución nueva en otro simulador aislado; no se modifica ni simula éxito.

## Rendimiento conservado, fuente explícita

Mismo host Linux Release, C274→5e,9648trabajadores ficticios/1005atenciones.
Son operaciones de Core, no mediciones del botón/iPhone. Ver v2-comparison.

|Acción|Antes p50 ms|Después p50 ms|n|
|---|---:|---:|---:|
|Guardar alergias|4262.038|2846.875|7|
|Guardar borrador|7448.555|2921.701|7|
|Contexto dispensación|3707.116|304.944|3|
|Excel enfermería98|7797.431|6351.137|3|
|Respaldo verificado|15758.589|12843.756|3|

CPU231.25→159.19s, RSS223392→223052KiB sin cambio relevante de memoria.
Formulario/historial/panel/editor/catálogo/búsqueda no muestran ganancias
relevantes en esta comparación. No p95 para3/7muestras. Core v1 cc45→5e:
Excel10hojas11032.479→831.534ms,n3. No mezclar líneas base ni hosts.
Build14 comparable: No medido. iPhone físico: No medido.8ca: pendiente.

La compatibilidad14 comprobada en5e usa el productor real9b1da6d con datos
ficticios: lee backup y journal, persiste rectificación, crea/restaura respaldo
nuevo y preserva trabajadores/atenciones/stock. No certifica el contenedor del
iPhone ni la firma de iLoader; se exige repetirla en el HEAD final.

## Distribución bloqueada

Preparación de guardia actualizada a8ca/run41684106094, Release UNBOUND,
sin workflow ejecutable de empaquetado.10pruebas negativas locales PASS con
metadatos ficticios, no pruebas de la app ni IPA generada. Solo habilitar tras
439Swift/30nativas/14UI/62JS/37Python y todas las comprobaciones de ese HEAD.
La compilación ARM64 y empaquetado usarán la rama de distribución existente.

BundleID requerido:pe.danper.saludmovil.native.iloaderpreview, versión0.4.2,
build15. Para actualización aprobada: respaldo cifrado14 verificado y clave,
mismoAppleID/equipo de firma/BundleID, instalar encima sin desinstalar ni
reimportar historial. Detenerse ante app nueva o datos vacíos. No hay IPA
aprobada ni instrucciones para sustituir aún la instalación estable.
