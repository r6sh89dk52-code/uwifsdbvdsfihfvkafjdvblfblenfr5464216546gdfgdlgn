# Cierre UI y número real de casos

Al integrar el caso de permiso, los verificadores exigían14UI pero el último heredoc de validate-macos.sh seguía comparando la suma con13. Esto rechaza14casos válidos y acepta un inventario incompleto de13. Fue un error en la integración del harness; no se atribuye a la app ni al simulador.

Cuatro regresiones ejecutan el descubrimiento real de clases y el cierre real del script, sin Xcode: inventario actual completo aceptado; inventario antiguo de13 rechazado; suite duplicada con igual total rechazada; clase seleccionada incorrecta rechazada. Antes del arreglo, fallaban las dos primeras:14se rechazaba y13se aceptaba. Después aprobaron las37pruebas Python (33anteriores+4nuevas), sin fallos.

El cierre ahora llama al mismo verificador de evidencia UI y contrasta cada suite, cantidad, clase y selectores con las fuentes actuales. No basta con sumar números. La comprobación estructural no constituye evidencia de ejecución: cada shard debe seguir aportar su XCTest real, semillas/preflights exigidos, cero fallos/omisiones y marcadores del SHA correcto.

La corrección se prepara en una rama auxiliar desde59e6773, sin cambiar App/Sources/NativeTests/InteractionTests/project.yml ni interrumpir las pruebas ya iniciadas de59e6773. La ejecución de regresiones auxiliar no aprueba la aplicación. El HEAD final deberá ejecutar sus comprobaciones obligatorias antes de generar una IPA; los resultados59e6773 se conservarán con su SHA real.
