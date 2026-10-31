# Auditoría integral Build 15 — alcance, controles y evidencias

Inicio: `cc45aa27013922a68301be01eaa1f1a16ad9e910`, PR #10. Base estable Build 14: `9b1da6d4cdead4729bcade6843abcbcfc287e870`. Trabajo exclusivo en `fix/indicator-historical-visit-site-build15-20261030`.

## Estado de validación

Este documento describe cambios y cómo se comprueban; **no certifica una ejecución pendiente**. El workflow B15 genera `FINAL_GATES.json` únicamente cuando las pruebas del SHA actual terminan sin fallos. Los resultados antiguos se usan solo para diagnóstico, comparación de rendimiento y producción de entradas cifradas de compatibilidad; no certifican el nuevo HEAD.

La entrega incluye un inventario estático de los 56 archivos Swift de App y de sus botones, selectores, rutas y llamadas detectadas: `action-inventory.json`. Un inventario estático no equivale a pulsar cada combinación posible ni a medirla. Las rutas diagnósticas/laboratorio se identifican aparte del trabajo clínico cotidiano; se conservan.

## Recorridos y hallazgos

| Módulo | Acciones revisadas | Coste o defecto encontrado | Cambio y control |
|---|---|---|---|
| Inicio, sesión y navegación | Abrir, desbloquear, pestañas, contadores, segundo plano | Dos recuperaciones para revisión y contadores; tareas simultáneas de refresco | Revisión/contadores desde un mismo registro autenticado; refresco excluyente; ocultación clínica y Face ID conservados |
| Atención y alergias | Abrir formulario, seleccionar persona, revisar, guardar, pasar pasos | Auditorías repetidas de exactamente los mismos bytes; carrera con autosave; construir padrón después de una escritura | Prueba inmutable interna tras ambas auditorías; confirmación de persistencia real; actualización COW de una alergia; errores de guardado separados del refresco visual |
| Borradores | Debounce, cambio de paso, cerrar, recuperar, confirmar | Consulta completa de revisión antes de cada escritura; guardados idénticos; cancelación de alergias podía dejar el borrador pendiente | Escritura optimista con un reintento solo ante conflicto real; etapa capturada junto al formulario; no reescribir estado idéntico; reprogramación tras fallo de alergias |
| Personal | DNI, nombre, directorio, alta y ficha laboral | Filtrado con comparación de locale durante cada render/paginación | Índices normalizados en memoria; búsqueda diferida fuera del hilo principal; lista vacía sin consulta; 25 filas por página y cinco sugerencias; DNI exacto por diccionario |
| Historial | Buscar, paginar, detalle, rectificar, volver | Auditorías completas ya disponibles; recorrido de incidencias por cada visita; reconstruir padrón al abrir la edición | Proyección autenticada interna con firmas de rectificación verificadas; incidencias indexadas por visita; edición preparada desde una sola revisión; actualización de una fila de historial conservando consumos físicos |
| Kardex e inventario | Consolidado, 98 productos, filtros, ingresos/conteos, R 1/0, cortes 9–8, movimientos | Validaciones duplicadas en operaciones del diario y sumarios; trabajo de incidencias cuadrático en historial v2 | Pruebas semánticas ligadas a bytes exactos; sumarios reutilizan resultados autenticados; sin cambios al cálculo físico, redondeos, movimientos, cierres ni secuencia de consumos |
| Indicador de diez hojas | Período, ambas sedes, selección, sede pendiente, generar/compartir | Un filtro Fundo aceptaba sede vacía; verificar dos veces la misma cadena; escritura del archivo en MainActor | Sede histórica explícita; nunca copiar automáticamente la ficha laboral; proyección compartida; ruta interna autenticada; archivo protegido escrito por actor separado |
| Excel enfermeras y vigilancia | Rangos, filtros, generar, compartir | Escrituras de XLSX en el hilo de interfaz; coste compartido de la bóveda | Escrituras protegidas fuera de MainActor; fórmulas, 98 productos, saldos desconocidos y formatos conservados; comparaciones oficiales TS/Swift |
| Respaldos, importación y restauración | Autenticar, leer, verificar, cifrar, compartir, restaurar | Lecturas/escrituras grandes en MainActor; validaciones repetidas en fuente ya autenticada | I/O en actor dedicado, acceso security-scoped durante toda la lectura, límite 42 MB, archivos regulares sin symlinks, protección completa y escritura atómica conservados |
| Catálogos, diagnósticos, procedimientos y vencimientos | Elegir, buscar, validar, agregar tratamientos | Riesgo de trabajo dentro de `body`; reglas clínicas y validaciones no deben reducirse | Se conservan los catálogos revisados, búsqueda de productos y alertas clínicas. Los cambios comunes de bóveda no alteran su contabilidad; regresiones funcionales existentes siguen obligatorias |

