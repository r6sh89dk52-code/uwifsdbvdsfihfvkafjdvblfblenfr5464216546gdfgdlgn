# DANPER N1r — Escritor nativo Swift XLSX, laboratorio aislado

El módulo \`N1rNativeWorkbookWriter\` escribe directamente ZIP32/OOXML **desde Swift**, con método STORE sin compresión, CRC32 verificado, directorio central validado, límites de tamaños y rutas seguras. Recibe exclusivamente la plantilla saneada de diez hojas embebida en TypeScript, convertida temporalmente a ZIP STORE por un generador de prueba. Crea celdas tipadas de CONSUMOS A–AD, mantiene DNI y código en texto, escapa entradas peligrosas, añade fórmulas de organización C/D y actualiza el rango de TB_CONSUMOS y la dimensión.

Pruebas: dos planes clínicos completamente ficticios de N1p, exportados físicamente mediante Swift a archivos en RUNNER_TEMP y abiertos en Node con ZIP/XML; comparación contra 30 valores por fila del motor TypeScript, 10 hojas, 19 tablas, 432 materiales y verificación byte a byte de las otras 9 hojas y estilos. Pruebas negativas de ZIP/CRC, plantilla incompleta, DNI numérico, ID duplicado, control XML y texto de inyección.

**Alcance restringido:** las otras hojas están preservadas, **no rellenas ni recalculadas de forma nativa**. Los nuevos registros todavía no heredan todo el formato, validaciones ni estilos de CONSUMOS. No hay compresión DEFLATE nativa ni recurso de plantilla Swift empaquetado. No es un exportador clínico para uso real. No toca pacientes, Keychain, build222 ni IPA. \`canActivate=false\` y \`supportsFullExcelParity=false\`.

Siguiente fase: formato completo por celdas, fórmulas/conciliación nativa de RESU/INGRESOS/CONTEO, validación con Excel en macOS/iPhone y evaluación de compresión.
