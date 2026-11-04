import importlib.util
from pathlib import Path
import unittest

spec=importlib.util.spec_from_file_location('owned_process',Path(__file__).parents[1]/'owned_process.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class OwnedProcessTests(unittest.TestCase):
    executable='/Users/runner/Library/Developer/CoreSimulator/Devices/OWNED/data/Containers/Bundle/Application/UUID/DANPERNative.app/DANPERNative'
    def test_selects_owned_app_and_not_other_simulator(self):
        listing='12 '+self.executable.replace('/OWNED/','/OTHER/')+'\n34 '+self.executable+' --danper-redesign-demo'
        self.assertEqual(module.find_owned_app(listing,'OWNED'),'34')
    def test_runner_is_not_application(self):
        listing='12 '+self.executable.replace('DANPERNative.app/DANPERNative','DANPERInteractionTests-Runner.app/DANPERInteractionTests-Runner')
        self.assertIsNone(module.find_owned_app(listing,'OWNED'))
    def test_path_inside_command_argument_cannot_select_unrelated_process(self):
        self.assertIsNone(module.find_owned_app('12 /usr/bin/python '+self.executable,'OWNED'))
    def test_absent_process_stays_unmeasured(self):
        self.assertIsNone(module.find_owned_app('1 /usr/sbin/launchd','OWNED'))
