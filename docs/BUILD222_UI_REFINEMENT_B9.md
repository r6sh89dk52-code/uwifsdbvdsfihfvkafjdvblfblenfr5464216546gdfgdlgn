# Revisión de interfaz B9 — referencia build 222

Referencia congelada: `09fef294d73f6a1c655dc42865b6fa5c5e1f792a`. Se leyeron `src/main.tsx`, `attentionStepper.css`, `visualRefresh.css` y `cohesiveExperience.css`. Evidencia de problemas: doce capturas físicas IMG_2815–IMG_2826.

| Problema observado | Cambio nativo | Referencia 222 |
|---|---|---|
| Catálogo completo rojo | Texto neutro, código secundario, agregar con icono y selección visible | results/product search |
| Un producto cierra el buscador | Agregar varias líneas y continuar con contador | selección de productos integrada |
| Valores truncados en menús | Campos verticales completos, selector con búsqueda y marca | campos de 48px, 13px radio |
| Lista de formulario uniforme | Paneles separados con títulos, contornos suaves y campos propios | panel, ui-surface, ui-line |
| Todo producto expandido | Resumen y detalle desplegable por producto | itemSummary / expandedProductId |
| Interruptores para seleccionar atenciones | Tarjetas con check y área completa pulsable | selección explícita |
| Revisión poco informativa | Diagnóstico, cada producto/cantidad/procedimiento, editar evaluación y situación final | clinicalReview / attention-result |
| Fin sin jerarquía | Confirmación, resumen clínico, estado físico por línea, nueva atención e historial de la bóveda | persist saved / historyActions |
| Pie ocupa demasiado espacio | Guardar borrador en barra superior, CTA persistente | registerDock compacto |
| Fecha duplicada/localizada | Campo único dd/MM/yyyy con calendario en hoja | estándar fecha pedido |

No cambia motor clínico, 86 equivalencias, FEFO, persistencia, cifrado, apertura ni generador Excel. Los cambios de selección escriben los mismos estados. El guardado conserva la validación original y la transacción atómica.

Verificación: capturas UIKit/SwiftUI en simulador claro/oscuro y accesibilidad; suite Linux, oráculo 3094 casos, Excel y compilación iPhone en Actions. El artefacto y resultado definitivo se enlazarán en PR #3. La captura demuestra composición, no pulsaciones físicas ni Face ID. Revisar en iPhone teclado, selección de varios productos, despliegue, guardar y navegación al historial.

La revisión incluye pasos navegables con validación de las etapas intermedias, retorno al inicio al avanzar, corrección guiada del primer campo pendiente y recuperación del estado de alergias ya revisado al cambiar de trabajador. El historial enlazado tras guardar usa la bóveda activa, nunca la muestra estática.
