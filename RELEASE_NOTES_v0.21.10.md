# DANPER Salud Móvil v0.21.10 — build iOS 220

## Alcance del candidato
Actualiza la v0.21.9/build 219 **sin desinstalar**. Los PR #52, #53 y #54 están incluidos en esta rama, además del cierre consolidado de v0.21.9:
- Un inventario físico y Kardex general para Fundo LA VENTUROSA y Planta PLVENTUROSA. Un único Indicador Ambulatorio de 10 hojas. Cada atención conserva sede y mapeo de código organizativo por fila.
- RESU: **M (COMENTARIO)** vacío para completar justificativos después de descargar; **K** proyección manual y **L** fórmula de requerimiento; las fórmulas E, F, G, H, I, J y L quedan intactas.
- Avisos locales de borradores con datos a los 60 minutos, sin DNI ni información de trabajadores. Ignora borradores vacíos, cancela los avisos de registros guardados o borrados y limita las programaciones pendientes a 50. Requiere permiso de notificaciones y prueba real con pantalla bloqueada.
- Restauración del respaldo con campo de contraseña **distinto** del usado para crear una copia; no se permite restaurar sobre una base que ya contenga datos y no se modificó el cifrado.

## Verificación de actualización
Se mantiene exactamente `appId: pe.danper.saludmovil.prototipo`. Entre la rama v0.21.9 previamente probada y esta candidata permanecen idénticos (mismo SHA de contenido):
- `src/secureDemoStore.ts`
- `src/privateWorkerVault.ts`
- `src/privateClinicalVault.ts`
- `src/portableBackup.ts`
- `src/attentionKardex.ts`
- `src/sharedInventoryReports.ts`
- `capacitor.config.ts`

No cambian claves Keychain, rutas de almacenamiento, algoritmos de cifrado, lógica de lotes, reglas de entrega ni identificador de la app. El número de versión pasa de 0.21.9 a **0.21.10** y CFBundleVersion de **219 a 220**. *La compatibilidad en SideStore/iOS se considera provisional hasta instalar el IPA sobre la versión 219 sin desinstalar y verificar persistencia.*

## Compilación: una sola ejecución manual tras PASS Linux
- No ejecutar el workflow iOS hasta que el PR de cierre tenga **CI Linux completo PASS**.
- `.github/workflows/ios-ipa.yml` solo admite `workflow_dispatch`, nunca inicia macOS automáticamente en PR/push.
- En GitHub Actions > **DANPER Salud Movil - IPA de pruebas** > **Run workflow**, elegir exactamente la rama `release/v0.21.10-build220-single-ipa`, pulsar **Run workflow** una vez.
- Descarga el artefacto `DANPER-Salud-Movil-iPhone-v0.21.10-BUILD-220-PRUEBAS-CIERRE`. Dentro estará `DanperSaludMovil-v0.21.10-SIN_FIRMAR.ipa` y su `sha256`. El workflow verifica bundle ID, versión 0.21.10, build 220, ARM64, Face ID, la plantilla Kardex incrustada y SHA256.
- No cambiar `main` ni fusionar los PR antes de probar en iPhone la actualización.

## Validaciones finales en iPhone
1. Antes de instalar, crear una copia cifrada, guardarla en **Archivos** fuera del almacenamiento temporal de la app y confirmar que se puede volver a localizar y que se conoce su contraseña.
2. Instalar **encima** de v0.21.9 usando el mismo identificador y SideStore. Si SideStore pide eliminar la app, **DETENERSE**: nunca desinstalar sin recuperación verificada.
3. Abrir con Face ID y comprobar que trabajadores, sedes, áreas, atenciones, borradores, lotes, Kardex, respaldos y preferencias anteriores siguen presentes.
4. Verificar que no haya selector de sede, generar un único Indicador Ambulatorio con 10 hojas, y que RESU!M sea editable y vacío, RESU!K permita proyección manual y las fórmulas funcionen al abrir en Excel. No crear consumos con stock ficticio sobre datos reales.
5. Con **solo datos ficticios**, crear un borrador con contenido, permitir notificaciones en Configuración, dejarlo 60 minutos y comprobar si aparece el aviso con el iPhone bloqueado. Guardarlo o borrarlo antes de los 60 minutos en otra prueba, y comprobar que no aparezca recordatorio obsoleto.
6. Confirmar la contraseña separada de restauración con un archivo de prueba, **sin restaurar sobre el iPhone que contiene datos**. La restauración real debe probarse exclusivamente en otra instalación vacía y controlada.
7. Si todo pasa, considerar el PR para fusión. Si hay cualquier anomalía, mantener la v0.21.9 y recopilar evidencia antes de otra compilación.

## Límites
El IPA es un prototipo experimental sin firmar, instalado mediante SideStore. Un PASS de Linux y Xcode no confirma comportamiento del llavero de iOS, notificaciones en segundo plano ni recuperación en un dispositivo físico: requieren comprobación manual. Esta entrega **no autoriza uso clínico de producción ni supone auditoría de privacidad institucional**.
