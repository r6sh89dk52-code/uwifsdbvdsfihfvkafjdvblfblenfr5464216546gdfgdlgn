# DANPER Salud Móvil — v0.7: compilación iOS de prueba

Este paquete es una **actualización acumulativa de v0.6**. Conserva los módulos web que ya se probaron y añade configuración para generar un **IPA sin firmar** utilizando Xcode, preferiblemente con GitHub Actions y un repositorio privado.

**IMPORTANTE: Este ZIP NO contiene un .ipa ya compilado.** El IPA solo aparecerá al terminar correctamente el trabajo de macOS. No se necesita una Mac local si utilizas GitHub Actions. SideStore podrá intentar firmarlo e instalarlo en el iPhone; la instalación efectiva debe probarse.

## Opción recomendada: GitHub Actions desde Windows

1. En tu cuenta GitHub crea un repositorio **PRIVADO**, por ejemplo `danper-salud-movil-pruebas`. No lo hagas público: el código incluye un perfil de responsable preconfigurado, cuya identidad no debe publicarse.
2. Descomprime este ZIP. El archivo `package.json` debe quedar en la raíz del repositorio, junto a `capacitor.config.ts` y la carpeta `.github`.
3. Sube al repositorio los archivos del proyecto, incluida **`.github/workflows/ios-ipa.yml`**, `resources` y `scripts`. NO subas bases de trabajadores, atenciones, Excel reales, `node_modules`, ni la carpeta `dist`.
4. En GitHub abre **Actions** > **DANPER Salud Movil - IPA de pruebas** > **Run workflow** > **Run workflow**.
5. Espera a que la acción termine. En el resumen del trabajo busca **Artifacts**, descarga `DANPER-Salud-Movil-iPhone-v0.7` y descomprime el artifact: encontrarás `DanperSaludMovil-v0.7.0-SIN_FIRMAR.ipa` y el archivo `.sha256`.
6. Transfiere el `.ipa` a tu iPhone. Desde SideStore puedes seleccionar el IPA para que SideStore lo firme e instale, sujeto a sus requisitos y limitaciones de tu Apple ID.

**Nunca compartas contraseñas, llaves de firma ni tu Apple ID conmigo ni los subas al repositorio.** No se necesitan credenciales de Apple para generar este IPA **sin firmar** en GitHub Actions.

## Opción alternativa: compilación local en Mac

```bash
npm install
npm run test:logic
npm run build
npx cap add ios
npx cap sync ios
bash scripts/build-ios-ipa.sh
```

Se necesita Xcode compatible con Capacitor 7 y CocoaPods. La salida aparece en `outputs/*.ipa` (sin firma).

## Comprobaciones en Windows (no generan IPA)

En PowerShell, desde la carpeta con `package.json`:

```powershell
npm install
npm run test:logic
npm run ios:check
npm run build
npm audit
```

## Límites estrictos de v0.7

- **SOLO PRUEBAS CON DATOS FICTICIOS.** Trabajadores, atenciones y alergias continúan en **localStorage SIN CIFRAR**. Compilar a IPA no lo vuelve seguro.
- No existe todavía SQLite cifrada, protección de claves con Keychain ni prueba de restauración de copias de seguridad.
- Las notificaciones nativas requieren permiso explícito en iOS y aún deben comprobarse en un iPhone real.
- La exportación Excel fiel, Kardex diario y el tratamiento de F/S (Falta/Sobra) continúan pendientes de futuras etapas.
- La compilación de iOS puede requerir ajustes según la versión de Xcode y del entorno; no se ha ejecutado `xcodebuild` en este entorno Linux.
- El identificador del bundle `pe.danper.saludmovil.prototipo` es PROVISIONAL y debe ajustarse si se publica formalmente o pertenece a una organización.
- Para una nueva compilación posterior a un cambio en React, debe ejecutarse de nuevo `npm run build` y `npx cap sync ios`.

## Reglas de privacidad

Evita sincronizar datos reales a servicios externos. El flujo de GitHub compila **solamente fuentes**; no debe cargar ficheros Excel de trabajadores. Utiliza un repositorio privado.

## Prueba en iPhone

Al instalar, comprobar: logotipo, modo claro/oscuro, formulario, diagnósticos, lista de medicamentos, borradores, alerta interna, permisos de notificaciones. No introducir información real.
