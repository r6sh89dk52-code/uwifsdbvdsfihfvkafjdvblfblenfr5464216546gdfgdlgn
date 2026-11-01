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

# Current failed logs show CoreAuthUI starting AFTER coreauthd's 5 s watchdog.
# Warm its executable before the app requests a policy, then relinquish its
# standalone scene. This never posts a biometric match or grants app access.
case "${DANPER_B15_UI_LABEL:-}" in
 N2BiometricInteractionTests|N3ClinicalJourneyTests-protected)
  WARM_LOG="${DANPER_AUDIT_OUT:?}/auth-ui-cold-start.log"
  python3 -u scripts/glass-audit/simulator-ready-bridge.py --stream "$SIM_ID" > "$WARM_LOG" 2>&1 & WARM_STREAM=$!
  trap 'kill "$WARM_STREAM" 2>/dev/null || true; wait "$WARM_STREAM" 2>/dev/null || true' EXIT
  xcrun simctl launch "$SIM_ID" com.apple.CoreAuthUI
  python3 - "$WARM_LOG" <<'PYREADY'
import sys,time
from pathlib import Path
p=Path(sys.argv[1]);deadline=time.monotonic()+30
while time.monotonic()<deadline:
    s=p.read_text(errors='replace') if p.exists() else ''
    if 'CoreAuthUI[' in s and 'didFinishLaunching' in s:break
    time.sleep(0.1)
else:raise SystemExit('CoreAuthUI did not finish its cold launch; do not start authentication tests')
PYREADY
  xcrun simctl terminate "$SIM_ID" com.apple.CoreAuthUI || true
  echo "AUTH_UI_EXECUTABLE_WARMED_NO_POLICY_OR_MATCH $SIM_ID"
  ;;
esac
