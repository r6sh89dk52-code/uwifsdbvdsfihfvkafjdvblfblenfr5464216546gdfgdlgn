# Build15 — resultado cerrado e58efd2, IPA bloqueada

Aplicación/HEAD primario:e58efd2a398b12ee196568295cb145821ed4639d. PR10 borrador, sin fusionar. Main y Build14 se conservan.
Run41707072055: FAILURE. Los resultados de este documento corresponden a e58; no se sustituyen por los de otro SHA.

## Aprobaciones verificadas

Swift439PASS/0FAIL/0SKIP; Xcode real y nativas30PASS/0FAIL/0SKIP; JavaScript62PASS; Python37PASS.
Ambos Excel oficiales PASS: indicador10hojas/432materiales y enfermería98productos, estructura/fechas/cálculos.
Core v1/v2 y9presupuestos PASS; compatibilidad cifrada con archivos producidos por código original14 PASS; Instruments idle PASS.
UI Inicio/Ajustes1, alergias2, formularios clínicos3, presentación2 y recorrido R1/R0+relanzamiento2:10casos PASS.
El caso R1/R0 completó todos los guardados, comprobaciones físicas, historial y relanzamiento sin ampliar600s. El cambio previo insuficiente permanece documentado; los últimos helpers se conservan.

## Bloqueos reales, sin falsificar aprobaciones

- Biometría:1PASS/1FAIL. La preparación de permiso y el caso de permiso sin acceso aprobaron. El caso automático falló antes del primer nomatch/match: solicitud real20:42:22.651, coreauthd devolvió -1000 UI activation timed out after5seconds20:42:28.119; CoreAuthUI apareció20:42:47.848. La app permaneció bloqueada y mostró Reintentar Face ID. No se considera autenticación exitosa.
- Menú: diagnóstico de runner1FAIL; la prueba real de menú NO SE INICIALIZÓ por Timed out while loading Accessibility. Se conserva el fallo de infraestructura, sin adjudicarlo a lógica del menú.
- Fuente clínica protegida:0PASS/1FAIL. Dos matches reales del simulador confirmados; la bóveda ficticia quedó creada/verificada con1trabajador y0atenciones, inventario sin activar. Tras el tap Volver no apareció Inicio dentro de15s. Causa pendiente de validación; no se etiqueta automáticamente como fallo del entorno.
- Complete: SKIPPED porque hay fallos. No es una aprobación del HEAD.

Los resúmenes XCTest de los ocho shards informan11PASS/3FAIL/0SKIP; una de esas3fallas es el diagnóstico previo a inicializar el runner de menú, por lo que su caso real quedó sin ejecutar. No confundir un fallo de arranque con una prueba funcional ejecutada.
Artifacts fallidos: biometry result13268959393/raw13270605150; menu result13269493377/raw13269068673; protected result13271376761/raw13270822512. DEMO/R result13271077890/raw13270768383 PASS.

## Rendimiento conservado, datos ficticios

Mismo host dentro de cada comparación Linux Release,9648trabajadores y1005atenciones iniciales. Core v2 C274→e58; no es latencia del botón ni del iPhone.

|Acción|Antes p50 ms|Después p50 ms|Reducción|n|
|---|---:|---:|---:|---:|
|Alergias cifradas confirmadas|5793.351|3690.646|36.30%|7|
|Borrador cifrado confirmado|10281.174|3812.687|62.92%|7|
|Contexto dispensación|5046.060|381.626|92.44%|3|
|Excel enfermería98|10737.118|8342.346|22.30%|3|
|Respaldo cifrado verificado|20780.281|16753.360|19.38%|3|

CPU312.89→207.88s; RSS223964→223100KiB, diferencia pequeña sin mejora relevante demostrada de memoria.
Búsqueda último trabajador p95=0.225316ms/común10.262642ms,n100: rendimiento conservado.
Core v1 cc45→e58: Excel10hojas11039.688→830.292ms,n3. No mezclar variantes/hosts; no p95 para3/7muestras.
Build14 como línea base de rendimiento comparable: No medido. iPhone físico: No medido. Los ajustes de XCTest no se presentan como una mejora adicional del runtime de la app.
Se conservan bóveda/revisiones, confirmación real de alergias, concurrencia/autosave, índices9648/paginación, inventario, rectificación histórica y exportaciones. No se integran los experimentos de menú/arranque DEMO.

## Compatibilidad y datos

Prueba1PASS/0FAIL en e58 con productor original14:9b1da6d4cdead4729bcade6843abcbcfc287e870.
Backup y journal originales legibles; rectificación persistida; respaldo nuevo restaurable; stock, trabajadores y visitas originales preservados. Solo datos ficticios; sin acceso al iPhone ni validación del contenedor físico.
Artifact Swift13266326697, JS13266935807, nativas13266998692, v2/presupuestos13267311984, v1/compat13268083297.

## Distribución y reparación dirigida

Run41708026547 FAILURE: su guardia rechazó el gate fallido. ARM64 y package SKIPPED. No IPA generada.
Primer intento de configuración41707802926 también queda registrado FAILURE. No se oculta ni se cuenta como prueba de la app.

Rama existente audit/b15-profile-device-9143997-20261101, commit b16a212a20ccc42026a2c06fc2639cf4e650f401:
el observador host deja de consultar simctl cada2s durante la activación y consulta únicamente después de una señal real del sensor, una vez por generación. Timeout del sondeo30→5s; esperas de autenticación/600s sin cambios. El host nunca inyecta match/nomatch.
11pruebas de protocolo PASS, incluyendo5nuevas carreras; no aprueban la app.
Run41718693853 EN CURSO: repite Biometric2/Menu1/protegida1 con los productos nativos/UI exactos y sellados de e58, sin recompilar/modificar App/Core/XCTest. Guarda diferencia de host, SHA del auxiliar y manifiesto de productos. Hipótesis de interferencia del sondeo todavía pendiente de validación real.

Esta recuperación aislada NO permite empaquetar ni sustituye el gate obligatorio completo. Conservar la guardia estricta: solo un HEAD primario definitivo con todas las comprobaciones completas aprobadas puede generar IPA. No relajar el guard para mezclar o esconder fallos. Si se integra la reparación, volver a ejecutar el gate completo para el nuevo HEAD y volver a vincular distribución a ese SHA/run.

Mantener Build14 instalada. Para una futura IPA aprobada se verificará mismo BundleID pe.danper.saludmovil.native.iloaderpreview, versión0.4.2/build15, misma bóveda/claves. La firma de iLoader debe conservar también equipo/prefijo AppID; un BundleID igual no prueba por sí solo acceso al Keychain tras firmar.
No desinstalar, resetear inventario ni reimportar atenciones al actualizar. Conservar respaldo cifrado reciente y contraseña. Todavía no existe una IPA aprobada para instalar.
