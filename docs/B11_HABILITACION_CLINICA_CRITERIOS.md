# DANPER Salud Móvil B11 — Habilitación para uso clínico

**Estado:** NO APTO PARA DATOS REALES. Este documento es una puerta de aceptación técnica, no una autorización clínica ni legal.

## Diagnóstico verificable (18-10-2026)

- `NativeRootView` y pantallas principales llaman actualmente a `N2SyntheticTrialIOSVault.shared`. Al arrancar utilizan una demostración con cinco trabajadores ficticios.
- Existe `N2ProtectedClinicalIOSVault`, que permite importar **una** fuente cifrada y auditada de forma independiente. No está conectada todavía a las pantallas operativas.
- El botón de respaldo en `N2NativeBackupExportView` exporta la bóveda sintética. No hay recorrido de recuperación probada en dispositivo nuevo para el modo clínico.
- El Excel Indicador está preparado para una sola sede por archivo; el consolidado Fundo + Planta sigue pendiente.
- El Kardex admite diario/semanal/rango en código, pero falta compararlo con el libro 222 en Excel y validar el cierre de inventario.
- Son necesarias pruebas de autenticación, protección tras suspender la aplicación, archivos temporales, cambios de dispositivo, roles y registros auditados.

## Pasos ordenados para la salida clínica

| Paso | Resultado exigido | Bloqueante |
| --- | --- | --- |
| 1. Fuente operativa | Pantallas consumen única bóveda CLÍNICA mediante selector de modo autenticado, sin consultar ni mezclar DEMO | Sí |
| 2. Importación PERSONAL | Importador XLSX: conflicto de DNI, reimportes, sede/área y correcciones manuales con historial | Sí |
| 3. Registro end-to-end | DNI > ficha > alergias > atención > FEFO por lote > confirmación > stock/Kardex/historial, transacción atómica | Sí |
| 4. Borradores/rectificaciones | Tras reiniciar, conserva historial y todos los campos; auditoría no modifica atenciones confirmadas previas | Sí |
| 5. Respaldo/restauración | Contraseña incorrecta/corrupción fallan sin borrar; copia recién generada se recupera en base vacía de prueba; hash/recuentos/verificación | Sí |
| 6. Indicador oficial | Un libro 10 hojas y ambas sedes, corte 9-8, 30 columnas, códigos reales 31/124, consumos pendientes sin inventar | Sí |
| 7. Kardex | 98 productos, mL/UND/cajas, apertura R 1/0, FEFO, F/S, 1 día/semana/rango, fórmulas originales | Sí |
| 8. Privacidad/protección | Autenticación al entrar y volver, cifrado en reposo, archivos compartidos protegidos, borrado de temporales, acceso autorizado y revisión de privacidad | Sí |
| 9. QA iPhone | XCTest, Xcode/iPhone real, background/foreground, sin cobertura, pérdida de energía y restauración de una copia segura | Sí |
| 10. Aprobación | Aprobación del empleador/responsable de tratamiento de datos y revisión del personal clínico en entorno piloto | Sí |

## Pruebas mínimas de aceptación

1. Crear datos **100 % ficticios** para ambas sedes. Nunca transportar documentos de pacientes en archivos de pruebas o logs.
2. Comparar un conjunto cerrado de ≥20 atenciones, incluyendo más de una por DNI/día; validar frecuencia y campos A–AD.
3. Simular consumos con lote vencido, sin stock, multilote, frasco abierto, caja abierta, reintento tras error y ajuste: nunca duplicar movimiento o convertir un pendiente en cero.
4. Cerrar, relanzar y probar recuperación de cada atención, borrador, rectificación, inventario y alergia.
5. Comprobar cierre mensual y exportar ambos libros; abrirlos en Microsoft Excel y verificar fórmulas, formatos, nombres y códigos; comparar celda a celda con build 222.
6. Hacer y recuperar dos respaldos cifrados desde entornos limpios; comprobar contraseña errónea y archivo modificado.
7. Verificar autenticación después de bloquear iPhone o pasar a segundo plano y que la información médica no aparezca indebidamente en vista de apps recientes o registros.
8. Recabar autorización institucional para almacenamiento de datos de trabajadores y definir retención, responsables y procedimiento ante pérdida del dispositivo.

## Reglas de liberación

- La **build 222 permanece inalterada** como referencia hasta que se aprueben todas las pruebas.
- El PR #4 sigue como **draft** y la versión de pruebas debe mostrar explícitamente **MODO DE PRUEBA**.
- `BUILD SUCCEEDED` solo confirma compilación; no confirma paridad, restauración, seguridad o aprobación operativa.
- No migrar de forma automática los archivos de build 222 ni crear historial clínico en la fuente sintética con datos reales.
- Registro de aceptación: commit exacto, Xcode/iOS/dispositivo, suite XCTest, recuentos antes/después de restauración, comparación Excel, validación clínica y responsable que autoriza.

