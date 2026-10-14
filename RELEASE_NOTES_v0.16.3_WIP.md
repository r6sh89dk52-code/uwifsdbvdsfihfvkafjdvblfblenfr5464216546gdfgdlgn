# DANPER Salud Móvil v0.16.3 — reorganización iOS (EN DESARROLLO)

Rama `feature/v0.16.3-ios-kardex-ux` a partir de v0.16.2 / build 162. No fusionar a main antes de cerrar los pendientes.

## Implementado en el PR
- Kardex de Enfermería organizado en cuatro secciones navegables: Inventario, Movimientos, Entregas y Reportes.
- Búsqueda por texto para los 98 productos existentes del Kardex en inventario y movimientos, con sugerencias, búsqueda sin tildes y selección explícita.
- Vista previa extensa del reporte tras control desplegable.
- Ajustes de CSS para pantallas pequeñas, controles de fecha, cabecera y áreas seguras.
- Advertencia B0 obsoleta corregida, sin alterar reglas de inventario ni correspondencias.

## Pendientes obligatorios antes de finalizar
- Incluir en la app, de forma local, el fichero binario sanitizado de la plantilla original de octubre, únicamente hoja «KARDEX ENFERMERAS», 98 productos sin donados, sin saldos/fechas originales. El exportador actual todavía solicita elegir el Excel. No eliminar ese selector hasta comprobar el recurso integrado.
- Versionar package-lock, IPA/build, workflow y verificador al nuevo número de build.
- Verificar que la plantilla integrada coincide con la original en formatos de impresión y no incorpora información sensible.
- Pruebas en iPhone físico, autofoco/teclado/scroll, exportaciones y firma SideStore.

Se preservan Keychain, los 86 vínculos aprobados, la exclusión de donados y nylon, las dos llaves independientes, el inventario e historial. EXCLUSIVAMENTE DATOS FICTICIOS.
