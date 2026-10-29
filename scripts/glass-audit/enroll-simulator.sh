#!/usr/bin/env bash
# Simulator preparation only: no successful authentication is injected here.
set -euo pipefail
SIM_ID="${1:?Pass the UUID of the synthetic Simulator created by this audit}"
[[ "$SIM_ID" =~ ^[0-9A-Fa-f-]{36}$ ]]
xcrun simctl list devices -j | python3 -c '
import json,sys
uid=sys.argv[1]
rows=[d for group in json.load(sys.stdin)["devices"].values() for d in group if d["udid"]==uid]
assert len(rows)==1 and rows[0]["state"]=="Booted" and rows[0]["name"].startswith("DANPER-SYNTHETIC-"),rows
print("Preparing enrollment only:",rows[0]["name"],uid)
' "$SIM_ID"
# Same set-state THEN post sequence as wix/AppleSimulatorUtils main.m,
# setBiometricEnrollment(), commit 753749d51ccdb709fddb4f24dd04436bed3bb6b4.
KEY=com.apple.BiometricKit.enrollmentChanged
xcrun simctl spawn "$SIM_ID" notifyutil -s "$KEY" 1
xcrun simctl spawn "$SIM_ID" notifyutil -p "$KEY"
xcrun simctl spawn "$SIM_ID" notifyutil -g "$KEY"
# notify state is diagnostic only. LAContext.canEvaluatePolicy + .faceID and
# the genuine match/nomatch/cancel/foreground UI tests remain mandatory.
