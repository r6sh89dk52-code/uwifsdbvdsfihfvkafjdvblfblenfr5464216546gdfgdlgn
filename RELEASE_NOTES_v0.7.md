# v0.7 — preparado para compilar iOS

- Fuentes acumulativas v0.6; incluye todas las funciones v0.5.1.
- Icono de la app redimensionado desde el logotipo oficial (sin recrear el logotipo).
- Flujo de GitHub Actions usando macOS para crear un archivo IPA sin firmar.
- Script bash para Xcode, validación de App.app, empaquetado Payload y SHA-256.
- Validación local de precondiciones (`npm run ios:check`).
- **No se ha compilado ni probado un IPA aún**; la construcción debe ejecutarse en Xcode/macOS.
- **No se han implementado aún datos cifrados**, por lo que esta versión es exclusiva para pruebas con información ficticia.
