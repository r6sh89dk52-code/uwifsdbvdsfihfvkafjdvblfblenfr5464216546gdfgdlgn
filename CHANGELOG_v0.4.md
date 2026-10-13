# DANPER Salud Móvil — Etapa A v0.4

Entrega acumulativa, parte del proyecto completo anterior; no es un parche.

## Cambios de v0.4

1. Se quita «Procedimiento activo para vincular insumos» y su estado. Ya no existe la selección general que podía llevar a clasificar equivocadamente el siguiente medicamento.
2. **Cada producto conserva su selector propio** de tipo de atención (columna T) y permite edición manual individual, incluso después de añadir otros productos.
3. Sugerencias independientes basadas en presentación: ampolla → INYECTABLE; tableta/cápsula → TRATAMIENTO ORAL; crema → APLICACION DE CREMA; gotas oftálmicas → APLICACION DE GOTAS OFTALMICAS.
4. Agujas y jeringas sugieren INYECTABLE si el contexto de la atención ya contiene un inyectable. Las presentaciones especializadas no se clasifican automáticamente por tener la palabra jeringa/aguja.
5. Insumos como gasas o algodón pueden vincularse con un único procedimiento pertinente. Si hay dos procedimientos compatibles, quedan sin clasificar para que el usuario elija, en vez de heredar el último procedimiento.
6. «Procedimientos independientes» permite indicar CURACION DE HERIDA u otro procedimiento sin obligar a añadir medicamentos, y sirve de contexto para clasificar insumos.
7. Se elimina `const NS` sin uso en `workbookPersonal.ts`, que causó TS6133 en la v0.3 inicial.
8. El paquete sigue incluyendo el importador de PERSONAL, trabajadores, historial, borradores, diagnósticos y la imagen oficial aportada por el usuario.

## Escenario de prueba prioritario

Agregar productos en este orden: DICLOFENACO AMPOLLA → JERINGA 5 CC → AGUJA 21G → PARACETAMOL TABLETA. El resultado esperado en cada producto es: INYECTABLE, INYECTABLE, INYECTABLE, TRATAMIENTO ORAL. Si cambias a mano el procedimiento de un producto, ninguno de los otros debe cambiar.

Agregar un procedimiento independiente CURACION DE HERIDA y después una GASA: deberá sugerir CURACION DE HERIDA cuando no haya otros procedimientos pertinentes. Si también hay un INYECTABLE, deberá solicitar elección individual para esa gasa.

## Instrucciones para Windows

Extrae esta versión en una carpeta NUEVA y conserva la v0.3 como respaldo. Desde la carpeta que contiene `package.json`:

```powershell
npm install
npm run test:logic
npm run build
npm audit
npm run dev
```

Node.js 20.19+ o 22.12+ (versiones compatibles). No copies `node_modules`, `dist` o archivos compilados de versiones anteriores. La aplicación usa la misma clave de datos locales para conservar información **ficticia** del prototipo si se ejecuta en el mismo origen del navegador. **No migres ni pruebes datos personales reales**: el almacenamiento actual en navegador no está cifrado.

## Límites

No se ha compilado aquí con npm por falta de conexión al registro de paquetes. Pasaron las pruebas de lógica y análisis de sintaxis; `npm run build` queda pendiente de ejecución en Windows. No incluye aún Kardex, Excel exportable exacto, cifrado SQLite/iOS, notificaciones de iOS o IPA firmado. Las propuestas de procedimientos son ayudas para registro y requieren confirmación clínica por el usuario.
