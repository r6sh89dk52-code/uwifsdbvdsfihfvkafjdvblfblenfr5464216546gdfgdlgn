#!/usr/bin/env python3
"""Limit a CI command and terminate its process group on timeout."""
import os
import shlex
import signal
import subprocess
import sys
import time


def main():
    seconds, label, *command = sys.argv[1:]
    started = time.monotonic()
    print(f"START {label} (limit {seconds}s): {shlex.join(command)}", file=sys.stderr, flush=True)
    process = subprocess.Popen(command, start_new_session=True)

    def signal_group(signum):
        try:
            os.killpg(process.pid, signum)
        except ProcessLookupError:
            pass
        except PermissionError as error:
            # macOS services may retain the group after the command exits.
            # Only signal the direct child if group signalling is denied.
            print(f"Cannot signal process group {process.pid}: {error}", file=sys.stderr, flush=True)
            try:
                process.send_signal(signum)
            except PermissionError as child_error:
                print(f"Cannot signal child {process.pid}: {child_error}", file=sys.stderr, flush=True)

    def terminate_group():
        signal_group(signal.SIGTERM)
        time.sleep(3)
        signal_group(signal.SIGKILL)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            print(f"Child {process.pid} did not exit; simulator cleanup will follow",
                  file=sys.stderr, flush=True)

    def interrupted(signum, _frame):
        terminate_group()
        raise SystemExit(128 + signum)

    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, interrupted)

    try:
        result = process.wait(timeout=int(seconds))
    except subprocess.TimeoutExpired:
        print(f"TIMEOUT {label} after {seconds}s (process group {process.pid})",
              file=sys.stderr, flush=True)
        try:
            rows = subprocess.check_output(
                ["ps", "-axo", "pid,ppid,pgid,etime,state,comm"], text=True, timeout=5
            )
            for row in rows.splitlines()[1:]:
                fields = row.split(maxsplit=5)
                if len(fields) == 6 and (fields[2] == str(process.pid) or any(
                    name in os.path.basename(fields[5])
                    for name in ("CoreSimulator", "testmanagerd", "xctest", "xcodebuild", "installd")
                )):
                    print(row, file=sys.stderr, flush=True)
        except (OSError, subprocess.SubprocessError) as error:
            print(f"Process diagnostics unavailable: {error}", file=sys.stderr, flush=True)
        finally:
            terminate_group()
        result = 124

    elapsed = time.monotonic() - started
    print(f"END {label}: exit={result} elapsed={elapsed:.1f}s", file=sys.stderr, flush=True)
    return result if result >= 0 else 128 - result


if __name__ == "__main__":
    sys.exit(main())
