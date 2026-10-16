# N1l — Plan de importación clínica nativa con CERO MEZCLAS

## Decisión vinculante
Se prohíbe incorporar a la aplicación SwiftUI los registros ficticios preinstalados del laboratorio N1g como punto de partida de una base clínica. Los datos nativos reales, cuando se habiliten en una etapa futura, procederán **únicamente de una copia completa .danperbackup de build 222 seleccionada por la persona, inspeccionada localmente, y a un contenedor nuevo vacío, con reemplazo íntegro**. Jamás `existing + incoming`, `reconcileWorkers` ni una unión por DNI para restauración de la base completa.

## Ya implementado en N1l
- En el inspector SwiftUI de Inicio/Más se solicita archivo y contraseña en el iPhone. Descifra localmente y audita la estructura completa de las nueve colecciones originales.
- N1lRealSnapshotGate reutiliza N1f: comprueba todos los campos conocidos/desconocidos, distingue ausente/null/false/cero, preserva orden de arrays, cuenta atenciones guardadas, borradores, correcciones, alergias conocidas/negadas/desconocidas, y mantiene intactos los consumos pendientes de vincular con movimientos.
- Identifica lotes sin identificador y lotes con ID duplicado, correcciones sin atención original guardada y atenciones sin trabajador en padrón.
- Señala expresamente identidades sintéticas conocidas del laboratorio N1g/N1f; **no hay garantía de detectar todas**. Nombres reales o falsos no pueden diferenciarse criptográficamente por el respaldo. Un backup que ya fue combinado en la build 222 requerirá revisión local por procedencia y comparación con fuentes confiables, sin inventar una clasificación automática.
- N1lDestinationState rechaza `containsDemonstration`, `containsClinicalData` y `uncertain`; solo se considera en el futuro un contenedor `verifiedEmpty` separado del almacén N1g/N1i.
- `canCommitToClinicalStorage` es **siempre false**: N1l no tiene método de importar ni escribe datos clínicos, no cambia ningún Keychain de producción, no exporta pacientes a archivos GitHub o CI.
- El inspector muestra exclusivamente cantidades agregadas y avisos sin DNI, nombres, diagnóstico o datos sensibles.

## Pruebas
Doce casos Swift Linux prueban: reconocimiento de seed ficticio y rechazo; fuente sintética limpia pero procedencia no verificada; destino con demostraciones, datos o estado incierto; preservación de extensiones futuras y borradores; ausencia de colección; DNI duplicado; lotes duplicados o sin ID; correcciones sin origen; atención huérfana del padrón; independencia del núcleo ficticio; y auditoría sin escribir. Se conservan 99 casos de N1k.

Se repite auditoría Xcode en macOS con compilación iOS Simulator y iPhone genérico sin firma ni IPA. Los tests GitHub utilizan exclusivamente datos sintéticos en RUNNER_TEMP.

## Futura habilitación transaccional, no realizada
1. Selección de una copia **íntegra, reciente y de procedencia conocida** desde build 222, sin datos de prueba mezclados. El usuario debe confirmar procedencia y comparar cantidades con la app real. Nunca recuperar de un snapshot parcial un inventario vacío.
2. Nueva bóveda clínica nativa totalmente independiente y vacía: no N1g/N1i demo; claves nuevas en servicio Keychain distinto; restablecimiento accidental y merges imposibles.
3. Preparar un archivo de generación temporal con todas las colecciones y validar hash semántico, conservación de campos/IDs, conteos, lotes, movimientos, R de Excel, documentos e historial, sin alterar el contenedor anterior.
4. Activación atómica de generación nueva **solo** tras verificación 1:1 y confirmación explícita. Probar interrupciones y restauración hacia atrás sin pérdida. Mantener la build 222 intacta como origen.
5. Auditoría de padrón (DNI único), atenciones y frecuencia del mismo día, alergias de tres estados, correcciones, FEFO/Kardex, 10 hojas oficiales, consumos sin movimientos vinculados; no generar registros complementarios ficticios.
6. Validación final de importación en iPhone por el propietario, cuando le sea posible. Hasta entonces se puede avanzar con código y pruebas, pero **sin activar escrituras clínicas reales**.

**Protección de privacidad:** no subir respaldos reales ni contraseñas a GitHub, correo de CI ni el chat. La auditoría real se ejecutará dentro del iPhone con FileImporter y sin logs de pacientes.
