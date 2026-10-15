# DANPER Salud Móvil v0.18.1 / iOS build 181 — Excel PERSONAL y fusiones sin duplicados

## Error reportado
Dos libros Excel PERSONAL creados por el flujo de depuración y pruebas incluían el carácter Unicode BOM (U+FEFF) delante de la declaración XML del archivo de relaciones xl/_rels/workbook.xml.rels. DOMParser en WKWebView puede rechazar esa declaración como XML mal formado. Los archivos ZIP y documentos XML eran válidos al leer bytes, pero el lector anterior no normalizaba BOM al recibir cadenas.

## Corrección
- src/workbookPersonal.ts: elimina exclusivamente U+FEFF inicial al analizar las partes XML. Distingue errores por ruta de parte; no elimina datos ni afecta el archivo original.
- src/workerRules.ts: DNI de ocho cifras es la identidad única. Una importación posterior mezcla nuevos y existentes por DNI. Nunca duplica trabajadores, ni sobreescribe nombres o sexo cuando el mismo DNI trae información contradictoria: conserva el valor anterior y cuenta la discrepancia para revisión.
- src/PersonalImporter.tsx: resumen de nuevos, ya existentes y conflictos de identidad/sexo antes de confirmar.
- El archivo importado no se añade al repositorio, no se empaqueta en el IPA y no se transmite por red; el padrón se conserva en el almacenamiento privado cifrado del iPhone.
- Importación local opcional, pensada para configuración inicial y actualizaciones posteriores. No es necesario repetirla en cada apertura de la aplicación.
- No inferir sexo a partir del nombre.

## QA y privacidad
- Prueba nueva scripts/test-personal-xml-dedupe.cjs genera libros PERSONAL ficticios con BOM UTF-8 y sin él, reproduce el comportamiento restrictivo de iOS y valida reimportación idéntica, Excel mixto con nuevos/antiguos, correcciones manuales y conflictos.
- Mantener el resto del Indicador y Kardex sin cambios. Sólo datos ficticios durante pruebas del sistema.
- Antes de importar un padrón real, confirmar SideStore/iPhone, persistencia, respaldo y seguridad del dispositivo. NO colocar nombres/DNI reales en GitHub.
