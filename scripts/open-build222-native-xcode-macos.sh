#!/usr/bin/env bash
# Local-only SwiftUI preparation; does not run GitHub Actions or erase simulator data.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "DANPER — preparación local de réplica nativa Build 222"
for cmd in node npm xcodegen xcodebuild; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FALTA: $cmd. Instálalo/configúralo antes de continuar." >&2
    exit 1
  fi
done
if [ ! -d "native-ios/App" ] || [ ! -f "native-ios/project.yml" ]; then
  echo "No se encontró el proyecto SwiftUI." >&2
  exit 1
fi
echo "1/3 — Instalando dependencias para recursos locales"
npm ci
echo "2/3 — Generando plantillas y catálogo; solo datos ficticios"
node scripts/prepare-n1s-ios-demo-resources.cjs
echo "3/3 — Regenerando proyecto XcodeGen"
(
  cd native-ios
  xcodegen generate --spec project.yml
)
echo "Listo. En Xcode selecciona DANPERNative, iPhone 16 Pro, Debug."
echo "Esta preparación no acredita paridad funcional ni ejecuta tests."
open "$ROOT/native-ios/DANPERNative.xcodeproj"
