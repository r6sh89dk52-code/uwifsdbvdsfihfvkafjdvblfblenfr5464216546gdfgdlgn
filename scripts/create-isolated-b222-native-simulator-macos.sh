#!/usr/bin/env bash
# Creates a fresh, isolated simulator for DANPER's synthetic native preview.
# Does NOT erase, uninstall or modify any existing simulator or iPhone.
set -euo pipefail
command -v xcrun >/dev/null || { echo "FALTA: Xcode / xcrun"; exit 1; }
command -v python3 >/dev/null || { echo "FALTA: python3"; exit 1; }
DEVICE_TYPE="$(xcrun simctl list devicetypes -j | python3 -c 'import json,sys; items=json.load(sys.stdin)["devicetypes"]; print(next((x["identifier"] for x in items if x["name"]=="iPhone 16"),""))')"
RUNTIME="$(xcrun simctl list runtimes -j | python3 -c 'import json,sys; items=json.load(sys.stdin)["runtimes"]; items=[x for x in items if x.get("isAvailable",False) and x.get("name","").startswith("iOS")]; print(items[-1]["identifier"] if items else "")')"
if [ -z "$DEVICE_TYPE" ] || [ -z "$RUNTIME" ]; then
  echo "No se encontraron iPhone 16 e iOS Simulator disponibles en Xcode." >&2
  exit 1
fi
NAME="DANPER B222 Nativa - Aislado $(date +%Y%m%d-%H%M%S)"
echo "Creando simulador totalmente nuevo: $NAME"
UDID="$(xcrun simctl create "$NAME" "$DEVICE_TYPE" "$RUNTIME")"
echo "UDID: $UDID"
echo "Iniciando nuevo simulador (sin tocar los existentes)..."
xcrun simctl boot "$UDID"
open -a Simulator --args -CurrentDeviceUDID "$UDID"
xcrun simctl bootstatus "$UDID" -b
echo ""
echo "SIMULADOR LISTO: $NAME"
echo "En Xcode selecciona el destino con ese nombre y ejecuta DANPERNative con Cmd+R."
echo "NO elimines el simulador antiguo: podría contener un cifrado que quieras conservar."
