# DANPER Salud Móvil v0.15.1 — corrección de cantidades en CONSUMOS

## Causa
La demostración v0.15 utilizaba paracetamol `16000182` con unidad oficial `UND` configurado como `frasco` de 100, lo que producía R=1 y R=0 para dos atenciones ficticias del mismo trabajador. La frecuencia no causaba el cero; el modo de envase incorrecto sí.

## Correcciones
- Entregas vinculadas a artículos de **unidades individuales** `UND`/`TBL` o `PAR`: la cantidad Excel R representa la **cantidad física dispensada** para cada atención, sin que la frecuencia influya. Se verifica que coincida con la cantidad clínica confirmada y la unidad física, aunque el lote se haya almacenado dentro de caja.
- Artículos por apertura de envase: mantienen R=1 si se abre un contenedor nuevo, R=0 si se sigue utilizando el abierto; la cantidad física consumida se conserva independientemente.
- Las entregas de unidades individuales con un lote contabilizado como frasco/caja (unidad física de envase incompatible) se rechazan hasta conciliar unidades; no se inventan conversiones.
- Se actualizan las pruebas de paracetamol (primera R=1, segunda R=2), caja de agujas `16000013` (R=1/0) y registro de frascos con unidad `FCO`.
- El libro de diez hojas conserva 432 códigos numéricos, datos ficticios y las protecciones de privacidad de v0.15.

## Precaución
- **No se migran ni modifican automáticamente lotes, movimientos ni atenciones anteriores.** Los registros de demostración con clasificación inválida requieren corrección consciente y trazable.
- Las cantidades y combinaciones de unidad/presentación deben verificarse antes de entrega; esta versión continúa siendo un prototipo para datos ficticios.
- Si una prueba de aceptación o CI falla, no fusionar en main. Microsoft Excel y SideStore deben comprobarse realmente antes de declarar validación final.
