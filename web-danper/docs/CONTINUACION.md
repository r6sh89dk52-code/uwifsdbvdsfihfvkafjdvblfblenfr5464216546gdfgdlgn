# Continuación concreta y puertas de validación

Estado: desarrollo parcial compilable y probado en los casos cubiertos. No cumple todavía todos los criterios integrales solicitados.

## Validaciones realizadas

- Build React/TypeScript/Vite de producción, con recursos generados desde Swift y precaché PWA.
- 24 pruebas de dominio (incluyen identidad heredada de Swift, presentaciones nativas, aislamiento de prueba y equivalencia diario/semanal): catálogos, reglas condicionales, envases declarados, FEFO multilote, stock insuficiente, reintentos, corte Lima 9–8, atención histórica, concurrencia IndexedDB, 10 000 trabajadores, importación de resultados/campañas, cifrado y rechazo de respaldo alterado, indicador, Kardex y vigilancia.
- Playwright: 17 casos pasados en Chromium para escritorio y emulación móvil; 1 omitido deliberadamente porque repite en móvil el recorrido individual de los 432 productos ya ejecutado en escritorio. Incluye importación XLSX con vista previa y paginación, ingreso de inventario, persistencia, cuatro pasos de atención, navegación, oscuro, aislamiento ficticio y descargas reales de Indicador/Kardex/vigilancia. También incluye ventanas centrales de confirmación/error, foco de corrección, búsqueda de padrón de 25 filas, protección de DNI duplicado, navegación con teclado y movimiento reducido.
- PWA de producción con Firebase: pantalla de acceso y recursos estáticos disponibles offline. Módulos y preferencias se probaron antes en modo local; esta prueba autenticada no los acredita. No acredita instalación ni todos los navegadores.
- Auditoría npm guardada: cero vulnerabilidades conocidas reportadas en ese momento.

## Trabajo de código pendiente (no atribuirlo a falta de credenciales)

1. Completar el port de `N2AutomaticCutAccounting`, `N2PendingDispensingEvidence` y `N2NativeReconciliationEditor`. La proyección actual es parcial y no confirma salidas históricas físicas.
2. Crear la interfaz de resolución de conflictos con lectura de revisión remota, comparación explícita, conservación de ambas evidencias y nueva operación reconciliada. El código actual bloquea dependientes y permite exportar el conflicto.
3. Implementar el journal cifrado concreto para `EncryptedSyncJournal` y la traducción completa de campos nativos. Conectar a un target SwiftUI aislado para validación; hoy no está integrado en la bóveda instalada.
4. Completar rectificaciones clínicas según todos los casos de `N2ClinicalCorrections`, incluyendo efectos auditados en ítems, reportes y conciliación; la implementación web actual admite un subconjunto.
5. Portar inventario auxiliar y todas las variantes de comandos nativos, y comparar todos los resultados contra fixtures ejecutados por Swift.
6. Completar conciliación material del Indicador, sus saldos e ingresos. Las pruebas actuales verifican estructura, fórmulas principales y casos sintéticos, no todas las combinaciones oficiales.
7. Portar reglas específicas y selecciones verificadas del proyecto EMO/colinesterasa. Las fuentes locales ya se localizaron: no pedirlas nuevamente sin comprobar esos directorios. No incluir personas reales ni seeds con DNI en Git.
8. Completar importador PERSONAL contra todas las variantes Swift, conservar metadatos de lote para reanudar importaciones masivas y añadir pruebas de nacimiento/sede/discrepancias de cada modelo original.
9. Añadir reportes estadísticos, plantilla oficial de descansos si existe, actualización local de notificaciones iOS y revisión asistida de documentos con aprobación humana. La exportación actual de descansos es de datos explícita, no una plantilla oficial inventada.
10. Ampliar pruebas UI de edición/historial individual EMO/colinesterasa, alertas, correcciones y exportación mediante descarga; comprobar Firefox, Edge, WebKit/Safari y PWA instalada.

## Dependencias externas concretas

- Firebase real ya creado y Hosting publicado: https://danper-salud-web-20261025.web.app. Google Auth configurado y una sola cuenta Google autorizada registrada. Inicio interactivo de Google pendiente de prueba. Firestore Standard configurado en Santiago; mantener reglas cerradas y escrituras desactivadas.
- Entorno con Swift/Xcode para ejecutar las pruebas del adaptador y las fuentes nativas. En este Windows no se encontró toolchain Swift.
- Emulador Firestore/Authentication para pruebas de reglas y de concurrencia remota; no se ejecutaron. No usar la prueba IndexedDB como sustituto de pruebas Firestore.
- Respaldo cifrado autorizado para ensayo de migración local íntegra; no se descifró ni modificó ningún respaldo clínico real.

Mantener `VITE_CLOUD_WRITES_ENABLED=false` y el adaptador Swift desactivado. Las credenciales por sí solas no resuelven los puntos de código anteriores.

## Siguiente ejecución

Trabajar en la rama integral existente y consultar otra vez el HEAD nativo. Si avanzó, revisar sus diferencias antes de actualizar el generador. Ejecutar `npm ci`, `npm run build`, `npm test`, `npm run test:ui` y `npm run test:pwa` desde web-danper. Los resultados están bajo `validation/`; las capturas de Playwright se generan en `test-results/`. No generar IPA, no tocar la instalación del iPhone y no conectar datos reales hasta cerrar las puertas anteriores.
