# REQUISITO DEFINITIVO: exportación del Indicador Ambulatorio completo (10 hojas)

**Decisión del usuario, 13 de octubre de 2026.** La única plantilla oficial de referencia para la exportación del Indicador Ambulatorio de DANPER Salud Móvil es **`01 INDICADOR AMBULATORIO -KARDEX 2026(2).xlsx`**, el libro de **10 hojas**. Descartar como referencia de esta funcionalidad el libro `REAL INDICADOR AMBULATORIO -KARDEX (MEJORADO) (version 1).xlsx` (15 hojas). No mezclar estructuras.

## Hojas obligatorias y orden original

1. `BD MATERIALES`
2. `CONTEO`
3. `INGRESOS`
4. `RESU`
5. `CONSUMOS`
6. `JUSTIFICACIONES`
7. `GUIA`
8. `@subuo`
9. `BASE TRU`
10. `@uo`

La exportación predeterminada debe preservar **las diez hojas originales** y sus estilos, fórmulas, tablas estructuradas y referencias compatibles. **Solo CONSUMOS** es una alternativa cuando no se pueda garantizar la integridad del libro completo; nunca cambiar silenciosamente al otro modelo de 15 hojas.

## Fuente única de códigos, nombres y unidades

En el Excel de diez hojas, `BD MATERIALES!A1:C438` incluye encabezados (A1:C1) y 437 filas de materiales (A2:C438):
- **432 registros tienen códigos formados exclusivamente por dígitos** y son los únicos permitidos en el catálogo operativo, selector de atención y exportación.
- **5 registros tienen códigos con letras, agregados manualmente por el usuario porque carecían de código oficial; NO importarlos, sugerirlos, asignarles códigos inventados ni exportarlos como artículos autorizados.** Son:
  - `o1000243` — OXIGENO MEDICINAL (RECARGA)
  - `o2001232` — PIZARRA DE CORCHO
  - `o2002298` — SELLO JEBE BASE MADERA RECTANG
  - `o2002299` — SELLO JEBE BASE MADERA CIRCULAR
  - `O2001117` — PAPEL BOND 75 GR A-3
- **Regla:** `^\\d+$` sobre el **código original como texto**, sin convertir letras a números ni eliminar ceros iniciales.
- En `main` a 2026-10-13, `src/products.json` **ya contiene exactamente los 432 materiales permitidos y ninguno de los cinco excluidos. No reemplazar innecesariamente este catálogo.**
- Comprobación comparativa fuente XLSX ↔ JSON: 432 códigos únicos numéricos; los 432 pares código/nombre/unidad coinciden tras eliminar espacios extremos. Hash FNV-1a/32 de filas ordenadas por código `codigo|nombre.trim()|unidad.trim()` separadas por LF: `d6cdf096`. Hash de códigos: `f6d63606`.
- No confundir con `src/kardexCatalog.ts`: los 98 productos del Kardex de Enfermería y 6 donados pertenecen a **otro informe**. Mantener ambos catálogos separados y conciliar por equivalencias verificadas, nunca por semejanza de nombre.

## Exportación diaria/semanal del libro de diez hojas

1. Por defecto, botón **Exportar libro completo (10 hojas)**. Permitirse elegir intervalo: por defecto semana corriente. El archivo resulta de una **copia trabajada y sanitizada del Excel de diez hojas**, no un libro nuevo con nombres aproximados.
2. `CONSUMOS`: plantilla tiene `A1:AD2793` y tabla `TB_CONSUMOS` (original `A1:AD2793`). Rellenar atenciones del intervalo escogido; una atención con varios insumos puede representar varias filas. Expandir tabla/fórmulas cuando haya más datos; no truncar.
3. Emplear códigos originales exclusivamente numéricos, descripción y unidad tomados de `BD MATERIALES` o referencia verificada. Si alguna atención usa código no numérico o sin correspondencia, **detener la exportación de esa fila con aviso explícito**; no inventar código ni asignar sustitutos.
4. `CONSUMOS` columna R (cantidad): si corresponde a apertura de envase confirmado, 1 al abrir y 0 en los usos posteriores; productos individuales según cantidad efectivamente entregada; no tomar cantidad por parecido de nombre.
5. `CONTEO`, `INGRESOS`, `RESU`: actualizar/calcualr los campos derivados únicamente de los registros autorizados del período y los movimientos conciliados; donde falte recuento físico o información de ingreso, dejar pendiente y mostrar advertencia. Preservar fórmulas funcionales y forzar su recálculo al abrir.
6. `BD MATERIALES` exportada: excluir los cinco registros de código alfanumérico del catálogo operativo, redimensionando tabla/referencias de forma segura; conservar los 432 numéricos en código, nombre y unidad.
7. `JUSTIFICACIONES`, `GUIA`, `@subuo`, `BASE TRU`, `@uo`: conservar estructura y catálogos/validaciones necesarios; eliminar datos personales/históricos ajenos al período o no autorizados. La plantilla original **no debe empaquetarse íntegra con datos de terceros en el IPA ni subirse sin sanitizar al repositorio**.
8. Los valores antiguos, datos personales y hojas auxiliares del Excel fuente deben verificarse en **todo el ZIP OOXML**: hojas visibles/ocultas, tablas y cadenas compartidas y propiedades. No asumir que limpiar `CONSUMOS` limpia todas las referencias.
9. El libro de **Kardex diario de Enfermería** (98+6) continúa siendo una exportación independiente del Indicador Ambulatorio (432 materiales numéricos).
10. Exportar localmente en iPhone con hoja de compartir nativa de iOS, sin subir atenciones a servidores. Una exportación repetida no modifica ni descuenta nuevamente el stock.

## Verificación automatizada antes de generar IPA
- Assert exactamente **10 hojas** en el orden descrito y `BD MATERIALES` con **432 códigos numéricos**, cero códigos con letras.
- Comparar los 432 códigos, nombres y unidades con la fuente (tras normalizar espacios extremos) y bloquear duplicados.
- Confirmar tabla `TB_CONSUMOS`, referencias de fórmulas correctas, ausencia de vínculos rotos y de datos anteriores en todo el ZIP.
- Casos de cero atenciones, múltiples materiales en una atención, exceder límite original de tabla, reiteración de exportación, y selección de fecha/semana.
- Validar `CONSUMOS` R=1/0 y los códigos de cada línea; nunca exportar medicamentos manuales con letras.
- Abrir archivo final en Microsoft Excel (sin mensaje de reparación) y comprobar compartir con Archivos/Correo/WhatsApp en iPhone.

## Estado de implementación
**Este documento define la fuente y los criterios de aceptación. La exportación del libro ambulatorio completo no debe anunciarse como terminada hasta pasar estas pruebas.** Integrar esta especificación con la implementación, evitando compilar iOS solo para modificar documentación.

