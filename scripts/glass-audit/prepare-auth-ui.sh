#!/usr/bin/env bash
# Open Simulator only. LocalAuthentication owns its own system UI lifecycle.
set -euo pipefail
SIM_ID="${1:?Synthetic simulator UUID}"
xcrun simctl list devices -j | python3 -c 'import json,sys
rows=[d for group in json.load(sys.stdin)["devices"].values() for d in group if d["udid"]==sys.argv[1]]
assert len(rows)==1 and rows[0]["state"]=="Booted" and rows[0]["name"].startswith("DANPER-SYNTHETIC-")' "$SIM_ID"
SIM_APP="${DEVELOPER_DIR:-$(xcode-select -p)}/Applications/Simulator.app"
test -d "$SIM_APP"
open -a "$SIM_APP" --args -CurrentDeviceUDID "$SIM_ID"
# Do not manually launch/terminate CoreAuthUI: it is a system-hosted service.
# An existing Simulator may ignore --args; no display binding is claimed.
echo "SYSTEM_UI_LIFECYCLE_OWNED_BY_LOCALAUTHENTICATION $SIM_ID"
