# DANPER SALUD WEB — base desde SwiftUI (25/10/2026)

## Fuente y aislamiento
- Rama de origen: `feat/build222-native-ui-parity-20261020`
- Commit base exacto: `9bec8e01ccbb3f1a674372cf6e48df049dc4f014`
- Esta rama nueva está aislada: **no modifica** la rama SwiftUI, `main`, el respaldo del iPhone ni sus datos reales.
- Interfaz web preliminar v0.2 (archivo ZIP de la conversación): no publicada ni conectada a la bóveda nativa.

## Código SwiftUI examinado
- `native-ios/Sources/DanperCore/N1lRealSnapshotGate.swift`: nueve colecciones canónicas.
- `native-ios/Sources/DanperCore/N1fLosslessFieldGate.swift`: identidades DNI, visitas guardadas/borradores y preservación de extensiones.
- `native-ios/Sources/DanperCore/N2NativeFormContext.swift`: JSON de atención, IDs de líneas y campos.
- `native-ios/Sources/DanperCore/N2ClinicalTransactions.swift`: guardado + movimiento idempotente y FEFO.
- `native-ios/Sources/DanperCore/N2ContainerAccounting.swift`: apertura declarada, contabilidad de envases, cierre.
- `native-ios/Sources/DanperCore/N2NativeInventoryCommands.swift`: lotes, existencias, movimientos.
- `native-ios/docs/N3_ENVASES_DECLARADOS_20261023.md`: secuencia de aperturas R=1,0,0,1,0, sin inferir envases por volumen.
- `docs/N2_INTEGRACION_CORTE_9_20261024.md`: corte del 9 al 8, sin doble débito retroactivo.

## Contrato de integración
1. DNI como texto de ocho cifras; atenciones y líneas con IDs persistentes, conservando el nombre del trabajador al atender.
2. Inventario físico único Fundo/Planta, no dos saldos paralelos.
3. Aperturas solo declaradas: `newContainers=N` y `declaredOpenContainers` por lote. Reutilizar equivale a R=0 verificado; sin evidencia se deja pendiente, no se crea R ficticio.
4. Unidad clínica y unidad física de Kardex son entidades distintas; volumen interno no determina la apertura.
5. Clave de movimiento por atención y línea `ATT:<attentionID>:ITEM:<itemID>`; no duplicar al reintentar ni modificar movimientos históricos.
6. Las transacciones de consumos deben ser atómicas y compatibles con ediciones offline, incluyendo FEFO multilote.
7. Corte mensual 9–8 y día civil `America/Lima`, sin restar otra vez los consumos históricos.
8. Exports oficiales: Indicador ambulatorio 10 hojas/432 materiales/19 tablas y Kardex Enfermería 98 filas; CSV provisional nunca sustituye los XLSX.
9. Colaboradores y alergias deben conservar sus referencias y procedencia; EMO y colinesterasa se agregan como módulos de dominio separados, vinculados por DNI.
10. Sincronización real solo después de conciliar migración, correspondencias, versiones y movimientos de inventario con fixtures compartidos.

## Trabajo efectuado fuera de GitHub
Se generó un paquete v0.2 web independiente con navegación, trabajadores, formulario de atención web en 4 pasos, seguimiento documental EMO/colinesterasa, alertas, configuración Firebase Spark, inspección estructural **solo lectura** de JSON sintético y pruebas JS. No está sincronizado con SwiftUI ni certificado para consumo automático de medicamentos.

## Próximas tareas con prioridad
- Integrar el código fuente web v0.2 dentro de un subdirectorio `web-danper/` de esta rama, manteniendo libre el nativo.
- Contrastar fixtures SwiftUI de modelo, FEFO, aperturas, idempotencia, correcciones e inventario entre web y Swift.
- Habilitar escritura física de Kardex **solo tras** pasar tests conjuntos y diseñar conciliación offline.
- Crear Firebase Spark propio, probar Auth/reglas y publicar Firebase Hosting para obtener URL real `.web.app`.
- Mantener SwiftUI operativa y sin escritura remota hasta la validación de la migración.

## Advertencia
Una vista preliminar de R y un inspector JSON no son el motor `N2ClinicalTransactions`; no importar datos reales ni considerar los consumos web como contabilizados en el inventario del iPhone.
