# N1o — ensayo de transacción clínica cifrada, SIEMPRE INACTIVO

## Punto de partida
N1n PR #76: 129/129 pruebas Swift Linux y compilaciones Xcode iOS Simulator + iPhone genérico sin firma. Esta rama hereda esa versión sin tocar la build 222, `main` ni la release.

## Qué demuestra el ensayo N1o
- El núcleo `N1oInactiveTransactionLab` solo admite un subdirectorio `danper-n1o-synthetic-*` del directorio temporal del sistema. No existe adaptador de iPhone, ruta desde SwiftUI, importación de pacientes ni acceso a Keychain clínico.
- Acepta únicamente snapshots estructuralmente completos y revisables según las puertas N1n y N1l; conserva todas las nueve colecciones, campos futuros, borradores, correcciones y consumos no conciliados. Produce SHA-256 semántico del árbol completo y hashes + recuentos independientes por colección.
- **Fase 1:** AES-256-GCM del snapshot íntegro, verificación de descifrado, y journal firmado con HMAC-SHA256. No se persiste texto clínico en claro.
- **Fase 2:** renombrado del ciphertext validado y escritura atómica del puntero **`inactive-verified.json`**. Este puntero es exclusivamente del ensayo: jamás lo lee la aplicación médica. `canActivate=false` permanece constante.
- Si la ejecución termina antes de escribir journal, el estado se bloquea como incompleto; no se borra el cifrado huérfano ni se adivina la fuente original.
- Interrupción después de journal: recuperación `pending` sin commit automático; después del renombrado, se revierte al estado pendiente; después del puntero inactivo, se verifica todo y se limpia el journal pendiente.
- Un snapshot diferente nunca reemplaza al primero. Clave errónea, corrupción de ciphertext/recibo, symlinks y directorios no autorizados provocan rechazo.
- Toda evidencia es **sintética** y se calcula de nuevo al recuperar. Este ensayo no valida durabilidad física ante pérdida abrupta de energía: `.atomic` no garantiza `fsync`, tampoco existe bloqueo interproceso. La restauración clínica definitiva no está implementada.

## Pruebas nuevas
13 pruebas Linux sobre transiciones interrumpidas y reinicios, integridad de nueve dominios, cambios de campos futuros, conflictos y protección contra corrupción. Incluye las 129 anteriores, sin registros reales.

## Puertas todavía pendientes
1. Validación de procedencia real del respaldo de build222 en el iPhone.
2. Comprobación clínica 1:1 de inventario, FEFO, consumo por producto y las diez hojas del Excel oficial.
3. Almacén definitivo cifrado, con atomicidad y durabilidad real (sincronización física, bloqueo y recuperación) **antes** de habilitar pacientes y movimientos.
4. Ensayos en iPhone físico. No generar ni instalar IPA en N1o.
