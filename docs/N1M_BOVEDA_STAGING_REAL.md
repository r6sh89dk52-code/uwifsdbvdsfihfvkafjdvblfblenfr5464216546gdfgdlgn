# N1m — Bóveda clínica nativa de PREPARACIÓN, jamás de fusión

## Principio de origen único
La futura app SwiftUI no importa trabajadores sobre el padrón sintético N1g ni agrega una atención sobre otra fuente. N1m admite como candidato solo un snapshot completo de las nueve colecciones de la build 222, con campos originales e incluso desconocidos, evaluado por N1l. **Ningún dato de pacientes reales se utiliza en los CI.**

## Lo implementado
- Núcleo `N1mRealClinicalStagingVault` con AES-256-GCM, AAD independiente, clave simétrica suministrada externamente y dos archivos: `complete-source.gcm` y `prepared-receipt.json`. El recibo HMAC-SHA256 autentica SHA-256 de ciphertext, hash de bytes originales, hash semántico N1f, recuentos de pacientes y consumos pendientes. No aparecen DNI ni nombres en el recibo.
- Directorio separado `DANPER-N1M-REAL-STAGING` en Application Support (o directorios temporales sintéticos `danper-n1m-synthetic-*` en pruebas). Prohibido apuntar al depósito N1I DEMO, archivo de build 222 o directorios con ficheros desconocidos. Protecciones iOS `FileProtectionType.complete` y exclusión de copia de seguridad.
- La preparación valida ANTES de escribir. Primero escribe bytes cifrados; verifica descifrado y que todos los campos y cantidades sigan coincidiendo; **solo después** escribe un recibo autenticado. No produce un archivo JSON clínico descifrado persistente.
- Repetir la misma copia exacta es idempotente. Una fuente diferente falla con `sourceConflict`. Si iOS se detiene entre la escritura cifrada y el recibo, al reabrir NO presenta el trabajo como completo: exige volver a seleccionar la misma copia para completar el recibo, sin borrar o sustituir el cifrado existente.
- Adaptador de iPhone `N1mRealClinicalStagingIOSVault`: nuevo servicio de Keychain `pe.danper.saludmovil.native.preview.n1m.real-staging`, `whenUnlockedThisDeviceOnly`, sin iCloud Keychain, clave aleatoria independiente; si ya hay ciphertext sin clave falla, sin generar una reemplazante. Este método **no está invocado por ninguna vista**: todavía no hay un botón para importar ni escribir datos reales.
- El indicador `canActivate` es SIEMPRE `false`. No existe API de activación ni escritura al almacén clínico real, incluso para fuentes estructuralmente limpias. El cifrado autentica contenido, pero no demuestra su origen ni la ausencia de registros ficticios sin etiquetas.

## Pruebas
- Se agregan 11 pruebas Swift sobre el fixture 100 % sintético del generador TypeScript N1f: 9 colecciones, preservación de borradores incompletos y extensiones, idempotencia, rechazo de fuentes alternativas, cierres interrumpidos antes/después del recibo, clave errónea, manipulación de ciphertext o recibo, rechazo de origen mixto reconocible, duplicados y directorios prohibidos.
- 111 pruebas Swift anteriores siguen obligatorias. Linux solo usa material sintético en `RUNNER_TEMP`.
- Xcode vuelve a compilar para iOS Simulator y iPhone genérico SIN firma y SIN IPA. No se prueba ni instala en el iPhone.

## Lo que falta antes de activar historias clínicas auténticas
1. Contrastar con una copia reciente .danperbackup **sin registros ficticios mezclados**, seleccionada por el usuario únicamente en su iPhone. Una identificación por nombre/DNI sin historial de procedencia no basta para decidir automáticamente si es real.
2. Conectar al adaptador el descifrado protegido con contraseña, solo mediante aceptación explícita; actualmente el inspector N1l tiene acceso de solo lectura y N1m no recibe esa salida.
3. Implementar almacén CLÍNICO ACTIVADO nuevo y vacío, distinto del STAGING, con transacción/journal y recuperación verificada antes de cambiar punteros. No reutilizar N1g ni fusionar bases.
4. Validar paridad 1:1 de Kardex físico, movimientos FEFO, consumos ambulatorios, todos los borradores, correcciones, alergias e histórico y la exportación del Excel oficial de diez hojas.
5. Ejecutar más adelante pruebas en iPhone de suspensión, reinicio y permisos, manteniendo build 222 disponible e intacta.

**Advertencia de durabilidad:** `.atomic` y HMAC no son equivalentes a `fsync` o a un commit transaccional final. N1m es una bóveda de preparación todavía INACTIVA. Una restauración real de registros sobre ella está prohibida por diseño.
