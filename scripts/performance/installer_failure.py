#!/usr/bin/env python3
"""Recognize only observed pre-XCTest Simulator installation failures.

This does not run/retry tests or select devices. The caller separately enforces
an owned synthetic Simulator and at most one reboot, and fails if retry fails.
"""
from pathlib import Path
import sys


def recoverable_install_failure(log: str) -> bool:
    return (
        'domain=IXErrorDomain, code=2' in log and 'Failed to create promise' in log
    ) or (
        'domain=NSCocoaErrorDomain, code=4097' in log
        and 'Simulator device failed to install the application.' in log
        and 'Couldn’t communicate with a helper application.' in log
    )


if __name__ == '__main__':
    sys.exit(0 if recoverable_install_failure(Path(sys.argv[1]).read_text()) else 1)
