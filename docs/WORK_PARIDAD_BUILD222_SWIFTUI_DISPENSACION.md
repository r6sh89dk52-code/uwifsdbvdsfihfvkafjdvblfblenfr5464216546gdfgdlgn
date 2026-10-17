# DANPER SALUD MÓVIL — WORK: PARIDAD REAL BUILD 222, REDISEÑO SWIFTUI Y DISPENSACIÓN INTELIGENTE

## MANDATO
Implementar código, pruebas, auditorías, capturas de simulador si son viables y IPA de evaluación. NO limitarse a elaborar un plan o cambiar colores. Trabajar exclusivamente en el repositorio privado r6sh89dk52-code/danper-salud-movil-pruebas mediante la cuenta r6sh89dk52-code. Leer primero este documento y verificar HEAD de las ramas; las referencias que siguen son puntos de partida, no permiso para sobrescribir trabajo posterior.

Referencias:
- Baseline funcional/visual híbrido: release/v0.21.12-build222-provisional-consumptions, SHA 09fef294d73f6a1c655dc42865b6fa5c5e1f792a.
- SwiftUI nativo evaluado: fix/n2-trial-onboarding-faceid-ui-20261017, PR #2 sobre native/swiftui-n1s-complete-excel-and-container-gate, último HEAD conocido 4872fd03f50351d8d467869975624880daa58458; IPA 0.3.0/build 5.
- Continuar desde el HEAD ACTUAL verificado de la rama nativa; crear rama de función propia y PR aislado. No modificar main, release build222 ni paquetes existentes, ni fusionar sin autorización.
- Los adjuntos de capturas de build222/nativa son referencias de diseño. No asumir que una captura prueba una funcionalidad.

## RESULTADO EXIGIDO
La nueva app ha de ser 100% SwiftUI nativa, con lógica clínica y de consumo al menos a la par de build222 y presentación superior: panel inicial con métricas reales, atención guiada, controles claros, alta de trabajador diseñada, dispensa dentro de la atención con catálogo completo y propuestas contextualizadas, FEFO y Excel correcto. La funcionalidad se considera PARIDAD solo cuando supera pruebas de equivalencia contra build222 y la experiencia resulta demostrable en simulador/iPhone. No simular comportamientos con tarjetas estáticas ni presentar una búsqueda oculta como una dispensa terminada.

## FASE 0 — AUDITORÍA OBLIGATORIA Y MATRIZ DE BRECHAS
1. Examinar la rama build222 COMPLETA y sus pruebas, especialmente:
   - src/automaticClinicalDispensing.ts
   - src/procedureRules.ts
   - src/AttentionDeliveryPanel.tsx
   - src/attentionStepValidation.ts
   - src/ClinicalStockChoice.tsx
   - src/attentionKardex.ts, src/kardexMovements.ts, src/inventoryRules.ts
   - catálogos, equivalencias aprobadas, formulario de atención, alta de trabajador, Home/dashboard y hojas de estilo de src.
2. Examinar en SwiftUI:
   - native-ios/App/N2NativeClinicalFormView.swift
   - native-ios/App/N2NativeWorkerEditorView.swift
   - native-ios/App/NativeRootView.swift, DanperUITheme.swift
   - native-ios/Sources/DanperCore/N2NativeFormContext.swift
   - N2NativeCatalogIndex.swift, N2ClinicalTransactions.swift
   - N2ProtectedClinicalIOSVault.swift, N2AtomicClinicalCoordinator.swift
   - N2VerifiedIndicatorWorkbook.swift, N1sFullExcelWriter.swift, N1sNursingExcelWriter.swift
   - Tests Swift, workflows iOS/macOS/Linux.
3. Generar docs/BUILD222_NATIVA_PARITY_MATRIX.md con equivalencias verificadas, diferencias, código y tests, sin detener ejecución. Priorizar brechas funcionales sobre adornos.
4. Hallazgo confirmado en revisión: N2NativeClinicalFormView.swift contiene chooseProduct y medicationFields, pero el buscador queda enterrado después de un bloque de procedimientos; N2FormMedication nace con procedure="OBSERVACION", sin inferencia de presentación. Esta implementación NO constituye paridad de UX ni de reglas con build222. Corregir esto de raíz.

