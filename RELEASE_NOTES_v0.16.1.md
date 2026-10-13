# DANPER Salud Móvil v0.16.1 — Kardex Enfermería sin donados

## Contrato confirmado
- Libro original de Kardex: `KARDEX DE ENFERMERÍA ACTUALIZADO - OCTUBRE-2026.xlsx`.
- **98 productos oficiales** de `KARDEX ENFERMERAS!C7:C104`, sin agregar ni sustituir nombres.
- Los seis productos donados `D-1` a `D-6` dejan de ser operativos y no se exportan.
- El archivo XLSX exportado tiene **una sola hoja `KARDEX ENFERMERAS`**, conservando estructura, celdas combinadas, columnas, bordes, márgenes y configuración de impresión A4 vertical 90% de la hoja original.
- El libro de Indicador Ambulatorio sigue manteniendo las **diez hojas y 432 códigos numéricos oficiales** sin cambiar nombres ni fórmulas.
- Stock inicial por producto: **pendiente (celda vacía)** hasta que se ingrese; si se declara **cero**, se exporta el valor 0. No reutilizar saldos del archivo antiguo.
- No se aceptan nuevas entregas clínicas ni salidas manuales de productos sin equivalencia verificada entre código del Indicador y artículo de Enfermería. La ausencia de stock o stock 0 también impide la salida. Crear lotes con saldo 0 e ingresos posteriores está permitido.
- Registros históricos de donaciones en Keychain no se borran, reinterpretan ni migran destructivamente; quedan fuera del nuevo catálogo operativo y del reporte actual.

## Pruebas de aceptación
1. 98 nombres originales, mismo orden, mismas posiciones C7:C104, sin `Hoja1` ni datos residuales de donados en las cadenas compartidas o metadatos del XLSX.
2. A4 vertical escala 90%; ninguna ruptura de bordes y celdas combinadas; revisar en Microsoft Excel real e iPhone tras CI.
3. Producto sin saldo confirmado: D/E/F/G/H en blanco; producto con saldo confirmado 0: D=0, E/G=0 (si no se ha movido), fórmulas F/H.
4. Producto con stock 0 no puede consumirse; con stock registrado y equivalencia aprobada sí, cumpliendo las reglas de cantidad 1/0 de envases.
5. Importación Keychain con datos v0.16 previos y posibles donados legados no elimina información, y estos no aparecen en selectores nuevos.
6. Verificar `npm run test:logic`, `npm run build`, `npm audit --audit-level=high`, `npm run ios:check`, construcción macOS/Xcode y verificación IPA.

## Importante
No se declara la hoja idéntica **en su impresión física** hasta abrir el nuevo XLSX en Excel real. El verificador automático comprueba la estructura y propiedades de impresión.
No utilizar datos clínicos reales: prototipo con información ficticia.
