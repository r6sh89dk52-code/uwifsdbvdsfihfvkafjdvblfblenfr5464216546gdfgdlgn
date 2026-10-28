# Kardex consolidado v2 — auditoría y arquitectura

Fecha de inicio: 27-10-2026. Rama exclusivamente local `feat/swiftui-premium-kardex-simple-v2`.

## Protección y base

Repositorio local real: `/Users/felipeazcarate/Downloads/DANPER-N2-Paridad`. Árbol inicial limpio. Base Premium `2c776e88bc8b83e68ea85060263d204ca57025da`, con evidencia local previa de 383 pruebas Swift, 61 comprobaciones JS y 22 XCTest aprobadas. Es evidencia de la base, no del modelo v2 todavía.

`origin` usa el nombre anterior `r6sh89dk52-code/danper-salud-movil-pruebas`; la referencia remota proporcionada resuelve la misma recuperación `ca95650a3ab5a47675f59677eb4249e37e48c511`. Recuperación desciende de la base con 11 commits (0 exclusivos locales frente a ella); NO se fusionó. Sus diferencias de aplicación se limitan a comparación JSON portátil de cierres y ajustes de pruebas. Sus workflows/IPA no se incorporan automáticamente. Glass Clinical permanece separado en `design/glass-clinical-access-home-20261027`, `4f3c0c0dec1a6dbe27988f1577d5e81bb5ffbbea`.

Referencias protegidas: Premium `2c776e8`; estable `9bec8e0`; main `19118cc`. No se cambian llaves ni identificador de bundle, no se instalan actualizaciones físicas y no se hace push/merge/distribución sin autorización.

Entorno comprobado: Xcode 16.2 (16C5032a), Swift 6.0.3 en modo de lenguaje 5.9 del proyecto, Mac Intel, SDK 18.2, runtime iOS 18.3.1, simuladores iPhone 16 disponibles. No se afirma compatibilidad de instalación con un iPhone de iOS superior a este Xcode.

El conector GitHub requiere una conexión no disponible, pero Git y `gh api` con acceso local permitido permiten leer referencias y el job de CI. Se descargó el log sintético del run `40576668230` para diagnóstico local. No se reejecutó CI ni se publicó nada.

## Dependencias críticas auditadas antes de implementar

| Componente | Dependencia actual | Tratamiento v2 |
|---|---|---|
| `N1eLegacyClinicalAudit` | lotes canónicos, cadena before/after, dispenseRef y grupos FEFO | conservar auditoría v1 intacta; añadir despacho por versión a un auditor v2 estricto |
| `N1fLosslessFieldGate` y `N1BackupAdmission` | nueve colecciones, identidad DNI, atención completa y campos extensibles | conservar validación y preservación clínica; nunca borrar campos clínicos para admitir v2 |
| `N2EncryptedClinicalJournal` | valida cada generación y usa AES-GCM + MAC + puntero atómico con revisión | conservar mecanismo, validar v2 mediante despacho; misma transacción para datos clínicos y salida |
| `N2ClinicalTransactions` y coordinador atómico | guarda/promueve borrador y descuenta FEFO en un único snapshot | ruta v2 con código/presentación, declaración R y movimiento idempotente; clínica válida con incidencia física separada |
| `N2NativeInventoryCommands` | registra lote, saldo por sellados/abiertos/unidades | solo compatibilidad histórica; operaciones activas consolidadas independientes |
| `N2ContainerAccounting` | declaredOpenContainers, volumen, cierres, aperturas y unidades restantes | conservar lectura v1; no usar en operación v2 |
| `N2StockRegistrationChoice`, `N2KardexCutPreview` y `N2AutomaticCutAccounting` | reconstrucción y corte 9–8 ligado a lotes | reutilizar calendario y fórmula; evidencia consolidada, conteo autoritativo y estimación sin débito |
| `N2NativeFormContext` y formulario | proyectan lotes y muestran FEFO/evidencias de envase | contexto v2 y pregunta manual R=1/0; sin capacidad, cierre ni elección de lote |
| `N2ProtectedClinicalVaultCore`, adaptadores iOS y `N2WorkspaceVault` | enlazan todas las pantallas con fuente clínica o DEMO fija | mantener separación; añadir operaciones versionadas en ambos dominios |
| exportador ambulatorio | historia clínica, correcciones y R verificado | conservar historia, distinguir evidencia antigua y consumos nuevos; no volver a ejecutar salidas |
| exportador Enfermeras/Kardex | 98 filas oficiales, cantidades R y manifiesto oficial | adaptar consolidado sin lotes ficticios; celdas no verificables explícitas, nunca saldo estimado certificado |
| `N2NativePortableBackupMaker`, inspector y admisión | envoltura v1 AES-256-GCM/PBKDF2, revisión explícita antes de activar fuente vacía | seguir leyendo v1, admitir respaldo v2 versionado, restauración clínica selectiva idempotente y bloqueo de sobrescritura silenciosa |

