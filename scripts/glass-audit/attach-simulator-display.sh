#!/usr/bin/env bash
# Attach this synthetic device to an actual GUI instance; no auth events.
set -euo pipefail
SIM_ID="${1:?Synthetic simulator UUID}"
xcrun simctl list devices -j | python3 -c 'import json,sys
rows=[d for g in json.load(sys.stdin)["devices"].values() for d in g if d["udid"]==sys.argv[1]]
assert len(rows)==1 and rows[0]["state"]=="Booted" and rows[0]["name"].startswith("DANPER-SYNTHETIC-")' "$SIM_ID"
SIM_APP="$(xcode-select -p)/Applications/Simulator.app"
if test -n "${DEVELOPER_DIR:-}"; then SIM_APP="$DEVELOPER_DIR/Applications/Simulator.app"; fi
test -x "$SIM_APP/Contents/MacOS/Simulator"
# --args is ignored by an already-running app. -n guarantees this UDID is used.
open -n -a "$SIM_APP" --args -CurrentDeviceUDID "$SIM_ID"
python3 - "$SIM_ID" "$SIM_APP/Contents/MacOS/Simulator" <<'PYGUI'
import subprocess,sys,time
for _ in range(30):
 rows=subprocess.check_output(['ps','-axo','pid=,command='],text=True).splitlines()
 found=[r.strip() for r in rows if sys.argv[2] in r and '-CurrentDeviceUDID '+sys.argv[1] in r]
 if found:
  print('SIMULATOR_DISPLAY_INSTANCE',sys.argv[1],*found,sep='\n');break
 time.sleep(1)
else:raise SystemExit('No Simulator GUI process bound to synthetic UDID')
PYGUI
