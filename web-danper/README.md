# DANPER SALUD WEB — desarrollo integral en curso

React + TypeScript + Vite, generado desde el HEAD nativo auditado. **No es todavía una plataforma clínica integral validada ni está desplegada.** Consulta [la matriz y pendientes](docs/AUDITORIA_Y_PARIDAD.md).

## Ejecutar en Windows

Desde la raíz del repositorio, abre `web-danper/ABRIR_DANPER_WINDOWS.bat`. Se necesita Node.js 22.12 o posterior. El script instala desde package-lock si corresponde, genera el contrato y abre el servidor HTTP local. Conserva la carpeta dentro del repositorio: la generación consulta las fuentes Swift de `../native-ios`.

```powershell
cd web-danper
npm ci
npm run build
npm test
npm run test:ui
npm run test:pwa
```

Los datos iniciales están vacíos. No se incluyen trabajadores reales ni una base clínica de demostración. Los tests usan identidades ficticias. El cierre del navegador conserva los datos en IndexedDB del mismo origen y perfil; borrar los datos del sitio los elimina. El respaldo cifrado se descarga mediante Ajustes. La migración del respaldo nativo permanece en staging, sin escritura cloud.

## Firebase

No se encontró configuración real en los recursos accesibles. Copia `.env.example` a `.env.local` y completa la configuración pública de la aplicación Firebase y el UID autorizado. Habilita Google en Authentication y crea Firestore. No incluyas claves privadas ni cuentas de servicio.

```powershell
$env:FIREBASE_PROJECT_ID = 'ID_REAL'
$env:DANPER_AUTHORIZED_UID = 'UID_VERIFICADO'
npm run firebase:prepare
npm run build
firebase emulators:start --config firebase.authorized.json
# Ejecutar y revisar primero las pruebas de reglas y sincronización pendientes.
firebase deploy --config firebase.authorized.json --only hosting,firestore
```

Firebase CLI no es dependencia del runtime de la web. Se requiere una sesión autorizada para desplegar. El script no crea cuentas ni activa facturación. `firestore.rules` deniega todo por defecto. No se proporciona URL web.app porque no se ha desplegado.

## Alcance comprobable

- Catálogo original completo: 432 productos; Kardex: 98; 86 correspondencias y seis adicionales extraídas de Swift.
- Registro de trabajadores, cuatro pasos de atención, borradores, historial y rectificaciones acotadas.
- Lotes, aperturas declaradas, FEFO, ingresos, conteos y cierres con eventos auditables.
- Importadores PERSONAL y exámenes mediante revisión de columnas; EMO, colinesterasa, descansos y alertas vinculados por DNI.
- Escritores de indicador y Kardex con recursos originales; exportación de fechas sobre plantilla conservando partes OOXML no modificadas.
- Cola IndexedDB, cliente Firebase CAS y adaptador Swift aislado, con limitaciones descritas en el contrato.

## Pendientes antes de uso clínico integral

Sincronización real y resolución completa de conflictos, migración íntegra con journal cifrado nativo, todas las reglas/fixtures de contabilidad automática y conciliación, rectificación nativa completa, inventario auxiliar, validación comparativa de vigilancia osteomuscular, plantilla oficial de descansos y estadísticas, paridad completa de importadores EMO/colinesterasa y sus programaciones originales, prueba Safari/Firefox/Edge e instalación PWA. El manifiesto, precaché y recarga offline de producción pasaron en Chromium; la compatibilidad entre todos los navegadores todavía no está certificada.

La prueba de apertura R=1,0,0,1,0 reproduce expectativas explícitas de `N3DeclaredContainerTests.swift`; aún no es una ejecución comparativa simultánea del paquete Swift y TypeScript. Las pruebas de concurrencia actuales verifican IndexedDB local, no sustituyen dos clientes Firestore reales.
