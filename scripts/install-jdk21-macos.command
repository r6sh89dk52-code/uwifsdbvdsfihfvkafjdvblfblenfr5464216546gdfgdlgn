#!/bin/bash
# Descarga Temurin JDK 21 de Eclipse Adoptium SIN Homebrew, sudo ni cambios globales.
# Solo instala en ~/Library/Application Support/DANPER/jdk-21.
set -euo pipefail
if [ "$(uname -s)" != "Darwin" ]; then
  echo "Este instalador está diseñado únicamente para macOS."; exit 1
fi
case "$(uname -m)" in
  arm64) ARCH="aarch64" ;;
  x86_64) ARCH="x64" ;;
  *) echo "Arquitectura de Mac no compatible: $(uname -m)"; exit 1 ;;
esac
ROOT="$HOME/Library/Application Support/DANPER"
DEST="$ROOT/jdk-21"
if [ -x "$DEST/Contents/Home/bin/java" ]; then
  if "$DEST/Contents/Home/bin/java" -version 2>&1 | grep -Eq 'version "21[.]'; then
    echo "JDK 21 ya disponible: $DEST/Contents/Home"
    "$DEST/Contents/Home/bin/java" -version
    exit 0
  fi
  echo "Ya existe otra versión de JDK en $DEST. No se sobreescribe."; exit 1
fi
if [ -e "$DEST" ]; then
  echo "La ruta de destino ya existe. No se sobreescribe: $DEST"; exit 1
fi
if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
  echo "Faltan las herramientas curl o tar de macOS."; exit 1
fi
mkdir -p "$ROOT"
TMP="$(mktemp -d "$ROOT/.jdk21-XXXXXXXX")"
trap 'rm -rf "$TMP"' EXIT
URL="https://api.adoptium.net/v3/binary/latest/21/ga/mac/$ARCH/jdk/hotspot/normal/eclipse"
echo "Descargando JDK 21 oficial de Eclipse Adoptium para Mac ($ARCH)..."
curl --fail --location --retry 3 --connect-timeout 20 --proto '=https' --tlsv1.2 --output "$TMP/jdk21.tar.gz" "$URL"
mkdir "$TMP/extract"
echo "Extrayendo Java 21 en un directorio privado del usuario..."
tar -xzf "$TMP/jdk21.tar.gz" -C "$TMP/extract"
JAVA_FILE="$(find "$TMP/extract" -type f -path '*/Contents/Home/bin/java' -print -quit)"
if [ -z "$JAVA_FILE" ]; then
  echo "El paquete recibido no contiene un JDK macOS válido."; exit 1
fi
JDK_HOME="$(dirname "$(dirname "$JAVA_FILE")")"
if [ ! -x "$JDK_HOME/bin/javac" ]; then
  echo "El archivo descargado no contiene un JDK completo."; exit 1
fi
if ! "$JDK_HOME/bin/java" -version 2>&1 | grep -Eq 'version "21[.]'; then
  echo "La versión de Java descargada NO es 21. No se instalará."; exit 1
fi
BUNDLE="$(dirname "$(dirname "$JDK_HOME")")"
mv "$BUNDLE" "$DEST"
echo "JDK 21 instalado sin Homebrew: $DEST/Contents/Home"
"$DEST/Contents/Home/bin/java" -version
echo "Ya puedes ejecutar: bash scripts/build-android-apk-macos.command"
