# Android — DANPER Salud Móvil Build 222

## Estado
Rama independiente: feat/android-build222-local-apk-20261020.
Referencia INTACTA: release/v0.21.12-build222-provisional-consumptions (commit 09fef294d73f6a1c655dc42865b6fa5c5e1f792a). No modificar main ni SwiftUI B11.

## Compilar en Mac SIN GitHub Actions
Requisitos: Node.js compatible con package.json, Android Studio compatible con Capacitor 7, Java 21, SDK Android API 35, conectividad a npm/Gradle.

En el terminal del Mac:

    git clone https://github.com/r6sh89dk52-code/danper-salud-movil-pruebas.git
    cd danper-salud-movil-pruebas
    git fetch origin feat/android-build222-local-apk-20261020
    git switch --track origin/feat/android-build222-local-apk-20261020
    bash scripts/build-android-apk-macos.command

Si el repositorio YA está clonado, no lo clones otra vez. Entra a su carpeta, comprueba git status y realiza el fetch/switch de la rama nueva. No cambies de rama con cambios locales sin guardar.

El script ejecuta npm ci, instala @capacitor/android@7 solo localmente (sin modificar lock/package de iOS), ejecuta test:logic, compila React/TypeScript, genera el proyecto Android si falta, sincroniza Capacitor, refuerza el manifiesto y compila Gradle.

APK DEBUG de salida: outputs/android/DANPER-Build222-Android-DEBUG.apk

Puedes transferirlo al Android e instalarlo manualmente o utilizar adb install -r outputs/android/DANPER-Build222-Android-DEBUG.apk con el dispositivo autorizado para depuración.

## Protección de datos
Android reutiliza la bóveda AES-256-GCM y claves guardadas con el plugin de almacenamiento seguro que se apoya en Android Keystore. Se deshabilita backup automático y se excluyen datos en reglas de extracción del sistema (en algunos fabricantes la migración puede diferir). Sin backend ni sincronización automática.
El archivo cifrado .danperbackup es un respaldo MANUAL entre iOS y Android; restaurar solo en base vacía, con contraseña y confirmación. Esta función tampoco está validada en Android físico.
No almacenar datos de trabajadores ni pacientes reales mientras falten validación del APK, bloqueo de acceso en Android, revisión de privacidad, restauración, FEFO, exportación Excel y pruebas reales de persistencia. No subir datos reales, contraseñas ni archivos .danperbackup al repositorio.

## Pruebas con información FICTICIA
1. Abrir e iniciar app en Android; verificar que no se usa localStorage para datos clínicos.
2. Importar padrón de prueba y registrar una atención con consumo confirmado.
3. Reiniciar aplicación y dispositivo; comprobar persistencia cifrada.
4. Exportar Kardex e Indicador Ambulatorio a Excel y comparar con Build 222.
5. Crear respaldo cifrado en iPhone e importar al Android vacío, verificar recuentos.
6. Verificar error de contraseña de respaldo y que no se borran registros.
7. Verificar navegación, teclado, notificaciones y permisos.

## Sincronización en etapa posterior
La futura sincronización segura iOS–Android requiere backend autorizado, autenticación, permisos, cifrado, auditoría por cambios, modo sin conexión y resolución de conflictos en movimientos y consumos. Nunca habilitarla sin pruebas.