## FASE 1 — SISTEMA VISUAL ÚNICO DANPER
- SwiftUI nativo (sin WKWebView de sustitución), código reutilizable, sin duplicar estilos pantalla a pantalla.
- Rojo DANPER predominante, tipografía iOS legible en Dynamic Type, superficies con contraste, jerarquía de CTA, iconos SF Symbols correctos, esquinas/sombras/gradientes discretos, modos claro y oscuro.
- Microanimaciones fluidas de aproximadamente 150–250 ms, transiciones entre pasos/tabs, pressed states, guardado, errores y éxito, haptics configurables, con Reduce Motion y VoiceOver respetados.
- Safe Area, Dynamic Island, teclado y scroll: botones primarios accesibles sin solaparse con teclado o TabBar; navegación Back totalmente en español; nada cortado en teléfonos compactos o texto ampliado.
- Pantalla de bienvenida/acceso rediseñada con logo real, composición visual atractiva y poco texto técnico. Solicitar Face ID automáticamente al abrir y al regresar de segundo plano, solo UNA vez por ciclo; mostrar «Reintentar con Face ID o código» después de cancelación/fallo, sin bucles ni pérdida de datos. Proteger app al cambiar a background.
- No mostrar «N2», «bóveda», revisiones internas o nombres de pruebas como título de pantallas operativas. Mantener identificación visible pero discreta de «Modo de prueba — datos ficticios».
- Inicio: hero «Nueva atención», contadores calculados desde registros confirmados (Hoy, Esta semana de lunes a domingo, Borradores), accesos a Personal/Historial/Inventario/Kardex/Excel, estados vacíos útiles. Zona horaria America/Lima; no contar filas de consumos como atenciones ni un borrador como guardado.
- Consistencia visual en Inicio, Personal, Atención, Borradores, Más/Ajustes, Inventario, Kardex, Exportación, Historial, restauración y nuevo trabajador.
- Formularios por pasos y validaciones: feedback animado, accesible y específico, como la UX build222 o mejor. Validar al avanzar; mostrar qué falta, enfocar primer error sin perder texto, no bloquear sin explicación.
- Nuevo trabajador: secciones identificación, persona, laboral y opcionales. Búsqueda o ingreso de DNI, datos simulados en beta, verificación duplicados, sede/área/cargo guiados, estado de alergias cerca de la identificación clínica, botón guardar persistente. No forzar información que no sea realmente obligatoria.

## FASE 2 — ATENCIÓN CLÍNICA CON DISPENSACIÓN VISIBLE E INTEGRADA
- Etapas recomendadas: 1 Trabajador/alergias; 2 Evaluación; 3 Tratamiento, medicamentos y consumo; 4 Confirmar. Si se mejora la secuencia respecto a 222, documentar diferencias sin omitir funciones.
- En PASO 3 poner una TARJETA PRINCIPAL «Medicamentos e insumos» al comienzo, con CTA «+ Agregar medicamento o insumo» grande, visible sin desplazarse al fondo de procedimientos. Búsqueda instantánea por nombre/código sobre catálogo N2 de 432 productos clínicos, resultados fluidos, unidad de medida, código y accesibilidad. Permitir múltiples líneas; editar/cancelar cantidades y descartar entradas accidentales.
- Tras elegir un artículo, mostrar tarjeta de consumo editable con nombre, código, unidad, cantidad clínica, procedimiento sugerido/confirmado, procedencia de la sugerencia, lote FEFO y existencia si verificable, apertura cuando aplique, estado físico («Descontado», «Pendiente de conciliar», «No descontado»). El guardado de atención jamás debe ocultar consumos clínicos pendientes.
- Guardado de atención y descuentos verificables debe ser transaccional y cifrado. El módulo separado de conciliación es solo para entradas históricas pendientes, NO condición obligatoria para los nuevos consumos válidos.
- Tener procedimientos sin medicamentos también es válido; un procedimiento no puede inventar consumo físico.

## FASE 3 — «INTELIGENCIA» DETERMINISTA AUDITABLE DE PROCEDIMIENTOS
Portar y ampliar fielmente src/procedureRules.ts en Swift puro con reglas + tests de paridad. NO usar un LLM para elegir vía clínica, diagnosticar, recetar ni establecer dosis. No inventar asociaciones, posologías ni stock.

