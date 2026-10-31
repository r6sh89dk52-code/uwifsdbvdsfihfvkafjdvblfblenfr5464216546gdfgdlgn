import importlib.util,json,tempfile,unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('ui_evidence',Path(__file__).parents[1]/'verify-ui-shard.py')
evidence=importlib.util.module_from_spec(spec);spec.loader.exec_module(evidence)

class UIEvidenceTests(unittest.TestCase):
    head='a'*40
    label='N2Build222ShellTests'
    def setUp(self):
        temporary=tempfile.TemporaryDirectory();self.addCleanup(temporary.cleanup)
        self.folder=Path(temporary.name)
        self.prepare(self.label,1)
    def summary(self,name,count=1,**overrides):
        data=dict(totalTestCount=count,passedTests=count,failedTests=0,skippedTests=0,
                  expectedFailures=0,testFailures=[])
        data.update(overrides)
        (self.folder/(name+'.xcresult.summary.json')).write_text(json.dumps(data))
    def prepare(self,label,count):
        for name in ['SOURCE_SHA.txt','SHARD_PASS_SHA.txt']:(self.folder/name).write_text(self.head)
        (self.folder/'SHARD_LABEL.txt').write_text(label)
        self.summary('biometric-preflight');self.summary(label,count)
    def reject(self,label=None):
        with self.assertRaises((AssertionError,FileNotFoundError)):
            evidence.verify(self.folder,label or self.label,self.head)
        self.assertFalse((self.folder/'SHARD_VERIFIED_SHA.txt').exists())
    def test_complete_current_evidence_is_accepted(self):
        self.assertEqual(evidence.verify(self.folder,self.label,self.head),1)
        self.assertEqual((self.folder/'SHARD_VERIFIED_SHA.txt').read_text().strip(),self.head)
    def test_green_shell_without_any_xctest_result_is_rejected(self):
        for path in self.folder.glob('*.summary.json'):path.unlink()
        self.reject()
    def test_missing_completion_marker_is_rejected(self):
        (self.folder/'SHARD_PASS_SHA.txt').unlink();self.reject()
    def test_other_commit_is_rejected(self):
        (self.folder/'SOURCE_SHA.txt').write_text('b'*40);self.reject()
    def test_failed_case_revokes_previous_verified_marker(self):
        (self.folder/'SHARD_VERIFIED_SHA.txt').write_text(self.head)
        self.summary(self.label,passedTests=0,failedTests=1);self.reject()
    def test_skipped_case_is_rejected(self):
        self.summary(self.label,passedTests=0,skippedTests=1);self.reject()
    def test_partial_suite_is_rejected(self):
        self.summary(self.label,0);self.reject()
    def test_missing_allergy_seed_is_rejected(self):
        self.prepare('N2AllergySaveInteractionTests',2)
        self.reject('N2AllergySaveInteractionTests')
    def test_complete_allergy_seed_and_two_cases_are_accepted(self):
        label='N2AllergySaveInteractionTests';self.prepare(label,2)
        self.summary('seed-'+label,2)
        self.assertEqual(evidence.verify(self.folder,label,self.head),2)

if __name__=='__main__':unittest.main()
