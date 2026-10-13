# DANPER Salud Móvil — Etapa A v0.5

### Cambios acumulativos sobre v0.4
1. Módulo de alergias situado inmediatamente debajo del trabajador, antes de datos de atención, procedimientos y medicamentos.
2. Diferenciación explícita entre no evaluado, refiere no tener alergias conocidas y alergias reportadas.
3. Registro local por DNI para **pruebas ficticias**, con advertencia de ausencia de cifrado.
4. Coincidencia **únicamente textual** con advertencia y confirmación antes de añadir productos; no detectar una coincidencia **no prueba seguridad**.
5. Medicamentos organizados por procedimientos en grupos plegables y tarjetas compactas, expandidas para cambiar cantidad, procedimiento o eliminar.
6. «Agregar otro» al final de la lista; al seleccionar insumo ambiguo se abre su editor.
7. Barra inferior Resultado / Borrador / Guardar por encima de la navegación.
8. Conserva logo original, importador PERSONAL, padrón local, sugerencias de diagnósticos y reglas individuales de procedimientos.

### Pendientes y limitaciones
- No contiene base nativa SQLite/SQLCipher ni seguridad para usar datos clínicos reales.
- El almacenamiento del navegador/localStorage de atenciones, trabajadores y alergias no está cifrado.
- No incluye IPA, exportación Excel, Kardex ni notificaciones iOS.
- No se ha garantizado disponibilidad de módulos nativos para despliegue.
