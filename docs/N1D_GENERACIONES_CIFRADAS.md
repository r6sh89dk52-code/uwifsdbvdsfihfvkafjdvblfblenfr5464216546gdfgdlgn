# N1d — Generaciones cifradas con recuperación durable, sin IPA

## Objetivo
Avanzar N1c a un **laboratorio de almacenamiento cifrado** con uso de archivos reales en Linux, sin tocar una instalación real ni prometer restauración clínica.

## Implementación
`native-ios/Sources/DanperCore/N1EncryptedGenerationLab.swift`
- Una clave AES-256 (Swift Crypto) **se suministra desde fuera** y jamás se escribe en este laboratorio; en iOS el próximo adaptador deberá obtenerla del Keychain con acceso `whenUnlockedThisDeviceOnly`.
- Padrón y atenciones sintéticos se cifran independientemente con AES-256-GCM, nonce aleatorio y **AAD** asociado a la generación y al dominio.
- Dos archivos `.gcm` se autentican y comprueban por SHA-256 antes de crear el journal.
- Journal y puntero de activación llevan **HMAC-SHA256** para detectar modificaciones no autorizadas; un solo puntero determina si se activaron ambos conjuntos.
- `Data.write(.atomic)` para copiar generación y puntero; no borra archivos cifrados anteriores.
- `recover` con clave correcta revalida ambas mitades; con clave incorrecta, metadatos manipulados o archivo GCM alterado bloquea lectura y sobrescritura.
- Restringe estrictamente el uso a directorios temporales `danper-n1d-synthetic-*` y cargas `N1D-CANARY|` ficticias (máximo 4 KiB por dominio). No recibe ni restaura un `.danperbackup` real.
- No devuelve contenido descifrado por API. Solo el identificador de generación, nunca datos de trabajadores.

## Pruebas
Además de los 30 casos N1c/N1b, 12 pruebas de N1d cubren:
- Lectura tras reinicio y confidencialidad de archivos.
- Interrupciones después de cada archivo, journal y puntero.
- Clave equivocada, manipulación de GCM antes/después de activación, intercambio de archivos de diferentes dominios y manipulación HMAC.
- Entrada no ficticia, directorio no autorizado, archivo cifrado ausente.
- Pruebas criptográficas TypeScript → Swift Crypto N1b permanecen en el pipeline.

## Límites pendientes
No se ha integrado la capa con SwiftUI, Keychain, la base clínica, inventario ni exportación de Excel. No se ensayó persistencia física ante corte de energía (`fsync` ni semántica de hardware), bloqueo interproceso, garantía antirollback/monotonicidad, protección completa de datos iOS ni restauración desde respaldo real. `Data.write(.atomic)` ofrece sustitución atómica de nombre pero no garantiza durabilidad física absoluta.

En la siguiente etapa, diseñar el adaptador Keychain/iOS sin ejecutar una IPA prematura; preparar comparación sintética 1:1 y reglas de FEFO/stock pendientes antes de habilitar importación en instalación vacía. La build222 permanece intacta y la PR no debe fusionarse sin revisión.
