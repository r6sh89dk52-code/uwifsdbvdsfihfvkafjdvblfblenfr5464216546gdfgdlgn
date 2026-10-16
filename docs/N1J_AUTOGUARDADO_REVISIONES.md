# DANPER N1j — Protección ante guardados fuera de orden y reinicio

Se ha detectado que N1i autenticaba el cifrado pero carecía de una revisión persistente en el puntero. Una tarea asincrónica retrasada podía reemplazar la versión reciente de un borrador ficticio, dependiendo del orden de las tareas SwiftUI. **N1j impide que una revisión menor o igual sustituya a la activa**.

## Cambios
- Puntero cifrado N1j versión 2 añade revisión Int64 estrictamente positiva autenticada con HMAC-SHA256, junto a generación y SHA-256 del ciphertext. El ciphertext sigue autenticado con AES-256-GCM y AAD de generación; no se expone en logs.
- Punteros v1 de N1i permanecen legibles como revisión 0; la primera escritura posterior genera automáticamente v2. Una alteración de `revision`, o un downgrade falsificado de `version`, invalida HMAC y bloquea lectura.
- `N1jRevisionClock`: se inicializa con la revisión autenticada recuperada. Cada cambio captura SINCRÓNICAMENTE una revisión nueva al tomar la copia en memoria para su tarea de escritura. No usa la hora del sistema como criterio de orden.
- El actor de almacén iOS serializa accesos al archivo de demostración. El motor portable rechaza escrituras con revisión igual o inferior a la última activada (`staleRevision`). SwiftUI ignora confirmaciones de tareas viejas, cancela el debounce anterior y solo muestra éxito de la revisión actual.
- Cuando se detecta error de autenticación, escritura o discrepancia de revisión actual, la pantalla de prueba bloquea edición, en lugar de reiniciar el almacén o reportar éxito falso.
- Ante suspensión de iOS, `scenePhase` pide guardado inmediato **de manera best-effort**. La ejecución real tras suspenderse el proceso no está garantizada; se debe validar en iPhone y posiblemente añadir una tarea de tiempo extra de iOS en una futura revisión de Xcode.

## Pruebas nuevas Linux
Diez nuevas pruebas N1j: reloj con revisión recuperada y desbordamiento; primer guardado y reapertura; orden inverso/equivalencia; reinicio con un trabajo antiguo; fallos antes/después de puntero; alteración de revisión y versión; competencia entre escritores; y lectura/migración no destructiva de un puntero ficticio v1 firmado.
Se mantienen todas las 89 pruebas anteriores de cifrado, Kardex/FEFO, validación clínica, borradores y aislamiento.

## Límites críticos
**No existe almacenamiento ni restauración de historias clínicas reales.** Solo catálogo ficticio; la build222 permanece intacta. La serialización de guardados en un actor es un control dentro de un proceso iOS, pero la comprobación del puntero **no equivale a un lock entre procesos**, un fsync o un contador antirrollback resistente a un atacante capaz de restaurar archivos antiguos válidamente autenticados. La ausencia de errores de `swiftc -frontend -parse` en Linux significa únicamente sintaxis válida: no demuestra compilación o funcionamiento en iPhone.

Sin runner macOS, sin Xcode, sin IPA y sin fusión automática; PR draft apilada sobre N1i.
