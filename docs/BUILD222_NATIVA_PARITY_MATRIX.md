# Build222 → SwiftUI: matriz de paridad verificable

Referencia funcional congelada: `release/v0.21.12-build222-provisional-consumptions`, `09fef294d73f6a1c655dc42865b6fa5c5e1f792a`. Base nativa verificada: `dd39d78b02da2c991e8d28aa0218c5bffc12d967`. Rama de trabajo: `feat/build222-native-parity-20261017`. PR #3; sin fusión ni escrituras sobre main/release. Las pruebas procesan únicamente personas y existencias ficticias.

## Hallazgos y cambios

El formulario nativo declaraba `medicationFields`, pero nunca lo renderizaba: no era solo un buscador poco visible. El paso 3 ahora lo incluye, antes del selector de procedimientos, con CTA principal y las 432 referencias sin truncar resultados. Se elimina OBSERVACION como valor inicial de productos y procedimientos nuevos. Los registros previos conservan sus elecciones.

| Función build222 | Implementación SwiftUI | Evidencia y alcance |
|---|---|---|
| Buscar 432 productos por nombre/código | `N2NativeCatalogIndex`, `N2NativeClinicalFormView` | Suite de catálogo exacto 432/98/86; búsqueda visible en paso 3; captura de maquetación no sustituye interacción física |
| Varias líneas, cantidades, borrar, procedimiento individual | `medicationFields` conectado al formulario | Cantidad clínica separada de cantidad interna; validación positiva; borrador conserva líneas y selecciones |
| Oral, ampolla, crema, oftálmico | `N2ProcedureRules` | 3094 casos contra copia congelada de `procedureRules.ts`: 432 productos + 10 ejemplos × 7 contextos |
| Jeringas/agujas contextuales y gasas ambiguas | `N2ProcedureRules.infer` | Sin contexto: por definir; gasa con dos procedimientos: por definir; agujas especiales no inventan inyección |
| Corrección manual persistente | `procedureConfirmed`, `procedureSource`; `N2NativeDraftRecovery` | Override no se recalcula; quitar el producto que sustentaba un contexto invalida sugerencias no confirmadas; recuperación conserva procedencia |
| Validación por pasos y formulario adaptativo | `N1hClinicalValidator` conectado al editor nativo; `N2ClinicalFormOptions` | Catálogos oficiales, alergias, fecha/hora, segmento osteomuscular; sistema obligatorio solo donde corresponde; diagnóstico libre con autocompletado existente |
| Procedimientos sin medicamentos | `N2NativeFormDraft.makeSavedVisit` | Prueba: atención sin producto no crea movimiento físico |
| T/U oficiales | Procedimiento elegido por línea; detalle INSUMOS según reglas oficiales | Escritores A–AD conservados y comparados con TypeScript; ninguna selección arbitraria entre alternativas |
| AA, envío de foto | Sin herida/curación: NO; con procedimiento de herida/sutura: pregunta SI/NO obligatoria | Solo se guarda la respuesta; no cámara ni imágenes clínicas |
| 86 equivalencias, E-62/E-63 diferenciados, E-68 excluido | `N2NativeCatalogLoader`, `N2NativeClinicalTransaction` | Mapeos exactos verificados; doble presentación exige selección; sin mapeo queda pendiente |
| FEFO, multilote, cero negativos | Motor transaccional existente preservado | Caducados excluidos; plan completo antes de escribir; saldo insuficiente no causa salida parcial |
| Envases, remanentes y consentimiento | `physicalUse`, cantidad interna, capacidad y `approveOpening` | Reutilización R=0; nueva apertura R=1 con autorización; también se ofrece autorización cuando queda remanente que puede agotarse |
| Descuento al guardar; idempotencia y cifrado | `N2AtomicClinicalCoordinator`, journal cifrado | Pruebas de interrupciones, reintento exacto y rechazo de modificación de entrega confirmada |
| Consumo clínico pendiente visible | `nativeDispensing` por línea, pantalla final e historial | Razón persistida sin modificar cantidades; registros históricos sin salida no se presentan como cero |
| Dos sedes, sin mezclar existencias | `dispensingSite`, lotes con `site`, Kardex diario filtrado por sede | Nuevas atenciones usan sede explícita; los lotes antiguos sin sede no se reasignan; quedan fuera del descuento nuevo. Las APIs de lectura histórica conservan compatibilidad cuando no se solicita ámbito |
| Inicio con métricas reales | `N2DashboardMetrics`, `NativeRootView` | Hoy, lunes–domingo America/Lima y borradores; no cuenta productos como atenciones; refresca al volver a Inicio/primer plano |
| Nuevo trabajador | Identificación, laboral, opcionales, sede guiada y guardar persistente | DNI repetido visible; validación transaccional existente; esta beta sigue exigiendo identidades ficticias |
| Borradores | Tab dedicada, autosave 650 ms, recuperación y eliminación confirmada | Motor cifrado y revisiones preservados; no redispensa al abrir |
| Acceso automático Face ID/código | `DANPERNativeApp` | Un intento por ciclo; cancelación ofrece reintento; al fondo invalida el contexto y descarta callbacks antiguos. Requiere prueba física |
| Identidad, accesibilidad y hápticos | Estilos compartidos, claro/oscuro, Dynamic Type, Reduce Motion, preferencia háptica | Xcode y adjuntos de maquetación; VoiceOver, teclado y tacto real requieren revisión en iPhone |
| Excel completo y fechas | `N1sFullExcelWriter`, `N2VerifiedIndicatorWorkbook`, Kardex nativo | Diez hojas, 19 tablas, fórmulas y 432 materiales; fechas numéricas con `dd/mm/yyyy`; 98 filas de enfermería |
| Provisional con consumos pendientes | Opción explícita + confirmación; mismo libro completo | R declarado identificado como provisional; advertencia y líneas pendientes en JUSTIFICACIONES; no crea movimientos ni cierre oficial |
| Frecuencia por atención | Conteo global de guardadas por DNI/día antes de filtrar selección | Exportar solo la segunda atención conserva SEGUNDA; consumos múltiples no incrementan frecuencia |
| Cortes, F/S, ingresos, conteo y 9→9 | Reconciliación y escritores existentes preservados | Suites de regresión de cierres, recibos, fórmulas y falta/sobra; no se reconstruyen históricos destructivamente |
| Compartir archivo | `UIActivityViewController` nativo, plantilla incluida | Construcción Xcode; destino Files/Mail/WhatsApp y SideStore se validan en iPhone |

