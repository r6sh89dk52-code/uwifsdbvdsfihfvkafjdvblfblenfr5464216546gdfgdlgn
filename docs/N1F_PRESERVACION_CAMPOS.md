# DANPER N1f — Preservación integral de campos (solo Linux)

N1f verifica sin editar registros que el árbol JSON de las nueve colecciones del formato original puede atravesar Foundation JSON sin pérdida semántica. El fingerprint SHA256 incorpora todos los nodos tipados (objetos, arrays, strings, números, booleanos y null), sus rutas de claves y el orden de los arrays; se revisan también campos desconocidos que pudiera traer una versión futura.

Los tipos comprobados provienen de main.tsx, workerRules.ts, secureDemoStore.ts y draftRules.ts de la rama de producción híbrida. Se preservan correcciones locales del trabajador, sede, datos clínicos, procedimientos, flags, borradores incompletos, borradores de corrección y los estados de alergias unknown/none/known. Una alergia conocida sin sustancias documentadas se señala para revisión sin convertirla en negada.

El generador JS crea exclusivamente trabajadores y atenciones ficticias en RUNNER_TEMP. El fingerprint se calcula en JS y Swift de manera independiente para comprobar paridad completa; 10 pruebas incluyen pérdida de extensiones, null, borradores, cambios del estado de alergia y flags, duplicidad de DNI/atenciones e independencia del orden de claves.

Aún no existe un importador clínico real ni escritura a Keychain, SQLite o exportación de XLSX nativa. El fingerprint no reemplaza autenticación de los respaldos. No usar ni subir backups personales reales al CI. Se conservan pruebas N1b–N1e y se ejecuta exclusivamente en Linux, sin compilar IPA. Los límites de 500 lotes y 1000 movimientos requieren un diseño posterior.
