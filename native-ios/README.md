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