Sugerencias contextuales verificables:
- Presentación claramente oral (tableta, cápsula, comprimido, pastilla, etc.) => sugerir TRATAMIENTO ORAL.
- Ampolla/forma claramente inyectable => sugerir INYECTABLE.
- Cremas, ungüentos, pomadas => sugerir APLICACIÓN DE CREMA; colirios/gotas oftálmicas => aplicación ocular si el catálogo y los procedimientos oficiales la reconocen.
- JERINGA o AGUJA genérica no prueba por sí sola que se inyectó medicamento; sugerir INYECTABLE si ya existe un contexto confirmado y pertinente. Si no, exigir elección.
- GASA, ALGODÓN, APÓSITO, CURITA, ALCOHOL, GUANTES, VENDAS pueden corresponder a curación, inyectable, sutura u otro procedimiento. Sugerir CURACIÓN DE HERIDA únicamente cuando el contexto/documentación lo respalda de forma única; en casos ambiguos solicitar confirmación en interfaz. No afirmar automáticamente «curación» por encontrar una gasa.
- Si hay dos procedimientos plausibles, presentar selector contextual. Si la sugerencia no tiene seguridad suficiente, marcar «Por definir» hasta elección. Nunca inicializar automáticamente toda línea con OBSERVACION sin revisión.
- Conservar corrección manual, preferencia confirmada y trazabilidad; al agregar o quitar productos recalcular sugerencias NO confirmadas, pero no sobreescribir selecciones del usuario.
- El procedimiento de cada producto debe alimentar TIPO DE ATENCIÓN (T) y DETALLE (U) según reglas oficiales; cuando haya varios, solicitar decisión, no elegir arbitrariamente el último.
- ENVÍO DE FOTO (AA)=NO en atenciones sin lesión/curación; con lesión/curación preguntar SI/NO, no tomar ni guardar fotos.
- Mostrar al usuario «Sugerido por presentación» o «Sugerido por contexto», con opción de cambiar; distinguir elección registrada de acto clínico efectivamente realizado.
- Añadir test suite con productos representativos, mayúsculas/tildes, especialidades ambiguas (agujas dentales/suturas), 2 contextos, override manual, reversión de cambios y sin procedimiento predeterminado falso.

## FASE 4 — STOCK CLÍNICO, KARDEX, FEFO Y ENVASES
- Reutilizar/validar N2ClinicalTransactions y N2AtomicClinicalCoordinator contra build222, sin simplificar validaciones.
- Catálogos EXACTOS: 432 productos clínicos, 98 de enfermería (excluir 6 donados), 86 equivalencias aprobadas, E-62/E-63 mismo código clínico 16024400 pero dos existencias físicas diferenciadas; E-68 y no mapeados NO descuentan sin equivalencia aprobada.
- Para artículos de unidad individual (UND/TBL/PAR cuando la equivalencia es exacta), una selección clínica y una cantidad verificable puede disparar descuento automático FEFO al confirmar atención; cantidad de insumos/stock físicos distinta de cantidad clínica cuando las unidades lo requieran.
- Lotes: fechas de vencimiento, exclusión de vencidos, prioridad FEFO, reparto multilote, cero negativos, validación de capacidad de envases, imposibilidad de descontar si origen/stock ambiguo.
- FCO/CAJA/PAQ: diferenciar unidades internas vs envase externo. Ejemplo ilustrativo de inventario ya aprobado: primer uso que ABRE envase => consumo de envase R=1; usos siguientes del mismo envase abierto => R=0, hasta agotarlo; al abrir uno nuevo confirmar explícitamente y contabilizar nuevo R=1. Nunca inferir capacidad a partir del nombre o de un ejemplo como 100 mL; usar datos de capacidad verificados.
- Un solo registro clínico por medicamento/insumo, aunque FEFO genere múltiples salidas auditadas. Idempotencia por atención + línea, sin doble descuento tras reintento, borrador, corrección o reapertura.
- Consumo clínico guardado incluso si no puede verificarse equivalencia/lote/unidades; estado «Pendiente», razón visible, sin inventar movimiento cero ni aceptar una entrega física falsa.
- Separación de stocks por sede y flujo Kardex diario; F=falta y S=sobra conforme formato existente. Cierre mensual/corte 9→9. No degradar conteo, apertura, ingreso extraordinario, stock sellado/abierto, reconciliación y exportación.
- Reconciliación de históricos sin modificaciones retroactivas destructivas; audit trail y confirmaciones.

