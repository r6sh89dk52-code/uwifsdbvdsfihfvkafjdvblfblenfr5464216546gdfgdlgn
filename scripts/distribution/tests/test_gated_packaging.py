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
 def test_previous_native_count_cannot_certify_current(self):self.reject(lambda g:g.update(native=28))
 def test_previous_swift_count_cannot_certify_current(self):self.reject(lambda g:g.update(swift=433))
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
if __name__=='__main__':unittest.main()
