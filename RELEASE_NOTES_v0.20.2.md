# DANPER Salud Móvil v0.20.2 — migración clínica sólo con respaldo verificado

Base: v0.20.1 PR #27 (cifrado clínico y recuperación) y funcionalidad validada hasta v0.19.3. No hay archivos reales ni contraseñas en GitHub o IPA.

## Regla de seguridad principal
La v0.20.1 migraba automáticamente el primer arranque. v0.20.2 **lo prohíbe**. Si el iPhone conserva datos anteriores detectados desde Keychain y el padrón privado, muestra una pantalla ANTES de cargar cualquier módulo y requiere seleccionar un archivo .danperbackup externo, escribir su contraseña original y verificar que su contenido coincida campo a campo con trabajadores, atenciones, alergias, lotes, movimientos, equivalencias y conciliaciones actuales.

Sólo ante coincidencia exacta inicia la migración; se verifica el estado clínico cifrado tras el cambio y se conserva una copia de la información previa en Keychain. Un archivo alterado, contraseña incorrecta o respaldo antiguo NO modifica la base. Si ya existe el almacén cifrado, no lo migra una segunda vez. No deduce sexo por nombres ni elimina trabajadores ficticios mezclados.

## Pruebas
- Actualización de test-secure-store y test-private-clinical-vault para garantizar que abrir sin autorización rechaza migración.
- test-verified-clinical-migration.cjs: contraseña incorrecta, respaldo antiguo con menos trabajadores, estado Keychain inalterado ante fallos, migración explícita, preservación del snapshot anterior y segunda apertura.
- Mantener protocolos de v0.20.1: restauración sólo en base vacía, journal de recuperación y cifrado AES-GCM.

## No declarar producción
Pendientes: prueba en iPhone real de migración SIN desinstalar, comparación con respaldo guardado fuera del dispositivo, reinicio y conteos; prueba completa de restauración en un dispositivo vacío, control de acceso Face ID/PIN y auditoría de seguridad antes de usar historiales clínicos identificables. No fusionar main ni instalar sobre datos reales antes de validar requisitos y copias externas.
