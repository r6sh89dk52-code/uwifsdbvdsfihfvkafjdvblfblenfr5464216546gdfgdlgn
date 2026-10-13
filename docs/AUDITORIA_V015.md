# DANPER Salud Móvil v0.15 — auditoría del candidato

Base: `main` v0.14.1, commit `c1554988b07f2b4dc9b891e9f5c72964e8fb6a5a`. Cuenta exclusiva: `fazcaratesilva-web`. Rama independiente: `feature/ambulatory-v015-work-validated`. El PR #11 y el esqueleto provisional se revisaron; su especificación y prueba de catálogo se incorporan a esta implementación.

## Defectos corregidos en el paquete de preparación

1. No contrastaba los encabezados reales. Ahora se verifican los 30 encabezados y los nombres OOXML de tabla, incluidos los saltos `_x000a_`.
2. Dejaba el primer responsable histórico en GUIA T2:U2. Se borran todos los datos del padrón a partir de la fila 2.
3. Copiaba XML auxiliar, nombres definidos, estilos, cachés o extensiones seleccionados sin un límite de confianza completo. Ahora el resultado usa exclusivamente el diseño vacío aprobado, derivado del original privado. Ningún XML del archivo seleccionado se copia al exportado.
4. Aceptaba cualquier catálogo de 432 códigos. Se compara código, nombre y unidad con el catálogo oficial y los hashes de regresión del PR #11.
5. Deducía cantidades solo por un vínculo. Se valida el historial y se reproduce cada salida en un estado temporal, comprobando apertura, R, cantidad y snapshots. La exportación no persiste esa reproducción.
6. No comprobaba cambios clínicos posteriores, equivalencias con el Kardex ni devoluciones/discrepancias. Se bloquean entregas desalineadas, sin equivalencia o con incidencias.
7. Permitía duplicados de artículos y fechas normalizadas incorrectamente, ocultaba fechas inválidas al filtrar y convertía edad vacía en cero. Se corrigen los tres casos y se rechazan horas inválidas.
8. Convertía la sexta atención en QUINTA. Ahora muestra REVISAR y aviso explícito.
9. Devolvía advertencias que bloqueaban tanto errores críticos como avisos. Ahora las entregas incompletas bloquean; los saldos pendientes son visibles y no inventan cifras.
10. No completaba subdivisión ni detalle. Se exige seleccionar la subdivisión, se mantiene área como unidad organizativa y se añaden fórmulas verificadas de códigos y el detalle guardado de procedimientos. Área sin correspondencia deja código vacío, con aviso en la pantalla.
11. Mantenía fórmulas de tabla que sobrescribían nombres, edad, sexo o responsable al recalcular. Se conservan valores actuales en esas columnas y fórmulas compatibles de organización, inventario y resumen.
12. INGRESOS y RESU convertían datos ausentes en ceros o saldos negativos aparentemente reales. Sus totales y saldos permanecen vacíos hasta conciliar; los consumos sí usan SUMIF de entregas del período.
13. No extendía todas las referencias y validaciones más allá de 2792 datos. TB_CONSUMOS, dimensión, validaciones y formato adicional crecen hasta 10000 datos.
14. No protegía ZIP frente a expansión, rutas, duplicados, solapamientos, CRC o entidades XML. Se añaden controles antes y durante la descompresión.
15. El original tiene una caché externa de aproximadamente 19 MB. Se descarta por streaming con CRC, sin retenerla ni parsearla como datos del reporte. Límites: 20 MB comprimidos, 40 MB expandidos, 24 MB por parte, 256 entradas, ratio controlado y rechazo de ZIP64/multipartes.
16. La lectura de Archivos podía terminar fuera de orden o fallar sin captura. Se protege la selección y los errores; se bloquean exportaciones simultáneas.
17. La compilación estricta fallaba por una variable sin usar. TypeScript estricto vuelve a pasar.
18. Se fuerza formato texto para códigos y DNIs, manteniendo fuente, bordes y rellenos, para conservar ceros iniciales también en lectores que aplican formatos numéricos a cadenas.

## Libro de diez hojas

