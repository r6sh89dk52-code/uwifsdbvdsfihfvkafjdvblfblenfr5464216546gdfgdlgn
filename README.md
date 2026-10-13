# DANPER Salud Móvil — Etapa A v0.6 (fuentes completas de prueba)

## Estado

Se conserva la v0.2 y se añade el módulo de importación local desde `PERSONAL` del libro **REAL INDICADOR AMBULATORIO -KARDEX (MEJORADO)**. **No es un IPA, ni una app validada para datos reales.** La exportación fiel a Excel será en la Etapa C; el Kardex será en la Etapa B.

## Cambios de v0.3

- **Importador .xlsx sin subida a servidor:** identifica la hoja `PERSONAL` por nombre y lee columnas A–I, incluyendo DNI, NOMBRES, edades, SEXO, UBIGEO, AREA y CARGO. No lee ni importa atenciones históricas.
- **Previsualización y confirmación:** trabajadores únicos, altas nuevas, coincidencias, DNIs repetidos y filas inválidas. Hasta pulsar «Confirmar importación» no modifica el padrón.
- **Conciliación:** evita duplicar por DNI, conserva fichas corregidas manualmente y completa campos que estuvieran vacíos. Un segundo Excel permite actualizar las fichas importadas.
- Mantiene registro y edición manual, búsqueda por DNI/nombre, diagnósticos presuntivos sugeridos, categorías del Excel, logo DANPER y modo oscuro.
- Cada medicamento sugiere su procedimiento independientemente (ampolla → INYECTABLE, tableta → TRATAMIENTO ORAL). Los insumos se vinculan por contexto cuando es inequívoco, o se solicita una selección individual. Ya no existe el selector superior de procedimiento activo. Se permiten procedimientos independientes como CURACION DE HERIDA. Los productos se buscan exclusivamente por nombre y conservan su código oficial.
- La presentación de sistemas afectados se vuelve condicional según la categoría. Antes de confirmar una atención con productos se valida que tengan procedimiento y cantidades enteras no negativas.
- El servidor de desarrollo queda limitado a **127.0.0.1**. Se propone actualización de Vite 8 y su plugin React compatible; se debe ejecutar `npm audit` en Windows para verificar la nueva resolución de dependencias.

## Instrucciones Windows PowerShell

1. Extraer el ZIP en una carpeta nueva. No copiarlo encima de v0.2 ni mover `node_modules` o `dist`.
2. Instalar **Node.js 20.19+ o 22.12+** (o más reciente compatible).
3. Desde la carpeta que contiene `package.json` ejecutar:

```powershell
npm install
npm run test:logic
npm run build
npm audit
npm run dev
```

4. Abrir la dirección `http://127.0.0.1:5173/` que muestre Vite.
5. Probar **únicamente con un Excel anonimizado o ficticio**: Inicio → Trabajadores → Importar padrón desde Excel → Seleccionar .xlsx → revisar conteos → Confirmar → buscar un DNI del archivo → usarlo en una atención de prueba.
6. Registrar un trabajador manualmente, reimportar el padrón y confirmar que se conserva su edición, sin duplicarlo por DNI.

## Seguridad y límites que siguen pendientes

**NO INTRODUCIR DATOS PERSONALES NI CLÍNICOS REALES.** Al igual que en v0.2, el padrón y las atenciones de esta versión se guardan en `localStorage` del navegador **sin cifrar**. La protección local nativa requiere integración con iOS Keychain/SQLite cifrado y pruebas de migración antes de poner la app en producción. No hay autenticación, por decisión del usuario; el responsable predeterminado permanece configurado.

No hay notificaciones locales de iOS cuando la app está cerrada. El recordatorio de borradores de 60 minutos sigue pendiente de integración nativa. No se exporta todavía el Excel original, no se calcula Kardex, no se hace conteo de envases, no se ha generado IPA ni se ha probado SideStore.

No se ha ejecutado aquí una compilación npm completa ni `npm audit` actualizado, ya que no fue posible instalar las dependencias de npm desde este entorno. La v0.3 está lista para **validación técnica en Windows**, no aprobada aún para producción.

## Catálogo y propiedad de datos

El ZIP incluye el catálogo de medicamentos/insumos extraído anteriormente de `RESU`, pero **no incluye los datos de trabajadores del Excel adjuntado**. El archivo .xlsx que el usuario selecciona se procesa localmente en su navegador. Se incluye una copia local de JSZip v3.10.1 con su licencia MIT para interpretar el formato .xlsx, sin descargas desde CDN.

## Pruebas automatizadas

`npm run test:logic` cubre DNI de 8 dígitos, ceros a la izquierda, deduplicación, validación de encabezados, prioridad a correcciones manuales y relleno de campos faltantes. Deben superarse antes de validar el flujo real de importación desde navegador.

## Kardex — decisión F/S resuelta para Etapa B

`F` = **Falta**, `S` = **Sobra**, respecto de stock teórico contra conteo físico. La columna J del Kardex deberá reflejar esa diferencia sin sumar ajustes al consumo de atenciones.

## Cambios específicos de v0.4

- Eliminado **Procedimiento activo** del formulario. Cada producto mantiene su propio selector.
- Clasificación por presentación del medicamento independiente del orden; una tableta tras un inyectable se propone como TRATAMIENTO ORAL.
- Jeringas y agujas sugieren INYECTABLE si hay contexto de un procedimiento inyectable; en caso contrario quedan pendientes de confirmar.
- Insumos de curación: se vinculan a CURACION DE HERIDA si es el único procedimiento pertinente; si hay ambigüedad se solicita decisión manual.
- Nuevo registro opcional de procedimiento independiente, incluido CURACION DE HERIDA.
- La selección manual de un producto no modifica los demás ni se sobrescribe al agregar otros.
- La base de datos continúa siendo un prototipo sin cifrado: **solo datos ficticios**. No se ha implementado el Kardex ni la exportación final de Excel.


## v0.5 — Reordenamiento para seguridad y rapidez
- **Alergias antes de medicamentos y procedimientos.** Estados: no evaluado / refiere no tener alergias conocidas / conocidas, por trabajador.
- La comprobación de alergias **solo compara literalmente nombres** y puede no detectar ingredientes o reacciones cruzadas; no constituye evaluación de seguridad farmacológica.
- En este prototipo, el estado de alergias se conserva en `localStorage` **sin cifrar**. Exclusivamente utilizar información ficticia.
- Medicamentos compactos, agrupados por procedimiento; cada grupo y cada producto son desplegables. El selector de procedimiento individual no se elimina.
- El buscador se muestra al tocar «Agregar otro», debajo de la lista, y la barra fija ofrece Resultado/Borrador/Guardar.
- La v0.5 **no incluye** todavía cifrado nativo, notificaciones iOS, la exportación Excel ni Kardex automático.


## Cambios v0.6

Revisar `CHANGELOG_v0.6.md`. Autoguardado y avisos internos desde 60 minutos; puente de notificaciones nativas a validar en iOS. Sigue prohibido introducir datos reales: localStorage no cifrada.
