# Contrato de sincronización v1 — implementación aún no habilitada en iPhone

## Datos y aislamiento

`accounts/{UID}/{collection}/{id}` almacena un documento por entidad. Colecciones: workers, allergies, attentions, clinicalItems, lots, movements, mappings, reconciliations, emo, cholinesterase, leaves, alerts y corrections. Los borradores son locales y no participan en revisiones cloud.

Cada documento tiene `key`, `collection`, `id`, `revision` (entero monotónico), `data`, `operationId` y `sequence`. DNI canónico identifica trabajadores y alergias. Atenciones, ítems y movimientos conservan sus IDs persistentes. La atención guarda un snapshot del trabajador para conservar la historia al corregir el padrón.

Los campos clínicos usan los nombres originales: `worker`, `items`, `date`, `time`, `category`, `system`, `segment`, `permission`, `permissionTime`, `blueBandage`, `returned`, `photoSent`, `responsible`, `responsibleDni`; lotes y movimientos preservan unidades, estados before/after y dispenseRef. Hay campos de edición web adicionales; se requiere todavía completar la traducción explícita entre los borradores web y los nombres de apertura nativos antes de activar migración. Los registros desconocidos se conservan en staging; no se descartan silenciosamente.

## Escritura

1. Una transacción IndexedDB aplica entidades y persiste la operación en outbox. No se comunica éxito si falla esta transacción.
2. Con sesión autorizada y conexión, una transacción Firestore lee primero recibo, reloj y todas las revisiones afectadas.
3. Si el recibo existe, el reintento es un no-op remoto.
4. Todas las revisiones deben coincidir con expectedRevision. Un conflicto no se reintenta cambiando la revisión esperada.
5. Se escriben juntas las entidades, recibo inmutable, registro incremental y reloj. Un movimiento no puede quedar separado de sus lotes dentro de la operación cliente.
6. Solo entonces se confirma el recibo en el outbox local. Un cierre de navegador entre pasos 5 y 6 se recupera mediante el mismo ID.

Las operaciones se limitan a 180 entidades. La importación de padrón usa bloques de 100; el conjunto completo de 10k filas no es una única transacción global. El proceso es reanudable por DNI, pero la pantalla todavía necesita un resumen persistente por lote de importación para reanudación explícita después de un cierre a mitad de proceso.

## Lectura incremental

Se leen páginas de 25 eventos `changes` por secuencia y después las entidades afectadas. El cursor y las entidades entrantes se aplican juntos. Un registro con cambios locales pendientes se conserva localmente para revisión; no se sobrescribe. La caché persistente clínica es IndexedDB; Firestore usa memoria, evitando dos colas independientes con resolución “última escritura gana”.

El primer dispositivo que se incorpora necesita una lectura inicial del historial de cambios; no se descargan 10k trabajadores cada vez que se abre Registrar. El reloj único serializa las operaciones de una sola cuenta. No se ha probado todavía el rendimiento remoto con 10k fichas en Spark ni la contención entre dos dispositivos reales.

## Conflictos

Se marca la operación y se bloquean las dependientes. Se permite exportar la operación para revisión. Está pendiente la interfaz completa que compara revisión remota, comandos físicos y evidencias, y produce una nueva operación conciliada. Nunca se debe resolver una colisión de stock copiando el saldo del dispositivo ganador. Este punto bloquea la activación clínica compartida.

## Seguridad y despliegue

Las reglas entregadas por defecto deniegan todo. El generador necesita UID verificado y proyecto real, y crea un archivo de reglas separado. Autenticación Google y UID se comprueban en cliente y reglas. El UID no es una contraseña. No se requieren Cloud Functions. Las cuotas gratuitas siguen aplicándose a lecturas, escrituras y almacenamiento.

Las reglas requieren recibo y secuencia por documento e impiden actualizar eventos guardados. Falta ejecutar pruebas de reglas en emulador y de transacciones remotas; no se consideran certificadas solo por lectura del archivo.

Referencias oficiales consultadas: [transacciones](https://firebase.google.com/docs/firestore/manage-data/transactions), [persistencia offline](https://firebase.google.com/docs/firestore/manage-data/enable-offline), [Hosting](https://firebase.google.com/docs/hosting/quickstart).

## Adaptador Swift

Paquete Foundation aislado en native-adapter. `SyncCoordinator` inicia desactivado; requiere validación de migración y conciliación. `EncryptedSyncJournal` obliga a integrar almacenamiento cifrado existente mediante implementación explícita. `FirebaseCloudTransport.swift` es una fuente opcional para un target de validación con SDK Firebase; no fue añadida al proyecto instalado.

Las pruebas Swift están escritas pero no ejecutadas en Windows sin toolchain Swift. Ejecutar `swift test` en native-adapter, compilar el target aislado con Firebase y después probar web → iPhone e iPhone → web con datos ficticios antes de conectar la bóveda real.

Las escrituras web también están desactivadas por defecto mediante `VITE_CLOUD_WRITES_ENABLED=false`. Configurar las claves públicas no activa automáticamente la cola. El cambio explícito a true queda reservado para la validación ficticia, y después para una migración autorizada completamente verificada.
