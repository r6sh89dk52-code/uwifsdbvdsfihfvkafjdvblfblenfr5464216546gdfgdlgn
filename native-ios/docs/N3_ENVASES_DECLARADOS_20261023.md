# N3 — Envases declarados y Kardex

Rama exclusiva: `feat/build222-native-ui-parity-20261020`.
Base publicada verificada: `f12ea441d8398de18be9b0781e58388660fbefc9`.
Los commits `0ec2a60` y `fccce39` son antecesores de esta base.

Este documento sustituye la descripción N2 que hacía depender la apertura de la capacidad restante. No reescribe ni recalcula movimientos históricos.

## Causa y corrección

El planificador anterior recorría el contenido interno de los lotes y abría otro envase cuando ese contenido se agotaba. La casilla autorizaba ese plan, pero no declaraba cuántos envases se habían abierto. Además, la disponibilidad de un envase abierto se deducía de `openedRemaining`.

Ahora se separan tres conceptos:

- Cantidad clínica: permanece en la atención original.
- Apertura contable: número entero de envases realmente abiertos y declarado expresamente por el usuario.
- Volumen interno opcional: no determina aperturas ni agotamientos.

El motor elige la unidad de Kardex del lote, no solamente la unidad del medicamento clínico. Por ejemplo, un producto clínico UND vinculado explícitamente a una CJA verificada descuenta cajas declaradas, no una caja por unidad clínica.

`declaredOpenContainers` se conserva en el lote dentro de la misma generación cifrada que la atención y sus movimientos. No se reinicia por día ni por sesión. Un saldo interno numérico de cero no cierra ese estado.

`newContainers` especifica la cantidad declarada. Una autorización antigua sin ese número no se transforma silenciosamente en una apertura nueva. Los borradores antiguos requieren una declaración nueva antes de abrir. Las evidencias antiguas que carecen de la declaración tampoco se reinterpretan como aperturas.

Si existe un envase abierto y no hay una declaración nueva, el Kardex registra R=0. Sin envase abierto ni declaración, el producto permanece pendiente y el stock no cambia. Una declaración de N aperturas reduce exactamente N envases cerrados y registra R=N, aunque hubiera otro envase abierto. No se completa un plan insuficiente abriendo envases adicionales por capacidad.

Sin selección explícita de lote, las N aperturas se reparten entre los lotes compatibles en orden FEFO; no se salta un lote anterior para buscar otro que contenga toda la cantidad. La suma auditada de las partes debe coincidir con N. Un volumen opcional insuficiente no autoriza aperturas adicionales.

## Auditoría y compatibilidad

Las nuevas salidas de envases llevan `containerAccountingVersion:1`, `declaredOpenings`, referencia a la atención y al producto, lote, fecha y estados anterior/posterior. La auditoría comprueba el plan declarado, el saldo cerrado, el estado abierto, R y la continuidad canónica del historial.

Un uso sin volumen declarado no inventa una salida de mL: su cantidad interna y su cambio físico son cero. Solo este contrato validado admite esa cantidad cero; los movimientos antiguos conservan sus validaciones originales. R=0 no se asigna a una atención sin vínculo verificable.

La clave de atención/producto impide repetir la dispensación al reintentar. Los movimientos ya vinculados mantienen sus valores originales. No se migran ni reescriben los catálogos, las 86 correspondencias, los lotes históricos o los respaldos.

La capacidad es opcional. Cuando no se proporciona, el esquema numérico heredado conserva su contador compatible, pero `volumeTrackingEnabled:false` impide interpretarlo como volumen físico verificado. La interfaz muestra envases abiertos/cerrados, no una capacidad supuesta.

## Interfaz y estado final del envase

El tratamiento muestra «Abrir nuevo envase» incluso si ya existe uno abierto. Solo una elección explícita habilita la cantidad de aperturas. El uso habitual de un envase abierto no requiere confirmaciones repetidas.

El inventario permite declarar agotado, cerrado/retirado de uso o descartado, con cantidad, responsable, motivo y confirmación. El evento `containerState` no devuelve envases al stock cerrado ni vuelve a consumirlos. Tampoco estima cuánto volumen se descartó. Tras retirar envases, el volumen residual deja de considerarse seguimiento verificado; se conservan sus valores históricos sin convertirlos en una salida inventada.

El resultado de la atención y el historial muestran el R contabilizado, incluido R=0 por reutilización. Las vías CLINICAL y DEMO usan el mismo enrutador, con dominios cifrados separados.

