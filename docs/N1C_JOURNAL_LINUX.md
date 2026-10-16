# DANPER N1c — Journal de restauración persistente (SOLO Linux)

**Rama:** `native/swiftui-n1c-durable-journal-linux`, derivada de N1b. Pruebas Linux exclusivamente; no Xcode, no macOS, no IPA.

## Resultado técnico
- `N1DurableRestoreSandbox`: implementación real de **archivos persistentes en carpeta temporal**; restringida por nombre de directorio y prefijo binario `N1-CANARY|`.
- Dos archivos de *datos ficticios*, uno para padrón y otro para atenciones, más manifiesto de hashes SHA256 en `restore-journal.json`.
- Escritura y verificación de ambas mitades antes de crear el journal; activación mediante **una sola referencia** `active-generation.json` de forma atómica (copy-on-write).
- Al reiniciar, si nunca se activó la referencia, se abandona el journal sin exponer ninguna mitad; si ya se activó, se revalidan ambos archivos y se finaliza limpiando el journal. Doble recuperación es idempotente.
- Fallos inyectados después de la primera escritura, segunda escritura, persistencia del journal y escritura del puntero; alteración de datos y metadatos; rechazo al restaurar sobre una generación activa.
- No se eliminan archivos de generaciones ni se toca ningún directorio de la build 222. Los archivos de fases abortadas pueden quedar huérfanos para diagnóstico, pero jamás pasan a ser activos.
- Las pruebas N1b de compatibilidad cifrada TypeScript → Swift Crypto se siguen ejecutando contra fixtures ficticias dentro de `RUNNER_TEMP`.

## Seguridad y límites
Este código es un **ensayo de persistencia con datos sintéticos**, no una restauración clínica operativa. Los canarios son texto ficticio; **NO están cifrados**, por diseño deliberado: se evita crear una falsa sensación de seguridad clínica. No se admite un respaldo .danperbackup auténtico ni el directorio real de un iPhone.

No prueba garantías de `fsync`/pérdida física de energía o transacciones de Keychain iOS; `Data.write(.atomic)` modela reemplazo por nombre, no garantiza persistencia eléctrica. No existe aún soporte multi-proceso ni coordinación de acceso. Un ensayo contra iPhone real requiere integrar el adaptador cifrado iOS y ensayar fallo de escritura, firma y protección de datos antes de habilitar importación.

## Próxima etapa (N1d)
Definir capa de almacenamiento cifrado nativo con generaciones indivisibles y journal compatible, validar 1:1 el respaldo clínico sobre fixtures anonimizadas/sintéticas, límites reales de 500 lotes/1000 movimientos y reglas de consistencia FEFO. Reservar macOS para una compilación conjunta autorizada; no generar una IPA en cada iteración.
