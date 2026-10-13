# DANPER Salud Móvil v0.8.0 — Transición a almacenamiento protegido en iPhone

## Objetivo
Continuar desde la v0.7.1 sin alterar el registro clínico de prueba ni sus correcciones de interfaz. La información del **prototipo** se almacena en el llavero cifrado del dispositivo iOS (Keychain), usando `@aparajita/capacitor-secure-storage@7.1.6`, compatible con Capacitor 7.

## Reglas
- Primer inicio: intenta leer Keychain; si no hay copia, busca datos de demostración de v0.7 y los migra, verifica la escritura y solo entonces elimina los datos antiguos de localStorage.
- Carga protegida: hasta finalizar la lectura, no habilita la edición para evitar sobrescrituras con listas vacías.
- Fallo de lectura, migración o guardado: detiene la interfaz y muestra un error; **nunca** interpreta una lectura fallida como base vacía.
- Keychain sin sincronización a iCloud y con `whenUnlockedThisDeviceOnly`.
- Escrituras serializadas; limpieza de datos ficticios a través del mismo almacenamiento, con confirmación.
- El navegador de desarrollo sigue usando localStorage solo para datos inventados.

## Pruebas
`npm run test:logic` incluye migración, escritura, fallo de lectura, fallo de guardado y adaptación a navegador. `npm run build`, `npm audit` y `npx cap sync ios` quedan en GitHub Actions.

## Limitaciones
Esta implementación es una etapa de aprendizaje/validación, **no producción clínica**. Keychain no sustituye a una base SQLite cifrada con modelo de datos, gestión de claves, copias de seguridad, recuperación y auditoría. El llavero puede conservar datos tras desinstalar una app, y SideStore puede cambiar las condiciones de firma/acceso. No introducir información real de pacientes o trabajadores.

## Antes de probar
1. Conservar el IPA v0.7.1 hasta validar el nuevo build. No desinstalar innecesariamente la aplicación.
2. Instalar v0.8 sin datos reales, confirmar que las atenciones ficticias se recuperan.
3. Crear borrador, cerrar y reabrir; comprobar que existe.
4. Introducir un registro ficticio, guardar, reiniciar; comprobar persistencia.
5. En Ajustes revisar "Persistencia local", su estado, y la eliminación de todos los datos ficticios.
6. Probar iPhone con SideStore y enviar registro de GitHub Actions si falla.
