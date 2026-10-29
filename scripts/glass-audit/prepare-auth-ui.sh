#!/usr/bin/env bash
# Warm the system UI process only; never enroll, match or authorize the app.
set -euo pipefail
SIM_ID="${1:?Synthetic simulator UUID}"
xcrun simctl list devices -j | python3 -c 'import json,sys
rows=[d for group in json.load(sys.stdin)["devices"].values() for d in group if d["udid"]==sys.argv[1]]
assert len(rows)==1 and rows[0]["state"]=="Booted" and rows[0]["name"].startswith("DANPER-SYNTHETIC-")' "$SIM_ID"
open -a Simulator --args -CurrentDeviceUDID "$SIM_ID"
# The recovered log proves CoreAuthUI exceeded coreauthd's 5-second activation
# watchdog on first launch. Prelaunch it before any DANPER authentication.
# This process has no DANPER LAContext and cannot grant access to its vault.
xcrun simctl launch "$SIM_ID" com.apple.CoreAuthUI
# Allow the UI-service cold start to finish outside the authentication watchdog.
sleep 8
# Do not leave a standalone User Authentication foreground scene behind.
# The actual app request must create its own system-hosted authentication UI.
xcrun simctl terminate "$SIM_ID" com.apple.CoreAuthUI
xcrun simctl spawn "$SIM_ID" launchctl list | python3 -c 'import sys
for line in sys.stdin:
 if "CoreAuthUI" in line or "coreauthd" in line:print(line.rstrip())'
