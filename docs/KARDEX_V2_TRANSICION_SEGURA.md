# Transición segura al Kardex consolidado

Esta guía describe operaciones que debe autorizar el propietario de los datos. El desarrollo y las pruebas usan exclusivamente fuentes ficticias. No se ha abierto, reiniciado ni migrado una bóveda clínica real.

## Antes de cambiar datos reales

1. Conserva la aplicación anterior y un respaldo cifrado completo que puedas recuperar. Guarda su contraseña por separado. No sobrescribas esa copia.
2. Instala únicamente una compilación revisada que conserve los identificadores y las llaves de la aplicación correspondiente. El IPA se preparará posteriormente en GitHub; este trabajo no distribuye ni instala una versión física.
3. Si la fuente clínica ya está en la aplicación nativa, el reinicio conserva sus atenciones directamente: no hace falta importarlas otra vez. Si es una instalación vacía, utiliza **Restaurar copia cifrada Build 222** para la recuperación completa, revisa sus contadores y autentícate. Una fuente ya existente bloquea esa recuperación completa.
4. Comprueba trabajadores, fechas, diagnósticos, procedimientos, medicamentos, alergias y borradores antes de iniciar el inventario nuevo. Con datos reales esta comprobación corresponde al usuario; las pruebas ficticias no certifican un archivo real que no se ha recibido.

## Activación del inventario

En Kardex registra al menos un conteo físico real. Cada producto conserva código, nombre y unidad originales del catálogo. Un producto no contado queda sin existencia verificada; no se convierte en cero. Un cero contado sí es válido.

Selecciona conteo por unidades para unidades individuales y por presentación para las presentaciones que contabilizas al abrir. Las unidades de catálogo desconocidas requieren una elección explícita. No cambies el código o la unidad para conseguir que un reporte coincida; tampoco conviertas litros, mililitros, cajas o unidades entre sí.

Indica el próximo vencimiento como referencia manual o déjalo pendiente de verificar. Esa referencia no certifica la aptitud de todas las existencias físicas.

El flujo exige una contraseña nueva, generar la copia completa cifrada, guardarla en Archivos, volver a leerla desde el destino, descifrarla y validar su estructura y cadenas clínicas. Después muestra la autorización expresa del reinicio y solicita autenticación del sistema. Si el archivo fue eliminado, cambió la fuente, cambió el archivo o cambió la revisión de la bóveda, la activación se detiene: actualiza la pantalla y crea/verifica una copia actual.

La activación registra UUID, hora exacta, zona America/Lima, versión 2, hashes de origen y respaldo, operador, autorización, auditoría y los conteos. La promoción del diario cifrado es atómica. No ejecutes el reinicio de nuevo para corregir una cantidad: utiliza un conteo autorizado.

## Qué se conserva y qué deja de operar

Se conservan trabajadores/DNI, atenciones completas, cantidades clínicas, procedimientos, diagnósticos, alergias, correcciones, borradores válidos y correspondencias. Las identidades históricas de las atenciones no se sustituyen por el nombre actual del trabajador.

Lotes, movimientos FEFO, conciliaciones ambulatorias antiguas, asignaciones/aperturas/cierres y evidencias pendientes del régimen anterior se retiran del estado operativo. El respaldo obligatorio y las generaciones protegidas anteriores conservan el origen. El régimen nuevo guarda únicamente evidencia clínica histórica de R ya verificable; no importa un libro físico antiguo ni vuelve a descontarlo.

Antes de autorizar el inventario nuevo todavía puedes guardar atenciones. Esta versión conserva esas atenciones sin ejecutar nuevas salidas FEFO sobre el inventario anterior.

## Restaurar historial conservando el inventario

Después de activar el conteo nuevo, utiliza **Restaurar historial clínico sin reemplazar inventario**. Selecciona el respaldo anterior, introduce su contraseña, revisa el resumen y confirma/autentica la operación. La aplicación mantiene productos, conteos y movimientos del régimen activo.