Las estructuras `stockLots`, `stockMovements`, `nativeDispensing`, `physicalUse/dispenseRef`, `declaredOpenContainers`, `openedRemaining` y `sealedContainers` no se eliminan de los lectores de compatibilidad. En v2 las colecciones operativas antiguas quedan vacías; la información clínica original permanece y la fuente completa previa queda en el respaldo cifrado obligatorio y las generaciones protegidas previas. No se reconstruyen automáticamente movimientos antiguos.

## Contrato del nuevo régimen

1. Snapshot clínico conserva trabajadores, atenciones, medicamentos, procedimientos, alergias, correcciones, borradores y correspondencias. Añade `inventorySchemaVersion=2` y estado consolidado validado.
2. Activación registra UUID, instante, America/Lima, esquema, SHA de fuente anterior, SHA de respaldo cifrado verificado, responsable, autorización y auditoría. Cuenta inicial es explícita; cantidad cero es válida, ausencia de conteo no equivale a cero comprobado. Una segunda activación no reinicia ni duplica el régimen.
3. Respaldo debe verificarse contra la revisión/fuente actual y estar guardado en un destino elegido por el usuario antes de activar. Una revisión obsoleta o respaldo incorrecto bloquea la activación. Contraseña nunca se persiste.
4. Código original + presentación inmutable identifican las existencias compartidas entre Fundo y Planta. Movimientos tienen identidad única, cantidad anterior/posterior, motivo y responsable. Conteos son autoritativos; no se aplican de nuevo consumos anteriores a ellos.
5. Por unidad se descuenta la cantidad clínica real. Por presentación, declaración explícita R=1 o R=0; no hay volumen interno ni cierres inferidos. Stock insuficiente conserva clínica e incidencia vinculada; resolver es idempotente y no vuelve a descontar.
6. Estimación del día 9 es una consulta basada solo en evidencia verificable: conteo + salidas − entradas − ajustes. Información incompleta permanece estimación y no modifica existencias. Se permite apertura extraordinaria al conteo, identificando períodos previos no verificables.
7. Restauración selectiva valida descifrado, integridad y estructura; mezcla clínica por DNI/ID canónicos sin sustituir inventario ni traer FEFO. Conflictos no se sobrescriben silenciosamente. Huella de respaldo y procedencia hacen la repetición idempotente. Recuperación completa se distingue y no sustituye un régimen activo sin una autorización específica.
8. Vencimiento es referencia editable manual; cambiarlo no toca saldo. Cada cambio/conteo conserva fecha, responsable y motivo. Desconocido/pendiente/vencido nunca equivale a aptitud garantizada.

## Secuencia y aceptación

Commits independientes para auditoría, núcleo consolidado, reinicio/restauración, R manual, corte/vencimientos, UI/exportaciones, autenticación y pruebas/documentación. Ajustes remotos solo por evidencia y sin fusionar ramas.

Primero pruebas puras con snapshots ficticios y diario cifrado temporal: preservación de árbol clínico, conteo exacto, aislamiento histórico, duplicados, R, stock insuficiente, eventos repetidos, edición de vencimiento, fórmula 9–8, migración interrumpida, contraseña/archivo corruptos y restauración selectiva repetida. Después integración de actor/formulario/exportaciones y XCTest en un simulador nuevo. Las pruebas v1 permanecen como compatibilidad; las pruebas operativas v2 reemplazan expectativas de FEFO en el flujo nuevo.

La autorización de esta misión permite desarrollar y probar el mecanismo, no reiniciar una fuente clínica real. El diálogo de reinicio en producto sigue exigiendo respaldo disponible y consentimiento explícito del usuario.

## Implementación de la retirada operativa

El snapshot v2 exige vacíos `stockLots`, `stockMovements`, `deliveryIncidents`, `ambulatoryReconciliation` y las evidencias antiguas de dispensación, sede y metadatos de lotes. Las correspondencias y cadenas clínicas se conservan; una restauración selectiva tampoco importa conciliaciones ambulatorias del régimen anterior. El respaldo completo previo y las generaciones cifradas anteriores conservan el origen.

Las cadenas de rectificación se validan al verificar un respaldo y al terminar una mezcla selectiva. La proyección clínica corregida se consulta por separado de la evidencia física original: corregir una dosis no vuelve a ejecutar su salida. Los reportes no presentan un saldo derivado como conteo físico, ni F/S=0 sin conteo, ni vencimientos editados después del período consultado.

La aceptación final distingue suite completa, pruebas nuevas, comprobaciones estáticas, XCTest nativo y recorrido de interfaz. Los logs de intentos fallidos se conservan para trazabilidad; el informe identifica las ejecuciones finales y no suma reintentos como pruebas distintas.