Seguimiento técnico: [Issue #5](https://github.com/r6sh89dk52-code/danper-salud-movil-pruebas/issues/5).

## Borrado completo de los datos ficticios — implementado en código, pendiente de validar

El botón `Más → Restablecer entorno de prueba → Borrar TODOS los datos ficticios` abre un asistente con recuentos previos. La persona debe escribir exactamente `BORRAR PRUEBAS`, confirmar una segunda vez y aprobar Face ID o código de dispositivo. **No se ejecuta al importar PERSONAL y no se ejecuta automáticamente**.

Operación de `N2SyntheticTrialIOSVault.eraseEntireDemo()`:
1. Comprueba nombre exacto del dominio sintético, ruta de Application Support permitida y que no sea un enlace simbólico.
2. Invalida únicamente la clave Keychain `n2-synthetic-trial-key-v1` del servicio `pe.danper.saludmovil.native.preview.n2.synthetic`; no utiliza la clave clínica.
3. Elimina el directorio `DANPER-N2-SYNTHETIC-VAULT` completo (personas, atenciones, borradores, alergias, stock/lotes, Kardex, auditorías, consumos y correcciones).
4. Elimina SOLO temporales con prefijos `danper-n2-demo-<tipo>-<UUID>`, nunca los `danper-n2-clinical-*` ni archivos de origen incierto, y cancela las notificaciones `danper.n2.demo.pending.*` y las históricas `danper.n2.pending.*`.
5. Comprueba que no existen ni la clave ni el directorio sintético, y vuelve a Inicio sin resembrar los cinco empleados ficticios. Si el proceso se interrumpe tras eliminar la clave, puede repetirse para terminar de retirar el directorio cifrado residual.

**Límites:** una copia que el operador haya guardado fuera del sandbox (Archivos, correo, etc.) NO se borra ni revoca. Los temporales antiguos sin separación clínica/demo no se purgan automáticamente. Los catálogos y plantillas distribuidos con la app, ajustes visuales y la build 222 tampoco se eliminan.

**Muy importante:** limpiar DEMO **no es un requisito técnico para activar CLÍNICA**, porque las bóvedas son independientes. Limpiar DEMO no importa un Excel real por sí mismo. La importación nativa del Excel PERSONAL y el inicio de una base clínica vacía siguen pendientes y no se consideran acabados.

Pruebas: `N2SyntheticResetScopeTests`, script `scripts/audit-n2-workspace-routing.cjs`, futura prueba manual con datos ficticios y Xcode 16.2. Este desarrollo **no autoriza usar datos reales todavía**.

## Actualización: importador nativo Excel PERSONAL (18-10-2026)

El importador se desarrolló **en código**, pero está **pendiente de XCTest, Xcode 16.2 y comparación con el archivo institucional**; no habilita uso clínico real hasta que todas las pruebas P0 estén aprobadas.

- Entrada: `Acceso clínico independiente → Crear base clínica desde Excel PERSONAL` cuando no hay fuente real, o `Importar/conciliar PERSONAL` cuando ya existe; también desde la pestaña Más del espacio clínico.
- `N2PersonalWorkbookReader`: utiliza `ZIPFoundation 0.9.20` (paquete fijado), XMLParser, y lee exclusivamente `PERSONAL` mediante las relaciones OOXML. Acepta `inlineStr` o `sharedStrings` opcional y Excel comprimido. Limita el archivo a 20 MB y cada parte XML a límites explícitos, bloqueando rutas ZIP anómalas y entidades XML externas. No importa otras hojas ni historial.
- Identidad: encabezados `DNI` y `NOMBRES` obligatorios, alternativos `APELLIDOS Y NOMBRES` y `NOMBRE COMPLETO`, `ÁREA`, `CARGO/LABOR/PUESTO`, `EDAD/EDAD MANUAL/EDAD AUTOMATIZADA`, `SEXO`, `UBIGEO`; DNI con ocho dígitos y sin inferir sexo por nombre. Cuenta duplicados y bloquea conflictos de nombres y sexo.
- La hoja PERSONAL de build 222 no contiene una sede por persona: la interfaz exige seleccionar explícitamente Fundo o Planta para **ese archivo**. Importar por separado los padrones correspondientes si hay sedes distintas, sin mezclar ni suponer ubicaciones.
- Vista previa: cuenta únicos, inválidos, sin nombre, repetidos, sexos ausentes/incorrectos y conflictos, más altas/actualizaciones frente a la bóveda existente. Face ID/código antes de abrir archivos; datos importados permanecen solo en memoria hasta confirmar.
- Primera importación: `N2PersonalRosterImport.initialSnapshot` crea una fuente nueva con trabajadores oficiales y **cero** atenciones, alergias, lotes, movimientos, conciliaciones o consumos; `N2ProtectedClinicalVaultCore.activateInitialPersonal` admite solo una bóveda clínica **vacía** y pasa las auditorías N1e/N1f/N1l.
- Reimportación: `mergePersonal` compara el DNI, mantiene nombres/sexos si coinciden (bloquea contradicciones), conserva correcciones manuales y todas las colecciones de historia, aplica **una única transacción cifrada** condicionada por revisión; no elimina automáticamente ausentes ni crea duplicados. Repetir sin cambios es idempotente.
- No se contacta con servidores ni se incorporan registros reales en el repositorio, recursos de demostración o logs.
- Pruebas nuevas: `N2PersonalWorkbookImportTests.swift` con Excel ZIP sintético y rutas negativas; el script de compilación ejecuta `swift test --filter N2PersonalWorkbookImportTests` y la prueba de seguridad DEMO.
- Después de importar PERSONAL, las atenciones e inventario están vacíos por diseño. Configurar inventario inicial clínico y completar restauración/Excel comparativo sigue siendo obligatorio antes de poner la app en funcionamiento.

## Restauración completa de un respaldo original de build 222 (18-10-2026)

**PR #4 — implementado en código, pendiente de aprobar en Xcode y sobre el respaldo original del operador**.

### Compatibilidad

La fuente oficial `src/portableBackup.ts` (build 222) genera `.danperbackup` con:
- JSON exterior: `format = DANPER-SALUD-PORTABLE-BACKUP`, `version = 1`,
  `kdf = PBKDF2-SHA256`, `iterations = 310000`, `cipher = AES-256-GCM`;
  `salt` de 16 bytes, `nonce` de 12 bytes y `data` base64 que contiene ciphertext + tag.
- PBKDF2 UTF-8 contraseña de 14 a 200 caracteres → clave AES 256 bits.
- JSON interior `{schema:1, exportedAt, snapshot}`; el `snapshot` contiene el
  árbol completo de trabajadores, atenciones, alergias, lotes, movimientos,
  asociaciones, incidencias, conciliaciones y campos desconocidos preservados.
- B11 `PortableBackupInspector` reconoce ese contrato. Lee el archivo en iPhone
  sin modificarlo, verifica GCM e integridad de la estructura y el Kardex.
  No adivina un dato clínico faltante ni convierte pendientes en dispensado.

### UX de restauración 2 fases

1. `Acceso clínico independiente → Restaurar respaldo completo de build 222`.
   **Elegir esta ruta ANTES de "Empezar solo con Excel PERSONAL"**.
2. Introducir la contraseña ORIGINAL, confirmar la procedencia y seleccionar el
   archivo desde Archivos. Autenticarse por Face ID/código.
3. Vista previa de recuentos de trabajadores, atenciones guardadas, borradores,
   rectificaciones, alergias, lotes, movimientos físicos, asociaciones,
   incidencias, conciliaciones y pendientes. **Fase 1 no escribe registros**.
4. Verificar respaldo en código por `SHA256` de la COPIA CIFRADA. Confirmar
   explícitamente. Volver a autenticar y descifrar el mismo archivo.
5. La activación solo admite la bóveda clínica **vacía** y rechaza si se alteró
   el archivo, es ilegible, tiene contraseña errónea, registros ficticios
   detectables, referencias huérfanas, movimiento Kardex inválido o fuente
   ya presente. `N2ProtectedClinicalVaultCore` guarda un snapshot completo en
   un solo journal cifrado; lee de nuevo y compara bytes y revisión.
6. Comparar recuentos previos y posteriores. La build 222, su Keychain y la copia
   de Archivos NO se borran ni se modifican.

### Advertencias y condiciones de aceptación

- La restauración desde backup completo y la importación inicial solo-PERSONAL
  crean **alternativas** a la primera fuente: **no se fusionan**. Si ya importaste
  PERSONAL en la bóveda clínica, no borres la base para restaurar otro archivo.
  Primero evaluar una migración específica con respaldo recuperable.
- Si el backup contenía consumos históricos sin entrega físicamente confirmada,
  deben seguir constando como pendientes (R no verificado) y requieren
  conciliación; no volver a descontarlos sin evidencia.
- `scripts/audit-n2-build222-backup-restore.cjs` comprueba los contratos
  de cifrado del TS original contra el lector Swift y las protecciones de la UI.
- `N2PortableBackupInteropTests` incorpora:
  contraseña errónea, hash distinto tras sustituir el archivo cifrado,
  recuentos de la fuente sintética completa (trabajadores, atenciones, lotes,
  movimientos y pendientes).
- **SIGUE PENDIENTE:** ejecutar estas pruebas nativas desde Xcode 16.2 y, en
  ambiente aislado y sin exponer el backup por chat/GitHub, revisar y restaurar
  el `.danperbackup` concreto que creó la build 222 del operador, comparar
  DNI, atenciones, consumos y movimientos de forma manual/automática. El
  cumplimiento criptográfico teórico NO demuestra aún que su archivo histórico
  pase todas las reglas clínicas del importador.
