# DANPER N1s — cierre integral de exportación en un solo PR

## Alcance de implementación
La rama N1s combina **el Indicador Ambulatorio** de DIEZ hojas (BD MATERIALES, CONTEO, INGRESOS, RESU, CONSUMOS, JUSTIFICACIONES, GUIA, @subuo, BASE TRU, @uo) con el **Kardex de enfermeras** (98 productos, conservando plantillas, presentaciones, fórmulas y configuraciones de impresión).

La fuente de verdad del contraste es el código TypeScript existente en `src/ambulatoryRows.ts`, `src/ambulatoryReconciliation.ts`, `src/ambulatoryExcel.ts`, `src/dailyKardex.ts` y `src/kardexExcelTemplate.ts`. El exportador Swift reconstruye los campos del Indicador A–AD, las 432 filas de stock, ingresos y conteo, y las hojas auxiliares no alteradas, así como el formato de Kardex de 98 ítems. Solo se usan XLSX y personas completamente sintéticas dentro de RUNNER_TEMP. **No se suben datos clínicos reales ni archivos exportados a GitHub.**

## Consumo en el acto de atención
- Guardar la atención confirma los medicamentos/insumos utilizados. Para UND/TBL/PAR con equivalencia Kardex aprobada y stock físico suficiente, FEFO automático, una sola escritura de atención y movimientos; no existe una segunda pantalla de "entrega".
- Para FCO/CJA/PAQ, se requiere una **cantidad interna verificada** por uso y presentación. La pantalla puede recordar exclusivamente esa cantidad no identificadora después de que el operador la configure, sin inferir cantidades de historias anteriores.
- Si el plan FEFO requiere abrir una caja/frasco sellado, la interfaz de la atención exige aprobación explícita para esa apertura. Mientras falte autorización el consumo clínico se guarda, pero no hay movimiento de stock inventado.
- La primera apertura deja **R=1 por envase abierto**; los siguientes usos del contenido abierto, **R=0**, aunque el remanente físico disminuye. Un uso multilote que abra dos envases genera R=2 en total para una sola línea clínica.
- **Un frasco de 100 mL no implica 100 atenciones por sí solo:** solo si consta que el consumo interno real es de 1 mL por atención y se respeta FEFO. A 2 mL por atención serán 50 usos. Al agotarse se solicitará aprobar una nueva apertura; sin stock se conserva pendiente, nunca saldo negativo.
- No reconstruir retroactivamente movimientos físicos a partir de registros históricos sin evidencia de stock real. Los productos con asociaciones ambiguas conservan estado pendiente hasta verificar presentación.

## Excel y columnas especiales
- CONSUMOS: cantidad R oficial proviene solamente de movimientos físicos confirmados; provisional queda identificado como tal.
- FRECUENCIA S: cuenta atenciones guardadas por DNI y fecha, no filas de productos; la sexta se marca REVISAR.
- T/U: tipo de atención y detalle por procedimiento real, evitando herencias silenciosas si hay varios procedimientos.
- AA: fotografía SI/NO conforme al formulario; no conserva imágenes clínicas.
- RESU/CONTEO/INGRESOS: los saldos pendientes siguen vacíos y no se convierten a cero; ingresos sujetos a revisión; M de RESU es COMENTARIO manual. Fórmulas y cortes se mantienen separados del Kardex diario.
- Kardex D/E/F/G/H: stock inicial, entradas, total, consumo de envase o unidad correspondiente y saldo final. F/S de conteos significa faltante o sobrante.

## Puerta final de calidad antes de activar el iPhone con datos reales
1. Pasar **Swift/Linux**, **npm build**, pruebas automatizadas de FEFO y comparación externa ZIP/XML de ambos XLSX Swift contra los dos exportadores TS.
2. Verificar por segunda vía las fórmulas, estilos, validaciones, tablas y rangos usados tras expansión a miles de filas; abrir los dos archivos en Microsoft Excel en dispositivo o Mac y confirmar cálculos, impresión y apariencia.
3. Integrar el recurso XLSX saneado y una base clínica nativa transaccional segura. El preview SwiftUI no tiene acceso automático a archivos de pacientes o respaldo real.
4. Probar restauración cifrada en iPhone físico sin pérdida de historia, alergias, consumos, inventario ni correcciones.
5. Solo entonces habilitar exportación clínica y firmar una IPA. No fusionar ni sustituir la **build222** durante estas comprobaciones.

**Escritores Swift actuales: solo laboratorio con datos ficticios; ningún permiso de restauración clínica.**