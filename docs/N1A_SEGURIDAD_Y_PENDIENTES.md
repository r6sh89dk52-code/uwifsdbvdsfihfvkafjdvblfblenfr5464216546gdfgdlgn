# DANPER SwiftUI N1a — aislamiento y base cifrada (experimental)

## Base y seguridad
- PR N0: rama `native/swiftui-foundation-v0.1`, commit `8b85264066fd772b35d87b76c7e6a0a296c49f97`.
- La build 222 existente conserva su bundle ID `pe.danper.saludmovil.prototipo` y datos. No se modifica.
- El nuevo bundle ID continúa siendo `pe.danper.saludmovil.native.preview`.
- N1a contiene únicamente un **laboratorio sintético**, no un almacén clínico. Nunca importar una copia real aquí.
- Prohibido subir a GitHub respaldos auténticos, DNI, claves, contraseñas o historiales.

## Implementado
1. `NativeEncryptedLabVault` (solo iOS): Keychain aislado y no sincronizado, accesible solo desbloqueado y en este dispositivo; AES-256-GCM usando CryptoKit.
2. Archivos privados con protección completa, excluidos de respaldos de iCloud, escritura copy-on-write con nombre UUID, verificación de descifrado antes de activar la referencia en Keychain. No borra generaciones anteriores.
3. Pantalla de laboratorio para generar **solo un contador ficticio**, verificarlo al reiniciar y observar errores sin volcar contenido clínico.
4. `N1BackupAdmission` (Swift puro): inspección de las nueve colecciones del formato legado. Clasifica consumos clínicos pendientes por diferencia con movimientos vinculados. Rechaza colecciones ausentes, estructura dañada y copia vacía. Pruebas Linux reproducibles.

## Limitaciones explícitas
- Esto **no importa respaldos**, no migra pacientes, no escribe historial clínico y no garantiza todavía paridad con un respaldo del iPhone.
- No existe aún un diario persistente de restauración de múltiples dominios (padrón + historia + Kardex): requerido antes de importar datos reales.
- La copia original del iPhone no se ha probado con el lector SwiftUI; el formato criptográfico es compatible por diseño, pero no constituye verificación empírica.
- La protección por Keychain del laboratorio requiere ensayo físico y pruebas macOS/Xcode; `swift test` solo valida `DanperCore`.
- Una nueva instalación tiene directorios separados y no puede consultar la base de la build 222 de manera implícita.
- Las validaciones del formato legado heredan límites de la build 222 (hasta 30 MB en JSON, 30 mil trabajadores, 500 lotes, 1.000 movimientos). No ampliar límites sin probar conservación y desempeño.

## Próximo paso N1b
1. Generar muestras **exclusivamente sintéticas** desde el cifrador TypeScript original y comprobar que el lector Swift las descifre en pruebas iOS.
2. Validar el respaldo auténtico únicamente dentro del iPhone, por recuentos; jamás transmitir archivos ni contraseñas.
3. Implementar prueba de restauración transaccional en una instalación vacía, con rollback/reanudación ante fallos inyectados y comparación 1:1 de todos los registros.
4. Recién después habilitar migración de datos y continuar N2–N4.
