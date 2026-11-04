import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('installer_failure',Path(__file__).parents[1]/'installer_failure.py')
installer=importlib.util.module_from_spec(spec);spec.loader.exec_module(installer)


class InstallerFailureTests(unittest.TestCase):
    def test_observed_installcoordination_promise_failure_is_recognized(self):
        self.assertTrue(installer.recoverable_install_failure(
            'domain=IXErrorDomain, code=2: Failed to create promise'))

    def test_observed_cocoa_helper_install_failure_is_recognized(self):
        self.assertTrue(installer.recoverable_install_failure(
            'domain=NSCocoaErrorDomain, code=4097\n'
            'Simulator device failed to install the application.\n'
            'Couldn’t communicate with a helper application.'))

    def test_partial_or_different_failures_are_not_retried(self):
        for log in ['domain=IXErrorDomain, code=2',
                    'Failed to create promise',
                    'domain=NSCocoaErrorDomain, code=4097',
                    'Simulator device failed to install the application.',
                    'domain=NSCocoaErrorDomain, code=4099\nCouldn’t communicate with a helper application.',
                    'XCTAssertTrue failed - authentication did not complete']:
            with self.subTest(log=log):
                self.assertFalse(installer.recoverable_install_failure(log))
