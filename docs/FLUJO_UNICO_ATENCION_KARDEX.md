# Flujo único de atención → consumo → Kardex (propuesta v0.21.10+)

## Requisito de producto confirmado por el operador
No se debe obligar al usuario a entrar en Kardex > Entrega para confirmar de nuevo los medicamentos/insumos que registró como utilizados en una atención. Guardar/finalizar una atención es la confirmación del consumo clínico. La salida física puede quedar sin conciliar por falta de información, pero la atención se conserva.

## Comportamiento actual del PR #57
1. Durante la atención se registra cada producto oficial, su unidad y cantidad clínica, y el procedimiento.
2. Al pulsar **Guardar**, se valida la atención. En una única escritura cifrada, se guarda atención + cualquier descuento físico verificable + movimientos del Kardex.
3. Para UND/TBL/PAR con una única asociación aprobada, cantidad física idéntica a cantidad clínica, existencia real compatible y FEFO inequívoco, se descuenta automáticamente una sola vez mediante clave `ATT:<id>:ITEM:<id>`.
4. Si no hay stock, está agotado, falta equivalencia aprobada, hay presentaciones ambiguas o la salida requiere una cantidad física interna no capturada, **se registra el uso clínico pero NO se genera movimiento físico ficticio**. Queda pendiente por identidad de atención/item, no por saldo negativo.
5. El historial muestra cuál es el estado de cada atención. El Indicador oficial sigue exigiendo un movimiento verificable; PR #56 ofrece un Excel PROVISIONAL donde R queda vacía para productos aún no conciliados y nunca inventa saldos, lotes o un 0.
6. Actualizar una atención que ya tenga productos descontados no permite modificar/eliminar esos productos sin corrección auditada.
7. Para revisar registros antiguos/ambiguos existe una herramienta de **conciliación histórica opcional** en el Kardex; no participa del guardado rutinario.

## Importante: qué NO se debe inferir
- Una cantidad clínica «1 CJA» o «1 FCO» no prueba cuántas agujas o mL se consumieron ni el instante en que se abrió el envase. La lógica 1/0 para R requiere información física interna.
- Dos productos Kardex diferentes que comparten un código del Indicador (E-62/E-63) no son intercambiables.
- Un lote registrado hoy no demuestra cuánto stock existía al principio del mes o en una atención anterior.
- No debe ejecutarse una migración retroactiva de los consumos antiguos del iPhone hacia saldos actuales sin recuento y validación por el operador.

## Próxima ampliación necesaria antes de promover el cambio
Añadir en el **mismo formulario de atención** (nunca en un módulo posterior) la cantidad física usada o presentación precisa solo para FCO, CJA, PAQ, correspondencias múltiples o envases no inequívocos, y calcular correctamente apertura R=1/0 con casos de frascos abiertos, cajas abiertas, agotamiento, FEFO y varios lotes. Las cantidades por defecto deben configurarse por producto con evidencia y permitir revisión. No adivinar mL/volumen.

## Gates de validación
- Tests Linux de cálculo, claves idempotentes, doble guardado, guardado fallido, FEFO, stock agotado, alteraciones posteriores, lotes vencidos, varias sedes y exportación provisional/oficial.
- Reconstrucción exacta del Indicador (10 hojas, R conforme) y Kardex (98 productos) usando datos sintéticos sin PII.
- Respaldo portátil restaurable y prueba en instalación vacía.
- Solo tras aprobaciones, crear UNA IPA para validar físicamente. No cambiar Bundle ID ni borrar la app instalada.
