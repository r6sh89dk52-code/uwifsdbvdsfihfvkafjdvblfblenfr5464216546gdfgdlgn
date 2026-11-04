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
# Let the framework launch/present/dismiss CoreAuthUI for its real policy.
# External warm launch/termination stalled the diagnostic log before XCTest
# on ARM64 and did not prevent the system watchdog on Intel. Do not manage
# this private system scene here. Tests still require genuine sensor events.
echo "SYSTEM_UI_LIFECYCLE_OWNED_BY_LOCALAUTHENTICATION $SIM_ID"