| Hoja | Resultado y procedencia |
|---|---|
| BD MATERIALES | 432 registros exactos, códigos de texto numéricos, tabla A1:C433 |
| CONTEO | 432 materiales, entradas físicas vacías, totales condicionales, pendiente de conciliación |
| INGRESOS | 432 materiales, cuatro espacios de ingreso vacíos, alertas de vencimiento y total compatibles, pendiente de conciliación |
| RESU | 432 materiales, consumos por SUMIF, saldos y requerimientos vacíos mientras falten entradas/recuento |
| CONSUMOS | 30 columnas originales A:AD; una o más filas por atención guardada; cantidades exclusivamente de entregas |
| JUSTIFICACIONES | Encabezados y formatos, sin registros históricos |
| GUIA | Catálogos genéricos y tablas; responsables históricos eliminados |
| @subuo | Catálogo organizacional original, sin información de trabajadores |
| BASE TRU | Encabezados y tabla vacía, sin padrón ni nacimientos |
| @uo | Catálogo organizacional original y fórmula CONCATENATE local, sin vínculos externos |

Se mantienen nombres, orden, colores, anchos, encabezados, tablas y estilos originales compatibles. Se reutilizan los formatos de filas del diseño aprobado. Se eliminan vínculos, propiedades, comentarios, objetos/cachés y extensiones no necesarios para garantizar privacidad. Se retiran validaciones #REF! preexistentes y fórmulas ligadas al padrón histórico. No se afirma fidelidad a objetos externos incompatibles eliminados.

## Pruebas reproducibles

`npm ci`, `npm run test:logic`, `npm run test:ambulatory`, `npm run build`, `npm audit --audit-level=high`, `npm run ios:check`.

Las pruebas nuevas cubren 29 escenarios de filas y 23 de OOXML/privacidad/ZIP, además de la comparación de los 432 materiales. Casos: cero/una/varias atenciones, varios productos, sexta visita, duplicados, códigos excluidos/desconocidos, unidad/nombre incorrectos, R 1/0, modificaciones posteriores, equivalencias, incidencias, fechas/horas, identificación textual, literal de fórmula, exportación repetida sin cambios, 3000 filas, expansión de tablas/validaciones/formatos, XML inválido, DTD, CRC corrupto, límites, rutas y contaminación ficticia en diez hojas/cachés/propiedades.

El control privado adicional usa el archivo original y no participa en CI ni publica ese archivo. La extracción del diseño vacío comprobó 19174 tokens de identidades históricas contra todos los componentes retenidos: cero coincidencias. El informe final de entrega incorpora los resultados concretos de CI y del IPA.

## Limitaciones que requieren verificación externa

- Microsoft Excel real: abrir sin reparación, recalcular, editar tablas e imprimir. Pendiente si no hay acceso al programa.
- SideStore/iPhone: instalación, hoja de compartir, operación sin conexión, memoria/tiempo de 3000 filas, continuidad de Keychain y gestos. Compilar Xcode no sustituye estas pruebas.
- La subdivisión seleccionada se aplica a todas las atenciones del intervalo. No hay sede individual guardada en v0.14.1: el usuario debe escoger un intervalo que corresponda a una sola subdivisión. No se altera el modelo previo para inferirla.
- Los códigos de unidad organizativa provienen del catálogo original; áreas libres sin coincidencia quedan sin código.
- No se rellenan saldos, recuentos ni ingresos desde el Kardex de Enfermería porque ambos catálogos/unidades no son equivalentes automáticamente. Quedan marcados para conciliación explícita.
- El límite existente de 1000 movimientos y 500 lotes permanece. El exportador admite 10000 filas, comprobado con 3000 filas, sin aumentar los límites del inventario validado.
- La app continúa destinada exclusivamente a datos ficticios; se conserva la arquitectura de prueba existente.

## Publicación

No fusionar hasta que pasen las pruebas Linux y la compilación/validación del IPA candidato en macOS. El push posterior a main genera un nuevo IPA v0.15. El verificador inspecciona ejecutable, versión/build, recursos, SHA256 y ausencia de archivos Excel brutos. El estado real de PR/Actions y artefactos se documenta en el informe final; este documento no declara una publicación final anticipada.
