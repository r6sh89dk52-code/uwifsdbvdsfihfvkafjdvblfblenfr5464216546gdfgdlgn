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

## Error Gradle en Mac con Java 25 (major version 69)

Síntoma de la primera compilación local (20 de octubre de 2026):

    BUG! exception in phase 'semantic analysis' in source unit '_BuildScript_'
    Unsupported class file major version 69

Causa: se utilizó Java 25 para ejecutar Gradle 8.11.1. Capacitor 7 requiere JDK 21; no actualices Gradle/Capacitor para ocultar este conflicto.

**Corrección aplicada al script de esta rama**: ahora verifica JDK 21 y lo selecciona solo para esta ejecución, incluso cuando JAVA_HOME apunta a Java 25. Busca JDK 21 en Android Studio, java_home y Homebrew. Si falta, muestra instrucciones y sale antes de Gradle.

Como el repositorio YA está clonado en el Mac, se debe actualizar la rama sin borrar ni clonar de nuevo:

    cd ~/danper-salud-movil-pruebas
    git status --short
    git pull --ff-only origin feat/android-build222-local-apk-20261020
    bash scripts/build-android-apk-macos.command

Si el script responde 'no se encontró JDK 21', instala esa versión sin quitar Java 25; con Homebrew:

    brew install openjdk@21
    bash scripts/build-android-apk-macos.command

Alternativa: instalar el JDK 21 compatible con Android Studio y proporcionar su ruta mediante DANPER_JDK21_HOME. Comprobar la versión con $JAVA_HOME/bin/java -version dentro del shell de compilación, o verificar el mensaje 'JDK 21 seleccionado...' en el log.

El aviso npm de fsevents, el mensaje xmldom de un caso de prueba negativo y la advertencia de chunk JS >500kB NO causaron el fallo Java. Este último sí merece mediciones de rendimiento en el HONOR X5 Plus. El paso de pruebas lógicas no acredita todavía la fluidez física de Android.

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
