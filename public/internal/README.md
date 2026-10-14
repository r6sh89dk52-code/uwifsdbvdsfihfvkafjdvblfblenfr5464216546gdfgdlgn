# Plantilla interna del Kardex de Enfermería

Esta carpeta contiene el recurso de la versión de pruebas v0.16.3.

**Archivo que se debe subir aquí:** `kardex-template.bin`
**Ruta final obligatoria:** `public/internal/kardex-template.bin`

Al subirlo, usar la rama `feature/v0.16.3-ios-kardex-ux` y seleccionar «Commit directly to this branch». No subirlo a `main`.

No alterar su nombre ni convertirlo en Excel. El archivo contiene la plantilla .xlsx depurada en su formato binario; la aplicación la abrirá directamente y nunca pedirá importarla.

**Importante:** las pruebas CI impiden la integración si la plantilla falta o no supera la validación de estructura e integridad. Sólo datos ficticios; no colocar aquí datos clínicos reales.
