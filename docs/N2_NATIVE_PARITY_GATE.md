# DANPER — paridad build 222 → SwiftUI N2 (SIN IPA)

## Alcance alcanzado
- Motor en memoria `N2NativeClinicalTransaction`: preserva las nueve colecciones originales, confirma la atención como una operación lógica, calcula FEFO por lotes, genera movimiento con vínculo de atención y evita duplicar entregas confirmadas.
- Solo asociaciones oficiales de las 86 equivalencias aprobadas; E-62 y E-63 continúan distintas. Las no autorizadas mantienen R desconocida.
- UNIDADES emitidas por cantidad clínica. CJA/FCO/PAQ exigen cantidad física específica, lote verificado y autorización de apertura nueva. Reutilización registra R=0, apertura R=1 por envase; guardado atómico en memoria antes de cualquier persistencia.
- Antes y después se valida íntegramente el snapshot mediante las puertas N1e y N1f. No se infieren consumos históricos ni cero para saldos desconocidos.

## Puertas aún abiertas antes de paridad **real**
- Enlazar el nuevo motor a formulario editable real: búsqueda y alta de trabajadores reales, alergias, diagnóstico, procedimientos, borradores con corrección auditada y fotos SI/NO, conservando la estructura de CONSUMOS A–AD.
- Persistir las nueve colecciones mediante generación cifrada y recuperación tras fallo de energía; activación segura de UNA fuente histórica original, sin mezclar registros demostrativos.
- Integrar exportadores de Excel desde la misma generación de datos clínicos consolidada: cierre 9–8, Kardex diario/rango, CONTEO, ingresos, RESU M manual, tablas, impresión y fórmulas.
- Pruebas cruzadas reales de archivo con Microsoft Excel, protección local Face ID, segundo respaldo cifrado/restauración, condiciones de recuperación, instalación iPhone y comportamiento de SideStore.

**No declarar que SwiftUI ha alcanzado build 222 solo porque sus tests de laboratorio pasen. No generar IPA, no fusionar main, no importar información real todavía.**

## N2 — coordinación con revisiones AES-256-GCM (laboratorio exclusivamente)

- `N2EncryptedClinicalJournal` guarda una generación cifrada y autenticada AES-256-GCM con manifiesto HMAC en una carpeta temporal aislada. El puntero activo se reemplaza atómicamente después de verificar la nueva generación; conserva generaciones previas.
- `N2AtomicClinicalCoordinator` enlaza guardado de atención FEFO en memoria con revisión cifrada completa, detecta cambios incompatibles de la misma visita y reconoce reintentos idénticos tras una interrupción posterior a la actualización del puntero.
- Pruebas sintéticas: inicio, revisión esperada, sobrescritura obsoleta, autenticidad, corrupción, fallos tras cifrado/diario/puntero y verificación de que el historial y el stock siempre están en una misma generación.
- **Restricciones:** el directorio solo admite prefijo temporal `danper-n2-synthetic-`, la clave es externa al código, ninguna pantalla clínica real llama al coordinador. No se generan ni firman IPA, ni se leen respaldos reales. La ausencia de un `fsync` explícito y las verificaciones físicas de iOS aún pendientes impiden declarar durabilidad eléctrica de producción.

## N2: historial y frecuencia nativa

- `N2NativeSnapshotReader` proyecta las nueve colecciones clínicas sin modificarlas; preserva diferencia entre `R=0` verificado y `R=nil` pendiente; aplica FRECUENCIA por trabajador/fecha ordenando por fecha, hora, ID de atención, no por cantidad de materiales consumidos.
- Búsqueda de personal respeta activación del padrón oficial, sin borrar personal histórico ni atenciones antiguas.
- La vista SwiftUI `N2NativeHistoryView` utiliza exclusivamente un snapshot ficticio construido en CI; el lector es reutilizable en una futura bóveda operativa autorizada. No importa ni expone datos reales.

## N2: almacenamiento clínico persistente y respaldo portátil

- `N2ProtectedClinicalVaultCore` encapsula una generación clínica separada bajo `Application Support/DANPER-N2-CLINICAL-VAULT`, con protección completa iOS, verificación contra modificaciones y retención de generaciones previas. Solo admite una fuente inicial completa y revisada explícitamente; no fusiona datos de prueba ni accede al contenedor de la build 222.
- `N2ProtectedClinicalIOSVault` utiliza otro servicio Keychain `...preview.n2.clinical`; nunca crea una clave reemplazo si existe contenido que no puede descifrar.
- La API de respaldo `N2NativePortableBackupMaker` implementa `.danperbackup` v1 compatible (PBKDF2-SHA256, 310.000 iteraciones, AES-256-GCM, sal de 16 bytes, nonce de 12 bytes); verifica descifrado antes de entregar el cifrado para compartir. No escribe respaldos sin contraseña ni incluye datos en el ejecutable.
- **No conectado aún a los flujos operativos o pantallas de importación/exportación real.** Compilar iOS no sustituye una prueba de restauración real y una comparación completa de snapshots de origen/destino.

## N2: formulario clínico nativo protegido y borradores

- `N2NativeClinicalFormView`: cuatro pasos independientes de la app híbrida para trabajador/alergias, evaluación, procedimientos y medicamentos, confirmación de atención. Solo opera tras verificar una fuente clínica N2 importada con consentimiento.
- `N2NativeFormContextReader` obtiene lista oficial de trabajadores, alergias y lotes compatibles del mismo snapshot cifrado; conserva las 432/98/86 equivalencias verificadas, sin emparejar productos por similitud textual.
- `N2NativeFormDraft` genera registros compatibles con la estructura de CONSUMOS A–AD y parches cifrados para borradores; no inventa cantidades físicas ni abre un envase sin aprobación explícita. La foto se marca NO si no hay lesión/curación.
- El motor de atención permite cero medicamentos cuando hay un procedimiento/observación válido; una atención sin medicamento no crea un movimiento de stock inexistente. La promoción de borrador a guardado es transaccional, no inserta un segundo ID ni pierde campos extendidos.
- Las pruebas del modelo no reemplazan una revisión visual de iPhone; falta completar paridad de todos los campos de la build222, historial editable, cortes y reconciliación integral.

**Bloqueo:** el uso clínico real permanece en evaluación mientras no se completen todas las pruebas de exportación/restauración y equivalencia de la build222. No generar IPA.
