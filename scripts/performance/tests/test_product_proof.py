"""Untested compiler output must never satisfy the native approval boundary."""
import json, os, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPT=Path(__file__).resolve().parents[1]/'test-products.py'
class ProductProofTests(unittest.TestCase):
    def test_untested_identity_tamper_and_approval_boundary(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder); products=root/'Products'; products.mkdir()
            (products/'suite.xctestrun').write_text('synthetic test descriptor')
            tool=root/'xcodebuild'; tool.write_text('#!/bin/sh\nprintf "Synthetic Xcode\\n"\n'); tool.chmod(0o755)
            proof=root/'proof.json'; env=dict(os.environ,PATH=str(root)+os.pathsep+os.environ['PATH'])
            def run(mode):
                return subprocess.run([sys.executable,str(SCRIPT),mode,str(products),str(proof)],env=env,capture_output=True).returncode
            self.assertEqual(run('compile-seal'),0)
            self.assertEqual(run('compile-verify'),0)
            self.assertNotEqual(run('verify'),0,'Untested compilation cannot authorize UI or packaging')
            original=proof.read_text(); data=json.loads(original); data['sourceSHA']='0'*40; proof.write_text(json.dumps(data))
            self.assertNotEqual(run('compile-verify'),0)
            proof.write_text(original); (products/'suite.xctestrun').write_text('changed bytes')
            self.assertNotEqual(run('compile-verify'),0)
