# DANPER Salud Móvil — SwiftUI Native (migración gradual)

**Estado:** Etapa N0: fundamento SwiftUI en paralelo a la build 222. **NO ES UNA APP CLÍNICA OPERATIVA.** No reemplazar ni desinstalar la app anterior ni restaurar una base real sobre ella.

## Lo que sí implementa
- SwiftUI 100 % nativo, sin React/WebView/Capacitor para este nuevo ejecutable.
- Bundle ID **independiente** `pe.danper.saludmovil.native.preview`, con Face ID o código del iPhone y bloqueo al salir.
- Interfaz de cuatro pestañas (Inicio, Atención de prueba, simulación FEFO, Respaldo).
- Modelos Swift puros y pruebas `swift test` para orden FEFO, multilote, fechas, cantidades, aperturas CJA 1/0, atenciones antiguas declaradas.
- Lector **únicamente de inspección**, local y en memoria, para el formato cifrado de respaldo v0.21.12: PBKDF2-SHA256 (310000 iteraciones) + AES-256-GCM (CryptoKit/CommonCrypto). Valida la contraseña y muestra solo cantidades agregadas de trabajadores, atenciones, lotes y movimientos; no importa ni escribe datos.

## Por implementar antes de operar
1. Auditoría de interoperabilidad binaria con el respaldo original y restauración **transaccional**, con test de interrupción/rollback y comparación íntegra de registros.
2. Escritura cifrada nativa (Keychain + archivos privados / protección iOS), migración controlada de la app existente.
3. Formulario real de atención, historial, trabajadores, alergias y guardado atómico de atención + stock.
4. Equivalencias de los 432 códigos clínicos con Kardex 98, FEFO 1/0 exacto, movimientos auditables, reintentos idempotentes y saldos.
5. Reproducción nativa verificada del Indicador oficial de diez hojas y del Kardex original, fórmulas y formatos.
6. Prueba de instalación física, actualización segura, Face ID, datos anteriores y efectos de SideStore.

