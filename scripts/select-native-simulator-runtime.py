#!/usr/bin/env python3
"""Select an available iOS runtime matching the selected Xcode simulator SDK."""
import argparse
import json
from pathlib import Path


def select_runtime(runtimes, sdk):
    expected = tuple(int(x) for x in sdk.split('.')[:2])
    candidates = [r for r in runtimes if r.get('isAvailable')
                  and r['identifier'].startswith('com.apple.CoreSimulator.SimRuntime.iOS-')
                  and tuple(int(x) for x in r['version'].split('.')[:2]) == expected]
    if not candidates:
        raise ValueError(f'No available iOS runtime matches simulator SDK {sdk}; refusing a newer runtime')
    return max(candidates, key=lambda r: tuple(int(x) for x in r['version'].split('.')))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runtimes', type=Path, required=True)
    p.add_argument('--sdk', required=True)
    a = p.parse_args()
    print(json.dumps(select_runtime(json.loads(a.runtimes.read_text())['runtimes'], a.sdk)))
