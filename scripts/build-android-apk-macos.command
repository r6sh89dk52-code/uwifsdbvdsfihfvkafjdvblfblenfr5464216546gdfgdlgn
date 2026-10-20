#!/bin/bash
# Compilación local sin GitHub Actions. SOLO datos ficticios.
set -eo pipefail
cd "$(dirname "$0")/.."
echo "DANPER Build 222 -> Android APK (local)"
if ! command -v npm >/dev/null; then echo "Instala Node.js compatible."; exit 1; fi
if [ -z "$JAVA_HOME" ] && [ -x "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java" ]; then
  export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
fi
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
