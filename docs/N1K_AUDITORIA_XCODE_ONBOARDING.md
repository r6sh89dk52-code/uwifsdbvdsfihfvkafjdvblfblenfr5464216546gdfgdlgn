# DANPER N1k — Auditoría Xcode sin instalación y bienvenida de primer inicio

## Qué autoriza esta etapa

La auditoría compila una **aplicación nativa separada** de la build 222. No se instala nada en el iPhone, no se firma ningún binario y **no se genera ninguna IPA**. La revisión Xcode usa iOS Simulator y un dispositivo iOS genérico con CODE_SIGNING_ALLOWED=NO; los productos intermedios permanecen en la carpeta efímera del runner macOS, sin descargarse ni adjuntarse a la conversación.

## Onboarding nativo

- Primer inicio: bienvenida DANPER con logotipo oficial y transición SwiftUI; explicación y solicitud voluntaria de notificaciones locales; confirmación voluntaria de Face ID o Touch ID cuando hay biometría disponible; resumen de privacidad.
- El botón de notificaciones invoca explícitamente UserNotifications.requestAuthorization(.alert,.sound,.badge). **No hay prompt automático** al abrir. Si se deniega, la introducción sigue y se pueden modificar preferencias en Ajustes iOS.
- El botón biométrico utiliza LAContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics). Si no está disponible o se omite, el desbloqueo de la app usa LAContext.deviceOwnerAuthentication que admite código del dispositivo. No almacenamos rostros ni huellas.
- La pantalla se muestra una sola vez mediante AppStorage con una marca no sensible; se completa únicamente al llegar al último paso y aceptar «Ir a DANPER Salud».
- No se solicita cámara, galería, micrófono ni ubicación: el formulario actual no utiliza esas funciones. El selector de respaldo real emplea el selector de archivos de iOS cuando el usuario decide abrirlo.

## Datos reales: posición de seguridad

La pantalla Inicio presenta un acceso directo al **inspector de respaldo real cifrado** de la build 222. La lectura requiere seleccionar el archivo en el propio iPhone e introducir la contraseña. Actualmente verifica datos agregados (trabajadores, atenciones, lotes, movimientos y consumos no vinculados); **no importa ni escribe** historias, alergias, inventario o consumos. La bóveda ficticia N1g/N1i/N1j sigue completamente separada del esquema real.

Para habilitar operaciones reales falta el adaptador de importación **transaccional y sin pérdida** a un almacén clínico Swift nativo, validado con una copia local en el iPhone tras auditorías completas de 10 hojas de Excel, Kardex FEFO, idempotencia, historiales y respaldos. No copiar registros reales ni claves a GitHub, al chat ni a logs de CI.

## Criterios técnicos de esta auditoría

- CI Linux: 99 pruebas Swift anteriores + análisis sintáctico de todos los archivos SwiftUI, incluyendo bienvenida.
- CI macOS **solo tras autorización expresa del usuario**: generar proyecto Xcode con XcodeGen, compilar primero para Simulator y luego para iOS genérico sin firma, revisar identificador de app y descripción de Face ID en Info.plist; no ejecutar iPhone físico.
- El esquema project.yml mantiene PRODUCT_BUNDLE_IDENTIFIER pe.danper.saludmovil.native.preview. **Prohibido** usar pe.danper.saludmovil.prototipo o tocar release/v0.21.12-build222-provisional-consumptions.
- Una compilación Xcode exitosa prueba tipado/enlace SwiftUI/Keychain y estructura del binario, no permisos de primer uso, notificaciones fuera de la app, persistencia ante suspensión real ni restauración de datos auténticos. Esto sí deberá verificarse en iPhone más adelante.