## FASE 5 — DATOS, FECHAS, RESPALDOS Y EXCEL
- Mantener estructuras cifradas, Keychain, separación del paquete de pruebas y build222, recuperación, revisiones y autosave.
- Fechas mostradas EN TODA LA APP: dd/MM/yyyy; con hora dd/MM/yyyy HH:mm. Esquema persistido ISO se mantiene cuando se necesita por integridad, FEFO e índices.
- Excel exportado: conservar diez hojas, fórmulas, referencias, formatos oficiales, tablas y estructura original. Fechas como valores numéricos reales con estilo dd/mm/yyyy (no texto de fecha en columnas tipadas). Revisar Kardex, CONSUMOS, INGRESOS, vencimientos, historial, vistas previas y portadas.
- A–AD de CONSUMOS exactas; S frecuencia (primera...quinta) por atención clínica del mismo trabajador y día, no por fila de insumos; T/U como arriba; AA como arriba. Registro del responsable correcto.
- Exportar solo atenciones nuevas/seleccionadas según reglas, no mezclar históricos del origen; libros 10 hojas verificables, share sheet iOS, sin solicitar al usuario una plantilla que el proyecto ya integra.
- No reemplazar valores existentes con placeholders ni crear historiales ficticios en modo operativo.

## FASE 6 — VERIFICACIÓN OBLIGATORIA SIN ATAJOS
Crear/actualizar pruebas Swift XCTest y pruebas JS de paridad, con casos:
1. Inicio: contadores de hoy, semana America/Lima lunes–domingo, borradores, atención múltiple con insumos: NO contar productos como atenciones.
2. Alta trabajador: validación, DNI duplicado, datos opcionales, persistencia sin afectar registros ajenos.
3. Medicamentos: buscar por código/nombre, elegir tabletas, ampolla, jeringa contextual, gasas ambiguas, editado manual, línea múltiple, borrar línea, autosave y restauración.
4. Dispensación: unidad individual, frasco abierto (R=0 reutilización), abrir caja/frasco nuevo con consentimiento (R=1), FEFO multilote, vencidos, saldo insuficiente, correspondencia ambigua, duplicidad de transacción, histórico, dos sedes, envase sin capacidad, pendiente físico con consumo clínico conservado.
5. Excel: regresión de 10 hojas y 98 materiales, fórmulas, formato de fechas real, A–AD, frecuencia, T/U, AA, diferencias F/S, 9→9.
6. SwiftUI: simulador oscuro/claro, teclado y safe area, accesibilidad, navegación, alertas de validación, Face ID auto + cancelación/reintento; donde simulador no demuestre SideStore/Face ID real, reportar límite.
7. Seguridad: no utilizar datos reales, sin borrar claves ni resetear bóvedas; comprobar misma app ID de laboratorio aislada; no sobrescribir build222.
8. Inspeccionar los resultados de CI en GitHub: Linux, compilación Xcode iPhone/simulador y pruebas de integración; reparar fallos antes de entregar. No declarar PASS si no se ejecutó.
9. Si hay herramientas, obtener capturas del simulador de Home, Paso 3 con medicamentos, modal de validación, trabajador, login; comparar con capturas build222. Documentar en PR mejoras y posibles diferencias.

## ENTREGA Y ACEPTACIÓN
- Trabajo efectivo en GitHub: commits, nueva rama y PR con tabla de paridad por función y archivo, tests verificables, lista de puntos que no pudieron probarse.
- Si TODO CI crítico es PASS, compilar NUEVA beta iPhone aislada (siguiente build numerada; nunca reutilizar build5), IPA sin firmar publicada en Actions con SHA-256 y vencimiento, lista para firmarse por SideStore.
- No fusionar a main, no sobrescribir ni eliminar IPA/copia existente, no migrar datos reales ni señalar la beta como producción.
- Prioridad de ejecución: 1) catálogo visible + inteligencia determinista + dispensación e inventario, 2) rediseño Home/Atención/Nuevo trabajador/acceso y animaciones, 3) unificación restante + Excel + pruebas y entrega. Implementar todo el alcance, no dejar el módulo de medicamentos fuera porque el diseño se vea agradable.
- Si una funcionalidad no puede alcanzar paridad por falta de regla/dato, registrar brecha exacta y dejarla segura y pendiente, nunca inventar comportamiento o marcarla terminada.
- Reportar al final: commit SHA, PR, runs Xcode/Linux, artefacto IPA confirmado, capturas de prueba si existen, tabla de funcionalidades de build222 vs nativa y limitaciones para la prueba en iPhone real.