## Reportes y Excel

El consolidado diario y los rangos de Enfermería suman el R de los movimientos de envases, y muestran como saldo contable los envases cerrados. Los eventos de cierre no generan otro consumo.

El corte del día 9 usa las aperturas registradas y reconstruye el saldo a la fecha consultada mediante los estados anteriores a movimientos posteriores. No usa indiscriminadamente el saldo actual para un corte histórico. Los ingresos de envases se cuentan como envases, no como su volumen interno.

Las reglas operativas verificadas se reconocen también al exportar el Indicador, conservando su identificador y versión; no se añaden a las 86 aprobaciones oficiales.

Un envase pendiente sin apertura verificable no convierte su cantidad clínica en R ni siquiera en un Indicador provisional: la exportación exige conciliarlo o excluir esa atención de la selección. Se mantienen las diez hojas, 432 materiales, 19 tablas y 30 columnas del Indicador, y las 98 filas oficiales de Enfermería.

## Otras correcciones N3 conservadas

- Firma local de ejecución del Simulator: la aplicación sin firma carecía del identificador de acceso necesario para Keychain y devolvía -34018. No se deshabilitó el cifrado ni se añadió una clave de producción. Se eliminó la omisión por -34018 de la prueba: una regresión de firma debe fallar, no saltarse la comprobación.
- Conservación del árbol de vistas durante inactividad transitoria de LocalAuthentication, con contenido oculto, inaccesible y sin interacción mientras la escena no está activa. El fondo sigue bloqueando e invalidando la sesión.
- Entrada automática al recibir la escena activa, además de observar la revisión de la fuente, para resolver una carrera entre autenticación y activación de la escena.
- Botón «Ocultar teclado», desplazamiento interactivo y revelado de búsquedas recién abiertas.
- Prueba nativa de activación DEMO corregida para una fuente realmente vacía; no se repuso un catálogo de trabajadores ficticios dentro de la app operativa.

## Diagnóstico del log original

El log `DANPER_N2_PARIDAD_MAC_20261022_233838.log` falla en una aserción estática que buscaba un texto de restauración en una vista que había cambiado. Es un desajuste de la auditoría, no una excepción causada por Node 24.22.0. La corrección anterior y sus pruebas se conservan; Node 24.22.0 sigue siendo el entorno de comprobación.

## Validación

El guion UI N3 crea y conserva registros ficticios cifrados mediante la interfaz normal. Solo debe ejecutarse en un Simulator aislado, sin datos clínicos reales. Las pruebas de interacción rechazan destinos físicos; no simulan éxito de LocalAuthentication dentro de la aplicación.

Resultados comprobados el 23/10/2026:

| Comprobación | Resultado |
| --- | --- |
| Suite Swift completa del motor final | 327 pruebas, cero fallos, 656,54 s |
| Regresiones focalizadas de envases, FEFO y reglas operativas | 19 pruebas, cero fallos |
| Node 24.22.0: `npm run test:logic` | 50 scripts completados, salida 0 |
| Auditorías N2 adicionales | 6 scripts; 14 vistas y 35 métodos de ambos dominios comprobados |
| Recursos y TypeScript/Vite | Generación correcta y build correcto; advertencias de tamaño de chunks no bloqueantes |
| Xcode: `AcceptanceFinal` | 15 pruebas, cero fallos y cero omisiones: 13 nativas y 2 UI |
| Revalidación nativa posterior | 13 pruebas superadas tras la aclaración de unidades del selector de lotes |
| Compilación explícita Xcode Simulator | `BUILD SUCCEEDED`, firma local verificada |

El entorno fue Xcode 16.2, iPhone 16 Simulator con iOS 18.3.1, macOS 15.1.1, arquitectura x86_64. No se generó IPA. Los originales siguen sin cambios: 432 productos clínicos, 98 productos de Enfermería, 86 correspondencias y 155 áreas.

### Aperturas y persistencia

La regresión obligatoria parte de dos frascos cerrados y obtiene **1, 0, 0, 1, 0**. Usa cinco días y reabre el journal cifrado en cada atención. Termina con cero cerrados y dos abiertos declarados. Reintentar la última atención no añade movimientos.

También se comprueban: agotamiento del volumen sin cierre automático; nueva apertura explícita aun con otro envase abierto; dos aperturas en la misma atención; cierre manual sin otro descuento; denegación sin declaración; datos alterados rechazados; CJA vinculada a un producto clínico UND con R **1, 0, 0**; y reparto de dos aperturas entre dos lotes FEFO con R por lote **1, 1**, sin inventar volumen.

