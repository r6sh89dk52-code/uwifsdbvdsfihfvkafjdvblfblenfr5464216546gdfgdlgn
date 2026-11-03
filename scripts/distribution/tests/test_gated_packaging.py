import copy,json,runpy,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent
module=runpy.run_path(str(HERE.parent/'package-build15-gated.py'));check=module['checked_gate']
valid=json.loads((HERE/'fixtures/fictitious-gates-not-app-approval.json').read_text())
class PackagingGuardTests(unittest.TestCase):
 def test_fictitious_complete_envelope_is_accepted_without_creating_ipa(self):check(valid)
 def reject(self,modify):
  data=copy.deepcopy(valid);modify(data)
  with self.assertRaises((AssertionError,ValueError)):check(data)
 def test_previous_head_results_cannot_certify_current(self):self.reject(lambda g:g.update(sourceSHA='0ed08d514763c30f1d631ffd1d22456111d91a0b'))
 def test_previous_native_count_cannot_certify_current(self):self.reject(lambda g:g.update(native=29))
 def test_previous_swift_count_cannot_certify_current(self):self.reject(lambda g:g.update(swift=437))
 def test_missing_ui_case_is_rejected(self):self.reject(lambda g:g['ui'].update(N2BiometricInteractionTests=1))
 def test_same_total_with_wrong_ui_suite_is_rejected(self):
  def wrong(g):g['ui']['InventedSuite']=g['ui'].pop('N2BiometricInteractionTests')
  self.reject(wrong)
 def test_skipped_case_is_rejected(self):self.reject(lambda g:g.update(skips=1))
 def test_changed_stock_compatibility_is_rejected(self):self.reject(lambda g:g['build14ForwardCompatibility'].update(stockUnchanged=False))
 def test_fake_zero_failures_do_not_override_actual_budget(self):
  def wrong(g):g['physicalV2Performance']['operations'][0]['after_p50_ms']=1e9
  self.reject(wrong)
 def test_saved_budget_must_match_actual_measurements(self):self.reject(lambda g:g['corePerformanceBudgets']['checks'][0].update(actual=0))
class DistributionRunProofTests(unittest.TestCase):
 def setUp(self):
  self.check=module['checked_release_run'];self.g=self.check.__globals__
  self.original=(self.g['RELEASE_RUN'],self.g['RELEASE_WORKFLOW'])
  self.g['RELEASE_RUN']=123;self.g['RELEASE_WORKFLOW']='d'*40
  self.run={'id':123,'head_sha':'d'*40,'path':'.github/workflows/b15-arm64-release-check.yml',
    'head_branch':'audit/b15-profile-device-9143997-20261101','event':'push','status':'in_progress','conclusion':None}
  self.jobs=[{'name':n,'status':'completed','conclusion':'success'} for n in ['await-final-gates','arm64-release']]+[{'name':'package','status':'in_progress','conclusion':None}]
 def tearDown(self):self.g['RELEASE_RUN'],self.g['RELEASE_WORKFLOW']=self.original
 def test_current_package_requires_both_real_prerequisites(self):self.check(self.run,self.jobs)
 def test_failed_release_is_rejected(self):
  self.jobs[1]['conclusion']='failure'
  with self.assertRaises(AssertionError):self.check(self.run,self.jobs)
 def test_skipped_gate_wait_is_rejected(self):
  self.jobs[0]['conclusion']='skipped'
  with self.assertRaises(AssertionError):self.check(self.run,self.jobs)
 def test_other_workflow_source_is_rejected(self):
  self.run['head_sha']='e'*40
  with self.assertRaises(AssertionError):self.check(self.run,self.jobs)
 def test_other_run_is_rejected(self):
  self.run['id']=122
  with self.assertRaises(AssertionError):self.check(self.run,self.jobs)
 def test_other_workflow_path_is_rejected(self):
  self.run['path']='.github/workflows/invented.yml'
  with self.assertRaises(AssertionError):self.check(self.run,self.jobs)
 def test_missing_prerequisite_is_rejected(self):
  self.jobs.pop(0)
  with self.assertRaises(AssertionError):self.check(self.run,self.jobs)
if __name__=='__main__':unittest.main()