El DNI determina la identidad canónica. Los registros idénticos se deduplican; repetir el mismo respaldo no duplica trabajadores, atenciones ni consumos. Si existen registros con el mismo identificador y datos diferentes, alergias contradictorias o cadenas de corrección incompatibles, se rechaza toda la operación. Conserva ambos respaldos y revisa la discrepancia en su fuente; no borres ni cambies IDs para forzar una mezcla.

No se importan lotes, saldos, conciliaciones o pendientes FEFO. Una restauración completa de emergencia se permite exclusivamente sobre una fuente vacía y es un flujo distinto. Nunca sustituye silenciosamente el inventario activo. Las bóvedas DEMO y clínica mantienen rutas, llaves y dominios separados.

Los respaldos del inventario nuevo usan sobre y payload de versión 2. Una versión antigua debe rechazarlos; no se debe interpretar un respaldo v2 como un inventario FEFO vacío. Conserva también el respaldo v1 previo a la transición.

## Operación cotidiana

- Unidades: 70 unidades y una entrega de 2 producen 68.
- Presentaciones: 12 frascos y **Sí — R=1** producen 11. **No — R=0** conserva 11. No se estima volumen restante ni se cierra un envase automáticamente.
- Si falta conteo, R o stock, la atención válida se conserva y aparece una incidencia independiente. Resuélvela después de verificar el hecho físico. Si un conteo posterior ya cubría ese consumo antiguo, la resolución no hace otro descuento.
- Entradas, salidas manuales, conteos y cambios de vencimiento registran operador, hora y motivo. Una repetición del mismo comando no aplica dos veces; un ID reutilizado con datos diferentes se rechaza.
- Un conteo posterior sustituye el saldo calculado por el físico confirmado y registra la diferencia. Permite mantener, actualizar o dejar pendiente el próximo vencimiento. Un cambio de vencimiento no cambia existencias.

## Cortes y Excel

El período permanece del 9 al 8. La consulta retrospectiva es de solo lectura:

`apertura estimada = conteo + salidas verificadas − ingresos − ajustes netos`.

70 + 4 − 2 = 72 describe una apertura verificable cuando existe evidencia suficiente; el stock actual sigue siendo 70. Si la evidencia es incompleta o incompatible, se muestra **Saldo inicial estimado: requiere verificación**. La apertura extraordinaria parte del conteo confirmado y no certifica el pasado. Ninguna estimación se convierte automáticamente en un movimiento.

El Excel ambulatorio conserva A–AD y diez hojas. R proviene de evidencia auditada; un R desconocido del régimen nuevo queda vacío en el provisional. Las discrepancias clínicas mantienen sus restricciones de exportación. Las selecciones parciales y los saldos no comprobados no se certifican como un cierre completo. La columna de conteo físico no se rellena con un saldo meramente calculado.

Enfermería conserva las 98 filas y las columnas originales. Solo una correspondencia única y una unidad compatible permiten ocupar una fila con stock verificable; una asociación ambigua no duplica existencias. Un LT clínico no se transforma automáticamente en un FCO de enfermería, ni un UND en CJA. Las filas sin saldo verificable se identifican y sus fórmulas de saldo desconocido se suprimen para evitar ceros aparentes. F/S se consigna cuando hubo conteo; el vencimiento corresponde a la referencia manual vigente en la fecha del reporte. La consulta histórica no usa una modificación de vencimiento registrada después de esa fecha.

Los productos sin correspondencia compatible continúan funcionando en el inventario y en el registro clínico; su fila oficial de enfermería queda sin certificar. No inventes equivalencias para completar las 98 filas.

## Revisión después de activar

Comprueba al menos una atención anterior, un borrador recuperado, los conteos iniciales, una salida por unidades y una declaración R=1/R=0. Exporta una copia cifrada v2 y consérvala además del respaldo anterior. Revisa los reportes y las incidencias. Cierra/reabre la aplicación y verifica autenticación, borradores e inventario. Ante una interrupción, actualiza primero la pantalla y consulta el historial antes de repetir una operación.