La importación inicial, la admisión de un respaldo externo y la verificación de una generación distinta continúan realizando auditorías completas. No se sustituyen por una comprobación de tamaño, fecha de archivo o número de revisión.

## Límite de confianza de las optimizaciones

- `N2AuditedSnapshot` es interno e inmutable: construirlo exige las dos auditorías completas. No existe un inicializador que acepte informes arbitrarios.
- El diario lee el archivo y comprueba recibo HMAC, AES-GCM/AAD y SHA en **cada** recuperación. Solo reutiliza auditorías semánticas si los bytes descifrados son exactamente iguales a bytes ya auditados.
- Dos entradas como máximo, de hasta 8 MiB cada una, por diario; ninguna se escribe en texto plano. Las fuentes mayores mantienen el recorrido completo.
- Cada actor mantiene su propia sesión clínica o ficticia, comprueba Keychain en cada llamada y descarta la sesión al bloquearse, ir a segundo plano o fallar Keychain. Un cambio de clave crea otra sesión.
- Las firmas y la secuencia de la cadena de rectificaciones se verifican también en los recorridos autenticados. Una modificación efectiva de datos no recibe automáticamente la prueba de los bytes originales.
- Escrituras y revisiones permanecen serializadas por sus actores; se prueban 16 solicitudes concurrentes con la misma revisión, una aceptada y quince rechazadas como obsoletas.
- No se cambia Bundle ID, grupos compartidos, claves/servicios Keychain, formato del diario, esquema v2 ni codec del respaldo. Solo el número de compilación candidato avanza a 15. No se instala en el iPhone real.

## Mediciones reproducibles

`scripts/performance/run-core.sh` ejecuta un mismo harness sobre el HEAD inicial y el actual. Datos fabricados: 9.648 trabajadores, 1.005 atenciones iniciales, stock/lotes/movimientos originales ficticios y borrador. Compilación SwiftPM Release en Linux x86_64; no son tiempos de iPhone ni de SwiftUI.

Se conservan todas las muestras. Operaciones lentas: siete muestras (o tres en Excel, edición y respaldo), mediana y máximo; no se inventa p95 con tres/siete muestras. Búsquedas: cien muestras y p50/p95. Se declara el ciclo de vida de cada implementación: el adaptador inicial creaba un diario por llamada; el optimizado mantiene el diario autenticado durante la sesión. La preparación inicial en frío no se representa como reapertura caliente.

La tabla final procede del artefacto `B15_PERFORMANCE_COMPARISON/comparison.json`. CPU/memoria de la navegación se miden además con XCTest en Simulator; `profile-simulator.py` intenta registrar Time Profiler y Allocations y guarda el resultado real de cada herramienta. Si no puede capturar una métrica, se informa **No medido**, nunca cero ni aprobado por inferencia. No se afirma una mejora en el iPhone físico sin medirlo.

## Pruebas y compatibilidad

1. Todas las pruebas Swift actuales, sin filtro, y comparaciones Excel oficiales.
2. 50 regresiones JavaScript y 12 controles adicionales.
3. Xcode real sobre el candidato y todas las pruebas nativas, incluyendo concurrencia; Face ID real inscrito en simuladores propios.
4. Todas las suites UI descubiertas, incluyendo guardar alergias/reabrir, búsqueda vacía, paginación y métricas del formulario. Los binarios se comparten solo dentro de la ejecución del **mismo HEAD**, con hashes de cada archivo y permisos preservados en tar. No se reutiliza un binario de otro SHA.
5. Archivos cifrados producidos por el código original Build 14 se abren y editan en el candidato; stock, trabajadores y atenciones originales deben permanecer iguales. Se verifica respaldo Build 14 y nuevo round trip. Es compatibilidad hacia delante; no una promesa de que Build 14 entienda campos nuevos de rectificación de Build 15.
6. Los fallos reales y las cancelaciones anteriores quedan en GitHub y en `previous-linux-failures.json`.

## Pendientes y distribución

No hay IPA de Build 15 autorizada por este documento. La versión instalada Build 14 permanece intacta. Se debe revisar el resultado completo de la ejecución actual, las métricas y cualquier limitación de Instruments antes de evaluar distribución.

La firma iLoader y la conservación del contenedor en una actualización física no pueden certificarse con Simulator. Conservar el respaldo original de Build 14 y la misma identidad de firma; no desinstalar la app que contiene los datos reales. No se ha accedido a datos del iPhone durante estas pruebas.
