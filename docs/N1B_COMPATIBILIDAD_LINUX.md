# N1b — Compatibilidad de respaldo entre TypeScript y Swift (Linux exclusivamente)

**Rama:** `native/swiftui-n1b-linux-crypto-restore`. Base N1a. No fusionar ni reemplazar la build222.

## Alcance N1b
- Usa el **cifrador TypeScript real** `src/portableBackup.ts` para producir respaldos de prueba con pacientes totalmente ficticios dentro del runner.
- El módulo `N1PortableArchiveReader` usa **Apple Swift Crypto** (CryptoKit Apple / BoringSSL Linux) para comprobar AES-256-GCM y PBKDF2-HMAC-SHA256 de 310000 iteraciones del respaldo original.
- Compara digest SHA256 de **todo el contenido descifrado**, tamaño y nueve colecciones, no solamente un recuento.
- Pruebas de contraseña incorrecta, tag GCM alterado y downgrade KDF. Nada se exporta fuera del runner: archivos temporales bajo RUNNER_TEMP, sin acciones de carga de artefactos.
- Simulador `N1SyntheticRestoreCoordinator` prueba recuperación antes/después del punto de activación de un *puntero único de generación*, rechaza contenido no sintético y un par de dominios incompleto. **No es una restauración real**.
- Se compila/prueba únicamente en `ubuntu-latest`. Ningún workflow macOS se añade ni ejecuta, ni se genera .ipa.

## Límites
1. La prueba de interoperabilidad usa datos sintéticos; no demuestra la compatibilidad de **tu copia real**.
2. El lector nativo SwiftUI instalado aún utiliza la implementación CommonCrypto de N1a; tras validar interoperabilidad podemos sustituirla usando el nuevo núcleo portable, pero eso requiere un gate de compilación iOS autorizado.
3. La simulación es solo un modelo en memoria, no implementa recuperación real iOS; faltan journal persistente, simulación de fallos de escritura FileManager/Keychain, preservación de generaciones, validación de datos físicos y rollback.
4. Nunca subir originales .danperbackup, credenciales o registros clínicos a GitHub. No cargar el respaldo en pruebas automáticas.
5. `swift test` sin `DANPER_N1_FIXTURE_DIR` omite solo los casos cifrados cruzados; CI siempre genera las fixtures.

## Próximo gate
Paridad cifrada `TypeScript -> Swift` en Linux PASS, luego auditoría N1c del plan de persistencia y verificación de errores de compatibilidad antes de permitir cualquier importación a un iPhone vacío. La build222 permanece inalterada.
