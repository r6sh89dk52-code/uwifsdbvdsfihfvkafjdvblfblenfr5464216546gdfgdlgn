# B10 — menús, autocompletado y dispensación al confirmar

Referencias físicas revisadas: IMG_2848/2849 (menú anclado), IMG_2850 (búsqueda inline), IMG_2851 (hoja de selección a sustituir), IMG_2852 (sin stock con sede), IMG_2853/2854 (acceso 222 vs nativo).

- `DanperChoiceField` usa menú de sistema anclado al campo, con marca de selección; deja de abrir una hoja con buscador. Se aplica a toda la UI activa que lo utiliza.
- `DanperInlineSearch` busca dentro del tratamiento, inventario y conciliación. Catálogos completos; sugerencias por nombre/código, teclado y selección múltiple de líneas clínicas.
- Pantalla de acceso: rojo DANPER, bienvenida y panel inferior redondeado. Autenticación automática, código y cancelación permanecen en el ciclo original.
- Inventario: panel inicial con acciones y lotes; alta/ingreso/conteo en una vista de operación; menús completos, campos con etiquetas y vencimiento único. Conciliación, respaldo y corrección adoptan paneles. Menú Más usa tarjetas con destino visible.

## Significado del reloj anterior

La captura 2852 dice explícitamente que no hay stock vigente con sede verificada. La atención clínica estaba guardada, pero el motor no podía acreditar una salida. No era una cola de trabajos ni una confirmación manual pendiente para unidades con existencias válidas.

Ahora se ejecuta una previsualización pura del MISMO motor antes de guardar. Los resultados muestran qué se descontará automáticamente y por qué otra línea no puede hacerlo. El guardado original sigue siendo una sola transacción cifrada de atención y movimientos. Los casos excepcionales se identifican como guardar con pendientes; el resultado usa advertencia explícita, sin reloj. No se inventa stock, no se cambian las 86 equivalencias y no se reconstruyen automáticamente consumos históricos.

Los lotes antiguos sin sede pueden recibir una verificación explícita de su ubicación original, con responsable, motivo y evento idempotente. La evidencia queda separada del lote original para conservar intacta la cadena canónica antes/después. Esta acción no traslada lotes con sede conocida ni cambia cantidades, vencimientos, lotes o movimientos; la sede verificada también delimita el historial del lote. Nunca se asigna por inferencia a partir del trabajador.

## Verificación

Pruebas nuevas: preservación exacta de cantidades/atenciones/movimientos al verificar sede, rechazo de traslado implícito y de IDs reutilizados con contenido distinto; descuento automático habilitado solo tras verificación; previsualización sin escritura que coincide con la transacción real e impide doble consumo.

XCTest de interfaz pulsa los menús y selecciona enfermedad, sistema osteomuscular y permiso; escribe Paracetamol/Diclofenaco en el autocompletado y agrega dos líneas, con capturas del teclado y menús abiertos. El arnés no toca bóvedas y su ruta está excluida de Release. Capturas adicionales: acceso, inventario, conciliación, exportación Kardex, resumen y cierre.

Pendiente físico: Face ID/Keychain con firma SideStore, tacto, VoiceOver, teclado y compartir Excel. No se considera aprobado por compilar.
