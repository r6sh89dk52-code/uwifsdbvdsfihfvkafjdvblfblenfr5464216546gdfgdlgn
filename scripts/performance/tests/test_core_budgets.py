import importlib.util,math,pathlib,unittest
spec=importlib.util.spec_from_file_location('budgets',pathlib.Path(__file__).parents[1]/'core-budgets.py')
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
def fixture():
 # Representative ratios derived from repeated measured v2 runs, no records.
 values=[('allergy_confirmed_encrypted_save',4400,3000,7),('draft_confirmed_encrypted_save',7600,3100,7),
 ('dispensing_readonly_refresh',3700,330,3),('nursing_98_export',8000,6400,3),
 ('encrypted_backup_verified',15800,12800,3),('worker_search_last',.16,.17,100),
 ('worker_search_common',7,7.1,100),('form_prepare_9648',235,236,7),('history_read_1005',134,135,7),
 ('dashboard_refresh',95,93,7),('correction_editor_load',51,48,3),('inventory_catalog_only',1.4,1.5,3)]
 return {'workers':9648,'initialVisits':1005,'operations':[dict(action=n,before_p50_ms=x,after_p50_ms=y,
  after_p95_ms=y*1.1,samples=s) for n,x,y,s in values],
  'resources':{'before':{'user_cpu_s':235,'peak_rss_kib':224200},'after':{'user_cpu_s':162,'peak_rss_kib':224124}}}
class CoreBudgetRegressionTests(unittest.TestCase):
 def test_measured_shape_passes_without_claiming_phone_latency(self):
  r=b.validate(fixture());self.assertEqual(len(r['checks']),9);self.assertFalse(r['physicalDeviceValidated'])
 def test_restoring_unoptimized_saves_is_rejected(self):
  d=fixture()
  for x in d['operations']:x['after_p50_ms']=x['before_p50_ms']
  with self.assertRaises(ValueError):b.validate(d)
 def test_absolute_host_speed_does_not_change_relative_save_budget(self):
  d=fixture()
  for x in d['operations']:
   x['before_p50_ms']*=2;x['after_p50_ms']*=2;x['after_p95_ms']*=2
  d['resources']['before']['user_cpu_s']*=2;d['resources']['after']['user_cpu_s']*=2
  self.assertEqual(b.validate(d)['failures'],0)
 def test_slow_last_worker_query_is_rejected(self):
  d=fixture();next(x for x in d['operations'] if x['action']=='worker_search_last')['after_p95_ms']=20
  with self.assertRaises(ValueError):b.validate(d)
 def test_scale_reduction_cannot_fake_improvement(self):
  d=fixture();d['workers']=2
  with self.assertRaises(ValueError):b.validate(d)
 def test_nonfinite_measurement_is_not_a_passing_comparison(self):
  d=fixture();d['operations'][0]['after_p50_ms']=math.nan
  with self.assertRaises(ValueError):b.validate(d)
 def test_memory_growth_is_not_hidden_by_cpu_improvement(self):
  d=fixture();d['resources']['after']['peak_rss_kib']=300000
  with self.assertRaises(ValueError):b.validate(d)
if __name__=='__main__':unittest.main()
