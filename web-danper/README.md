# DANPER SALUD WEB — desarrollo integral en curso

React + TypeScript + Vite, generado desde el HEAD nativo auditado. **No es todavía una plataforma clínica integral validada. Hosting está publicado para validación.** Consulta [la matriz y pendientes](docs/AUDITORIA_Y_PARIDAD.md).

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

Proyecto real: `danper-salud-web-20261025`. [Abrir la versión publicada](https://danper-salud-web-20261025.web.app). Google Authentication está configurado para la cuenta autorizada; su inicio interactivo de sesión aún no tiene prueba de extremo a extremo.

Firestore Standard se configura en Santiago, `southamerica-west1`, con reglas que deniegan todo. Las escrituras clínicas permanecen desactivadas y no se migraron datos reales. El archivo `firebase-project.public.json` contiene únicamente identificadores públicos del proyecto y el UID autorizado.

`npm run firebase:configure` prepara la configuración local pública sin activar escrituras. Luego ejecuta `npm run build`. El despliegue requiere la sesión autorizada de Firebase CLI. No adjuntes claves privadas ni cuentas de servicio.

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

## Ajustes de formularios y prueba ficticia

El responsable de registros nuevos usa la identidad preconfigurada en SwiftUI. Sede y sexo se eligen con selectores. El Kardex permite pegar o escribir el producto, muestra sugerencias y hereda la presentación del catálogo nativo; una unidad no verificada exige elección explícita. El registro inicial ya no solicita stock mínimo ni capacidad interna. Las aperturas R=1/0 durante dispensación conservan su confirmación física.

En Ajustes, **Probar con datos ficticios** abre una base IndexedDB separada, con tres trabajadores, dos atenciones y un lote. Nunca entra en la cola cloud. Dentro de la prueba puedes descargar PERSONAL ficticio y cargarlo desde Trabajadores para verificar la importación con vista previa. **Volver a mis registros** retorna al espacio habitual sin sobrescribirlo. El respaldo nativo real sigue limitado a staging.

## Ventanas de confirmación, corrección y padrón

Las operaciones guardadas muestran una ventana central después de completar la transacción local. Los errores de validación ofrecen Corregir para enfocar y resaltar el dato pendiente sin borrar el formulario. La importación por bloques muestra una sola confirmación al finalizar; los borradores automáticos permanecen silenciosos. Las descargas muestran Archivo preparado.

Registrar → Buscar en padrón abre un buscador por DNI o nombres, ordenado y paginado de 25 en 25. La elección de una ficha es explícita. Si no se encuentra al trabajador, puede registrarse desde la misma atención; un DNI existente conduce al padrón y no sobrescribe la identidad. Si el padrón está vacío, se ofrece importar PERSONAL en ese paso.

Los diálogos mantienen el foco de teclado, y las animaciones respetan prefers-reduced-motion. Validación: 24 pruebas de dominio y 17 casos UI pasados, con una repetición móvil omitida.