## Desarrollo
Linux/macOS (solo lógica):
```sh
cd native-ios
swift test
```
Mac con Xcode 16 y [XcodeGen](https://github.com/yonaskolb/XcodeGen):
```sh
cd native-ios
bash scripts/make-app-icon.sh
xcodegen generate --spec project.yml
xcodebuild -project DANPERNative.xcodeproj -scheme DANPERNative -destination 'generic/platform=iOS' -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```
El ejecutable de prueba se debe firmar con la identidad correspondiente antes de instalarse. **Nunca** debe utilizar el bundle ID de la aplicación clínica existente mientras no se haya validado la migración.

## Criterio de aceptación
No considerar la migración completa hasta que los test nativos y cruzados con la app heredada confirmen preservación exacta de cada consumo, stock/lote, historial, alergias, borradores, Kardex y Excel; no hay acceso a datos reales ni sobrescritura implícita.

## Etapa N1a — almacenamiento aislado de prueba

La pestaña «Laboratorio» comprueba escritura/lectura cifrada de **un contador ficticio** usando CryptoKit y Keychain independientes. No carga, importa ni modifica datos clínicos. El núcleo añade validación de colecciones del respaldo antes de una futura restauración. Detalles y condiciones en `docs/N1A_SEGURIDAD_Y_PENDIENTES.md`.

## Etapa N1b (Linux exclusivamente; sin IPA)

El núcleo Swift ahora incluye verificación de respaldo AES-256-GCM compatible con la generación TypeScript mediante Apple Swift Crypto. Las pruebas Linux producen archivos **ficticios** temporales desde `src/portableBackup.ts` y comparan autenticidad, digest de texto claro, estructura, daños y contraseña incorrecta. El simulador de restauración es puramente de pruebas; **no permite importar trabajadores o atenciones reales**. Consultar `docs/N1B_COMPATIBILIDAD_LINUX.md`.

## N1c — Journal de generación persistente (solo Linux)

El paquete Swift ahora incluye `N1DurableRestoreSandbox`, exclusivo de tests ficticios con `N1-CANARY|`, carpetas temporales, dos archivos por generación, hashes SHA256, diario persistente, un puntero de activación y reanudación tras interrupciones simuladas. **No almacena registros reales y no implementa aún restauración clínica.** Véase `docs/N1C_JOURNAL_LINUX.md`.

## N1d — Ensayo de almacenamiento cifrado con generaciones recuperables (Linux)

`N1EncryptedGenerationLab` cifra datos sintéticos con AES-256-GCM, autentica manifiestos con HMAC-SHA256, obliga a verificar dos dominios antes de activar un puntero único y valida reinicios/fallos. Las claves se suministran por fuera; no hay acceso a datos clínicos ni integración con iOS Keychain todavía. Revisa `docs/N1D_GENERACIONES_CIFRADAS.md`. No genera IPA.

## N1e — Validación de paridad clínica y Kardex (solo lectura, Linux)

`N1eLegacyClinicalAudit` verifica los consumos, stock por lotes y grupos FEFO conforme a las reglas originales TS, conservando `R=0` frente a `R=nil`. Pruebas generadas sintéticamente por código TS de la build 222, sin pacientes reales y sin IPA. Ver `docs/N1E_PARIDAD_CLINICA_STOCK.md`.

## N1f — Comprobación 1:1 de campos de atención, padrón y alergias

Fingerprint semántico completo JSON: protege borradores parciales, correcciones, alergias unknown/none/known y extensiones desconocidas sin reescribir registros. Pruebas Linux generadas desde esquemas originales TS y datos ficticios. Consultar docs/N1F_PRESERVACION_CAMPOS.md. Sin IPA ni restauración real.

## N1g — SwiftUI real: padrón, atención y borradores ficticios

Implementación de UI SwiftUI de cinco pestañas y estado compartido de sesión `N1gClinic`, exclusiva de personas ficticias y sin persistencia clínica. Reglas de corrección, alergias y guardado simulado comprobadas en Linux; solo sintaxis de SwiftUI validada en Linux, **compilación real iOS pendiente**. Ver `docs/N1G_PANTALLAS_SWIFTUI.md`. No se genera IPA.

## N1h — Formulario guiado con paridad de reglas TypeScript

Se agregaron sistemas/segmentos de evaluación, horario, permiso, procedimientos independientes y marcadores sin fotografía al formulario SwiftUI ficticio; el validador Swift usa las mismas reglas que `src/attentionStepValidation.ts`, probadas con 16 escenarios sintéticos. Ver `docs/N1H_FORMULARIO_GUIADO.md`. Sigue sin guardar datos reales, sin compilar app iOS y sin generar IPA.

## N1i — Borradores ficticios cifrados y recuperables

El motor Swift incluye AES-256-GCM y puntero autenticado para guardar exclusivamente datos inventados. La interfaz de prueba incorpora un adaptador iOS a Keychain **separado**, guardado diferido de 650 ms y recuperación al abrir. La app de producción no se toca. Las pruebas Linux no sustituyen la compilación iOS con Xcode. Consultar docs/N1I_BORRADORES_CIFRADOS.md. Sin macOS ni IPA.

## N1j — Guardado ficticio ordenado por revisión autenticada

A partir de N1i, cada generación cifrada almacena una revisión v2 con HMAC. Revisión recuperada al iniciar, snapshots monotónicos, protección contra tareas retrasadas y diez regresiones Linux. La solicitud inmediata al pasar a segundo plano sigue siendo best-effort; requiere validación en Xcode/iPhone. Ver `docs/N1J_AUTOGUARDADO_REVISIONES.md`. Sin datos clínicos reales y sin IPA.

## N1k — Auditoría SwiftUI/Xcode y bienvenida profesional

La introducción nativa de primer inicio solicita voluntariamente notificaciones y biometría, permite omitirlas y explica el acceso local a archivos. El acceso a respaldo cifrado real es **solo lectura**; no hay migración de pacientes todavía. Se audita la compilación Xcode sin firma en simulador y dispositivo genérico, sin generar IPA ni sustituir la build 222. Detalles: `docs/N1K_AUDITORIA_XCODE_ONBOARDING.md`.

## N1l — Solo fuente real, sin mezclar datos ficticios

Se amplió la lectura local del `.danperbackup` con auditoría completa de **nueve colecciones** (padrón, atenciones, alergias, avisos, lotes, movimientos, equivalencias, incidencias, conciliaciones); recuento de borradores/correcciones y vínculos pendientes. Bloqueo de destino ocupado o desconocido, marcadores ficticios reconocibles y duplicados. **No existe importador ni escritura de datos reales en N1l**: revisar `docs/N1L_PLAN_CERO_MEZCLAS.md`. El inspector nunca almacena registros reales ni mezcla con N1g. El cifrado no permite distinguir ficticios sin marcadores; un origen combinado requiere depuración de procedencia humana antes de migrar.

## N1m — Bóveda de preparación cifrada con origen único

Se añadió almacenamiento cifrado independiente de preparación de la base auténtica de build 222, pero todavía **sin conexión al selector ni activación clínica**. Incluye recibo HMAC, verificación de hashes y conservación 1:1, reanudación tras interrupciones sin mezclar fuentes y un servicio Keychain independiente. Sigue siendo una etapa de preparación sin instalación y sin IPA. Ver `docs/N1M_BOVEDA_STAGING_REAL.md`.