El diario y el rango de Enfermería contabilizan dos aperturas, no cinco atenciones. Se inspecciona el XLSX real: G93=2 y H93=0 para el producto del ensayo. El Indicador conserva sus diez hojas; dentro del corte iniciado el día 9 mantiene R **0, 0, 1, 0**, porque la primera apertura del día 8 pertenece al corte anterior. Se rechaza usar un envase pendiente como cantidad clínica provisional para inventar una apertura.

### Interacción real en Simulator

El recorrido aprobado usa la interfaz normal, sin probes de layout ni desbloqueo ficticio: entrada autenticada, registro, evaluación, catálogo y sugerencias, selección de procedimientos, varios medicamentos/insumos, atención guardada, regla operativa, evidencia de apertura, inventario, historial, relanzamiento y Kardex.

Se confirmó por UI una apertura de alcohol R=1 y una atención adicional con el mismo envase R=0, sin nueva confirmación de apertura. Después del relanzamiento siguen apareciendo **1 FCO cerrado y 1 envase abierto declarado**. El diálogo para declarar agotado/cerrado/descartado se abrió y se canceló sin alterar el estado; el cierre efectivo se valida por regresión del motor.

Los lotes ficticios de Paracetamol muestran el lote anterior agotado y saldo en el posterior. Las siguientes atenciones sin cantidad suficiente permanecen pendientes, sin descuentos nuevos. La gasa sin correspondencia continúa pendiente; no se inventó un movimiento para hacer desaparecer el aviso. La cobertura de dos sedes y de ambigüedades adicionales corresponde a las pruebas del motor, no a dos recorridos UI completos por sede.

La prueba biométrica usa LocalAuthentication real del Simulator, señales del simulador para coincidencia/no coincidencia y cancelación en Springboard. Comprueba intento automático sin tocar Ingresar, cancelación, reintento y retorno al primer plano. No observa reintento automático durante la ventana comprobada tras cancelar. Esto **no es una prueba de Face ID físico**.

Las ocho pruebas nativas de renderizado/teclado no sustituyen estos recorridos funcionales. El vencimiento admite entrada DD/MM/AA, pegado y corrección de cursor; las listas y los Excel conservan sus formatos de presentación existentes con año completo.

### Diagnóstico de las ejecuciones intermedias

Las ejecuciones incompletas no se cuentan como aceptadas. Un guion de UI arrastraba desde la posición del interruptor y desmarcaba involuntariamente la apertura después de confirmarla. La inspección de solo lectura del registro ficticio cifrado mostró consentimiento falso y cantidad de aperturas cero: el motor había rechazado correctamente el descuento. El guion ahora desplaza desde el margen no interactivo y comprueba el consentimiento inmediatamente antes de guardar. Se retiró el diagnóstico temporal; no se cambió el motor para aceptar una apertura sin declaración.

Los borradores y atenciones ficticias intermedios se conservaron. No se borró el historial para conseguir resultados positivos ni se recalcularon consumos anteriores.

### Comparación visual y límites

Se conservaron 17 capturas originales de la ejecución aprobada, además de las referencias Build 222 disponibles en el proyecto. Coinciden identidad DANPER, cuatro pestañas en el mismo orden y áreas funcionales. No son pantallas idénticas: la cuadrícula y el orden de herramientas de inicio, la organización vertical de Kardex, tamaños/tipografía y controles de navegación nativos difieren de las capturas web. El saludo tampoco reproduce el nombre fijo de la referencia. El contador de lotes se denomina «registrados», porque conserva también los agotados.

No se hizo una comparación píxel a píxel con viewport idéntico. Las referencias disponibles no permiten certificar todos los estados de tratamiento, conciliación y resultado. Por ello **no se declara paridad visual completa**. La apertura/cancelación de esos estados sí se observa en las capturas nativas y en las pruebas UI.

Pendiente en iPhone físico: Face ID y código reales, cambios de enrolamiento, bloqueo/retorno con el sistema real, teclado y tamaños de texto en pantalla física, aceptación visual y validación clínica por el responsable. Ninguna equivalencia ficticia del ensayo se precarga como aprobación oficial. No se modificaron datos clínicos reales, respaldos originales, Keychain de producción, `main` ni Build 222 operativa.
