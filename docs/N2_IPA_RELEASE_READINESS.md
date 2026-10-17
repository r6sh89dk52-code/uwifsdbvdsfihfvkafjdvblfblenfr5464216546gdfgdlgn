# DANPER N2 - Preparacion segura del IPA

Esta rama sigue en evaluación. No se declara la paridad operativa con build222 ni se sustituye la aplicación instalada.

El script `scripts/build-native-preview-ipa-macos.sh` permite empaquetar localmente un **IPA sin firmar, solo para evaluación** sin consumir minutos de GitHub Actions.
Requiere macOS, Xcode, XcodeGen, Node/npm, la rama nativa y el consentimiento explícito `DANPER_PREVIEW_ACK=ACEPTO_SOLO_EVALUACION`.
Se verifica el identificador aislado `pe.danper.saludmovil.native.preview`, y la IPA contiene exclusivamente los recursos sintéticos saneados del proyecto. SideStore/AltStore deberá firmarla antes de instalar y aún no se ha comprobado su compatibilidad en iPhone físico.

### Pendiente antes de declarar IPA apta para trabajo
- Exportación de los dos libros Excel desde la misma bóveda clínica N2 verificada, conservando el original de 10 hojas, Kardex 98 y cortes correctos.
- Correcciones y borradores auditados, reconciliación de inventario por períodos y campos originales completos.
- Validación de restauración integral de las nueve colecciones, historial, alergias y movimientos físicos usando respaldo del usuario solo bajo consentimiento.
- Verificación de notificaciones en segundo plano y revisión final en Excel e iPhone físico.
- Mantener intactos `main`, la build222 híbrida y su Keychain.

### Implementación preparada
- Exportación cifrada `.danperbackup` AES-GCM con contraseña de al menos 14 caracteres, autentificación del dispositivo y hoja Compartir.
- Aviso nativo de borrador tras 60 min sin actividad, sin DNI, paciente ni diagnóstico en la notificación; cancelación al guardar.
- Procedimientos múltiples nativos con guardado auditado.

**No generar IPA operativa o firmada de producción mientras estas puertas sigan abiertas.**
