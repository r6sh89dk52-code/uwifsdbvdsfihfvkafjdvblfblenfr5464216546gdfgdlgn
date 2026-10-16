# DANPER — paridad build 222 → SwiftUI N2 (SIN IPA)

## Alcance alcanzado
- Motor en memoria `N2NativeClinicalTransaction`: preserva las nueve colecciones originales, confirma la atención como una operación lógica, calcula FEFO por lotes, genera movimiento con vínculo de atención y evita duplicar entregas confirmadas.
- Solo asociaciones oficiales de las 86 equivalencias aprobadas; E-62 y E-63 continúan distintas. Las no autorizadas mantienen R desconocida.
- UNIDADES emitidas por cantidad clínica. CJA/FCO/PAQ exigen cantidad física específica, lote verificado y autorización de apertura nueva. Reutilización registra R=0, apertura R=1 por envase; guardado atómico en memoria antes de cualquier persistencia.
- Antes y después se valida íntegramente el snapshot mediante las puertas N1e y N1f. No se infieren consumos históricos ni cero para saldos desconocidos.

## Puertas aún abiertas antes de paridad **real**
- Enlazar el nuevo motor a formulario editable real: búsqueda y alta de trabajadores reales, alergias, diagnóstico, procedimientos, borradores con corrección auditada y fotos SI/NO, conservando la estructura de CONSUMOS A–AD.
- Persistir las nueve colecciones mediante generación cifrada y recuperación tras fallo de energía; activación segura de UNA fuente histórica original, sin mezclar registros demostrativos.
- Integrar exportadores de Excel desde la misma generación de datos clínicos consolidada: cierre 9–8, Kardex diario/rango, CONTEO, ingresos, RESU M manual, tablas, impresión y fórmulas.
- Pruebas cruzadas reales de archivo con Microsoft Excel, protección local Face ID, segundo respaldo cifrado/restauración, condiciones de recuperación, instalación iPhone y comportamiento de SideStore.

**No declarar que SwiftUI ha alcanzado build 222 solo porque sus tests de laboratorio pasen. No generar IPA, no fusionar main, no importar información real todavía.**
