# DANPER Salud Móvil v0.21.11 — CANDIDATA build 221 (NO INSTALAR AÚN)

Esta candidata conserva en cascada:
- PR #55: release v0.21.10 build 220 verificada en iPhone.
- PR #56: exportación provisional cuando hay salidas clínicas sin movimiento verificable.
- PR #57: finalización de atención con descuentos automáticos, FEFO multilote y auditoría cruzada del Excel de 10 hojas y del Kardex original de 98 productos.
- Este PR: preparación estricta de actualización de la build 220 a la build **221**, sin macOS ni IPA en esta etapa.

## Identidad y esquema: prohibido alterar
- Bundle ID: `pe.danper.saludmovil.prototipo`, exactamente el de build 220.
- No se cambian los identificadores de Keychain (`prototype-snapshot-v1` ni las claves de bóvedas clínicas y padrón).
- No se cambian los directorios cifrados privados, identificadores de lote, movimiento ni la representación de las atenciones anteriores.
- No se activa migración ni limpieza automática de registros, inventario o borradores al abrir la nueva versión.
- El catálogo oficial de **98 productos del Kardex**, **432 códigos del Indicador** y **86 asociaciones revisadas** permanecen integrados.
- Diferenciar **catálogo cargado** de **cantidades de inventario conocidas**. Ausencia de stock previo nunca equivale a stock cero.

## Evidencias Linux requeridas
- `npm ci --no-fund`
- `npm run test:logic`, incluidas las nuevas:
  - `scripts/test-upgrade-221-preservation.cjs`: simula un snapshot previamente poblado, una entrega FEFO con dos partes y una atención anterior sin conciliación. Comprueba continuidad y ausencia de descuentos retroactivos, cambios de esquema o de app ID.
  - `scripts/test-cross-device-encrypted-restore.cjs`: cifrado AES-GCM real en dos dispositivos iOS simulados, pero con movimientos FEFO multilote reales y un vínculo clínico. Comprueba contraseña errónea, restauración en destino vacío, reinicio, bloqueo de sobrescritura y fallo de escritura.
  - `scripts/test-fefo-cross-report-audit.cjs`: compara ambos archivos Excel generados desde las plantillas oficiales incrustadas, incluidos R, D/E/F/G/H, aperturas 1/0, fórmulas y dos sedes.
- `npm run build` (TypeScript + Vite).
- `npm audit --audit-level=high`.
- `npm run ios:check` sin ejecutar Xcode.
- La plantilla oficial y los formatos Excel continúan sin incluir archivos de pacientes ni archivos XLSX brutos en un futuro IPA.

## Condiciones obligatorias antes de solicitar la PRIMERA compilación macOS
1. **GitHub Linux PASS** de la última revisión del PR candidato y sus PR dependientes.
2. El usuario debe confirmar que su iPhone sigue en v0.21.10 build 220 con el mismo Bundle ID. Nunca instalar una build menor ni cambiar el identificador.
3. En el iPhone **antes de actualizar**, crear y compartir por Archivos un `.danperbackup` cifrado con contraseña independiente (14+ caracteres). Guardarlo fuera del directorio de la aplicación, preferiblemente en dos ubicaciones accesibles. No compartir el archivo ni la contraseña por GitHub.
4. Comprobar que el archivo existe y que se puede seleccionar y descifrar sin restaurarlo sobre el iPhone actual. Anotar fuera del chat: cantidad de trabajadores, atenciones, lotes, movimientos y fecha de la copia.
5. No crear ni alterar atenciones solo para forzar el Excel. Los consumos históricos pendientes se preservarán, sin descuento retroactivo automático.
6. Autorizar explícitamente una sola ejecución manual de `.github/workflows/ios-ipa.yml` usando la **rama candidata validada**, no `main` ni versiones anteriores.
7. El IPA generado sería **sin firmar**. La instalación física, firma por SideStore, Face ID, notificaciones en segundo plano y comportamiento de iOS siguen pendientes de validación.
8. Si la instalación solicita borrar datos, eliminar/reinstalar la app o usar un Bundle ID diferente, **DETENER** y pedir auditoría; no seguir.

## Checklist en el iPhone tras autorizar una futura IPA
- Primer arranque: Face ID solo una vez, bienvenida e inicio disponibles.
- Confirmar coincidencia de conteos de trabajadores, atenciones, alergias, lotes, movimientos, borradores, conciliaciones y notificaciones con los datos anteriores.
- Abrir al menos dos atenciones **ya guardadas** y verificar que NO se descuentan nuevamente al consultarlas o corregir campos permitidos.
- Confirmar que las salidas antiguas sin inventario histórico siguen pendientes y no se transforman en movimientos nuevos.
- En datos ficticios separados, cerrar una atención con FEFO 2+3 para una cantidad total 5: deben generarse 2 movimientos de lote y 1 fila clínica.
- Comprobar frascos/cajas: primera apertura R=1, usos posteriores R=0. No asumir capacidades de envases si faltan.
- Exportar los 2 Excel con datos ficticios o anonimizados, verificar fórmulas, valores por sede y saldo.
- Probar respaldo/recuperación **únicamente en una instalación vacía separada**, si se dispone de ella; no sobreescribir la base del equipo principal.
- Comprobar que las notificaciones sigan funcionando sin exponer datos clínicos.

## Si una actualización falla
- NO desinstalar, borrar datos, reiniciar el inventario ni experimentar con una IPA anterior.
- Preservar inmediatamente el archivo `.danperbackup` externo y la contraseña.
- Guardar solo capturas anonimizadas del error y su fecha; no publicar nombres ni registros clínicos.
- Una recuperación desde respaldo debe hacerse **en una base vacía**, verificando todos los conteos y movimientos. No mezclar dos bases ni simular saldos.
- No garantizar rollback automático: el firmado de SideStore, archivos privados y Keychain deben revisarse físicamente antes de tomar una decisión.

## Estado de esta candidata
**Código preparado únicamente para validación en Linux.** Ninguna prueba automatizada demuestra que SideStore conserve en la práctica las bóvedas nativas: eso solo podrá confirmarse físicamente en el iPhone.