## Verificación y límites de aceptación

La compilación no acredita administración clínica ni una experiencia superior por sí sola. El flujo de CI exige Linux (XCTest y comparación de Excel) y Xcode (simulador, iPhone y XCTest) antes de empaquetar la beta. Los resultados exactos se enlazan en el PR. La beta usa el identificador existente de laboratorio `pe.danper.saludmovil.native.preview`; no toca el identificador de build222 ni borra claves o archivos.

Las capturas son vistas SwiftUI alojadas en UIKit dentro del simulador con datos ficticios. No acreditan pulsaciones de usuario, funcionamiento real de Face ID ni activación Keychain. La captura debe contener píxeles variados: un PNG vacío no se acepta como evidencia. Los inicializadores de maquetación son DEBUG y no activan almacenamiento ni saltan autenticación en la IPA Release.

El simulador sin firma puede devolver `errSecMissingEntitlement (-34018)`; el test de activación lo informa como SKIP, nunca PASS. No se cambia la política de Keychain para ocultarlo. Antes de uso operativo se requiere instalar con SideStore y comprobar: activación inicial y conservación tras relanzar; Face ID automático/cancelación/fondo; seleccionar varios productos y su persistencia; remanente/apertura con autorización; teclado en pantalla compacta y texto ampliado; compartir ambos Excel; restaurar respaldo con contraseña.

Los lotes existentes sin sede carecen de evidencia para adjudicarlos a un tópico: se conservan y no se descuentan en nuevos registros con ámbito explícito. No hay migración automática de datos reales. El ejemplo empaquetado añade dos existencias **ficticias** claramente identificadas para probar sedes distintas, sin relabelar existencias históricas; instalaciones de prueba previas no se resetean ni reciben inventario inventado.

La aprobación visual final corresponde a la comparación de capturas y la prueba del usuario. No se declara terminada una auditoría de todas las interacciones de accesibilidad ni que la beta sea apta para producción.
