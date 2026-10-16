# N1i — Borradores de DEMOSTRACIÓN con AES-GCM y recuperación

## Alcance real implementado

- N1iDemoArchiveCodec: archivo con marcador 'DANPER-N1I-DEMO-ONLY|', máximo de 64 KiB y catálogo estricto ficticio de trabajadores, atenciones, alergias y borradores. Rechaza nombres reales, diagnósticos fuera del catálogo, duplicados, referencias de corrección inexistentes y cantidades no admitidas.
- N1iEncryptedDemoDraftVault: AES-256-GCM, AAD por generación, autenticación HMAC-SHA256 del puntero. Escribe archivo cifrado, comprueba descifrado antes de activar un único puntero lógico y conserva generaciones anteriores. Una clave errónea o archivo alterado bloquea acceso; no se reinicia silenciosamente.
- Restricción de rutas a directorios temporales 'danper-n1i-synthetic-*' o al único directorio de prueba en Application Support 'DANPER-N1I-DEMO'. 
- Adaptador Swift iOS N1iDemoDraftIOSVault: Keychain exclusivo del prototipo 'pe.danper.saludmovil.native.preview.n1i.demo-only', clave aleatoria AES-256 accesible solo con dispositivo desbloqueado, sin iCloud Keychain. Los archivos se protegen con FileProtectionType.complete y se excluyen de copia de seguridad.
- NativeRootView restaura la sesión ficticia desde Keychain/archivo al abrir, guarda con espera de 650 ms ante cambios y solicita guardado al dejar primer plano. Si hay error de lectura/autenticación, bloquea edición de simulaciones.
- Jamás accede al Keychain, rutas ni datos de producción de la build222. Tampoco escribe en N1/N1a, FEFO o Kardex existentes.

## Qué prueban las verificaciones

Diez pruebas Linux para serialización cifrada, reinicio, pérdida de energía simulada antes y después del puntero, clave incorrecta, manipulación de ciphertext y manifest, alteración concurrente, preservación de borradores de corrección y rechazo de datos reales/no ficticios. Se conservan las 79 pruebas N1h y los escenarios TypeScript originales.

Limitaciones: las comprobaciones de SwiftUI en Linux son de **sintaxis solamente**; el tipado iOS y la integración real Keychain necesitan Xcode más adelante. El guardado diferido y el intento al ir a segundo plano no ofrecen garantía total de persistencia cuando iOS termina abruptamente. Sin fsync, bloqueo interproceso ni antirollback criptográfico del puntero. No es un almacén clínico operativo y no permite restaurar datos reales. Cero runner macOS y cero IPA. PR borrador sin fusionar.
