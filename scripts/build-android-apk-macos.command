#!/bin/bash
# Compilación local sin GitHub Actions. SOLO datos ficticios.
set -eo pipefail
cd "$(dirname "$0")/.."
echo "DANPER Build 222 -> Android APK (local)"
if ! command -v npm >/dev/null; then echo "Instala Node.js compatible."; exit 1; fi
# Capacitor 7 compiles against Java 21; Gradle 8.11.1 cannot run with Java 25.
# Do not trust inherited JAVA_HOME (it may point to JDK 25).
# Select JDK 21 only for this script, without changing the Mac's global Java.
is_jdk21() {
  local candidate="$1"
  [ -n "$candidate" ] && [ -x "$candidate/bin/java" ] && [ -x "$candidate/bin/javac" ] || return 1
  local major
  major="$("$candidate/bin/java" -version 2>&1 | awk -F '"' 'NR==1 { split($2, a, "."); print a[1] }')"
  [ "$major" = "21" ]
}
jdk_candidates=(
  "${DANPER_JDK21_HOME:-}"
  "${JAVA_HOME:-}"
  "$HOME/Library/Application Support/DANPER/jdk-21/Contents/Home"
  "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  "/Applications/Android Studio Preview.app/Contents/jbr/Contents/Home"
  "$HOME/Applications/Android Studio.app/Contents/jbr/Contents/Home"
  "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
  "/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
)
if [ -x /usr/libexec/java_home ]; then
  jdk_candidates+=( "$(/usr/libexec/java_home -v 21 2>/dev/null || true)" )
fi
selected_java=""
for candidate in "${jdk_candidates[@]}"; do
  if is_jdk21 "$candidate"; then selected_java="$candidate"; break; fi
done
if [ -z "$selected_java" ]; then
  echo "ERROR: no se encontró JDK 21. Gradle 8.11.1 NO puede ejecutarse con Java 25."
  echo "Sin Homebrew: ejecuta bash scripts/install-jdk21-macos.command"
  echo "También puedes instalar manualmente JDK 21 desde Eclipse Temurin."
  echo "Después repite este mismo script. NO necesitas cambiar Java globalmente."
  if [ -x /usr/libexec/java_home ]; then /usr/libexec/java_home -V 2>&1 || true; fi
  exit 1
fi
export JAVA_HOME="$selected_java"
export PATH="$JAVA_HOME/bin:$PATH"
echo "JDK 21 seleccionado para esta compilación: $JAVA_HOME"
"$JAVA_HOME/bin/java" -version 2>&1 | head -n 1
if [ -z "$ANDROID_HOME" ] && [ -d "$HOME/Library/Android/sdk" ]; then
  export ANDROID_HOME="$HOME/Library/Android/sdk"
fi
if [ -z "$ANDROID_HOME" ] && [ -d "$HOME/Android/Sdk" ]; then
  export ANDROID_HOME="$HOME/Android/Sdk"
fi
if [ -z "$ANDROID_HOME" ] || [ ! -d "$ANDROID_HOME" ]; then
  echo "Instala Android Studio y SDK (API 35), configura ANDROID_HOME."; exit 1
fi
node scripts/check-android-port.cjs
npm ci --no-fund --no-audit
# No se cambia package.json ni package-lock: se preserva build iOS.
npm install --no-save --package-lock=false --no-fund --no-audit @capacitor/android@7
npm run test:logic
npm run build
if [ ! -f android/gradlew ]; then
  npx --no-install cap add android
fi
npx --no-install cap sync android
node scripts/harden-android-manifest.mjs
(cd android && chmod +x ./gradlew && ./gradlew --no-daemon :app:assembleDebug)
APK="android/app/build/outputs/apk/debug/app-debug.apk"
if [ ! -s "$APK" ]; then echo "No se ha generado el APK."; exit 1; fi
mkdir -p outputs/android
cp "$APK" "outputs/android/DANPER-Build222-Android-DEBUG.apk"
echo "APK generado: $(pwd)/outputs/android/DANPER-Build222-Android-DEBUG.apk"
shasum -a 256 outputs/android/DANPER-Build222-Android-DEBUG.apk
echo "Solo DEBUG para pruebas con datos ficticios: falta validar en Android físico."
