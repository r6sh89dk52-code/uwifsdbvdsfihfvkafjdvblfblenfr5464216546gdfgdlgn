# DANPER Salud Móvil v0.6 — Borradores y preparación de notificaciones iOS

- Conserva todas las funciones de v0.5.1 (logo, importador PERSONAL, alergias primero, medicamentos compactos, procedimientos editables y modos de apariencia).
- Autoguardado con espera de 650 ms al editar borradores con contenido. También se vuelca el borrador durante `pagehide` y cuando el documento pasa a segundo plano. **No constituye una garantía contra cierres de proceso repentinos en el intervalo de debounce.**
- Avisos dentro de la app después de 60 minutos desde la última actualización, con botón para revisar y eliminar borradores.
- Al editar una atención ya confirmada, se genera un borrador separado que referencia la original, sin retirarla del historial de confirmadas. Al confirmar la corrección, reemplaza el original y elimina el borrador.
- Preparado puente `@capacitor/local-notifications` v7 para avisos programados iOS, con autorización explícita del usuario y cancelación al completar o eliminar borradores. **No probado aún en iPhone ni en segundo plano**.
- El navegador en Windows muestra solo alertas internas; no promete notificaciones con la app cerrada.
- Se conserva el prototipo sin autenticación y el responsable predeterminado.

## SEGURIDAD: no usar datos reales

Continúa utilizando `localStorage` **sin cifrado**. La integración de base nativa cifrada con SQLCipher, clave en el llavero iOS, pruebas de migración y respaldo seguro aún está **pendiente**, al igual que IPA y Excel exacto. Ni siquiera disponer del módulo de notificaciones convierte esta versión en segura para registros clínicos.

## Validación Windows

Extraer el ZIP en carpeta nueva, abrir PowerShell en carpeta con `package.json` y ejecutar:

```powershell
npm install
npm run test:logic
npm run build
npm audit
npm run dev
```

Probar con datos totalmente ficticios: crear una atención, escribir datos, esperar un segundo, refrescar la página, recuperar el borrador en Historial; verificar que se marque como vencido después de una hora; completar el registro y comprobar que desaparezca el recordatorio. Probar la cancelación al eliminar.

### iOS (cuando se disponga de un Mac y Xcode)

Después de npm install y npm run build: `npx cap add ios`, `npx cap sync ios`, `npx cap open ios`. Verificar permisos de notificación, app cerrada, zona horaria, cambios de hora y funcionamiento real. No distribuir ni registrar datos sensibles en esta compilación.
