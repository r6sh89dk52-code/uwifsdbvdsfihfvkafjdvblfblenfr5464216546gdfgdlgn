#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE="App/Assets.xcassets/BrandLogo.imageset/danper-logo.png"
OUTPUT="App/Assets.xcassets/AppIcon.appiconset"
test -f "$SOURCE"
mkdir -p "$OUTPUT"
sips -s format png -z 1024 1024 "$SOURCE" --out "$OUTPUT/AppIcon.png" >/dev/null
cat > "$OUTPUT/Contents.json" <<'CONTENTS'
{
  "images": [
    {"filename":"AppIcon.png", "idiom":"universal", "platform":"ios", "size":"1024x1024"}
  ],
  "info": {"author":"xcode","version":1}
}
CONTENTS
test -s "$OUTPUT/AppIcon.png"
echo "PASS: AppIcon oficial de 1024x1024 creado únicamente para compilación iOS"
