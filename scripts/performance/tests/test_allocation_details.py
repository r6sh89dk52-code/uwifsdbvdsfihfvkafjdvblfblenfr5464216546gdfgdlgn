import importlib.util,pathlib,tempfile,unittest
p=pathlib.Path(__file__).resolve().parents[1]/'export-allocation-details.py'
s=importlib.util.spec_from_file_location('allocation_details',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
TOC='<trace-toc><run number="1"><tracks><track name="Allocations"><details><detail name="Statistics" kind="table"/><detail name="Allocations List" kind="table"/></details></track></tracks></run></trace-toc>'
class AllocationDetailTests(unittest.TestCase):
 def test_actual_view_details_are_selected_instead_of_nonexistent_allocation_schema(self):
  q=m.detail_queries(TOC);self.assertEqual(len(q),2)
  self.assertIn('tracks/track[@name="Allocations"]/details/detail[@name="Statistics"]',q[0][1])
  self.assertNotIn('/data/table',q[0][1])
 def test_unrelated_or_missing_tracks_are_not_fabricated(self):
  for s in [TOC.replace('name="Allocations"','name="Leaks"'),TOC.replace('<detail name="Statistics" kind="table"/>','')]:
   with self.assertRaises(ValueError):m.detail_queries(s)
 def test_ambiguous_multiple_runs_are_rejected(self):
  with self.assertRaises(ValueError):m.detail_queries(TOC.replace('</trace-toc>',TOC.removeprefix('<trace-toc>')))
 def test_run_attribute_cannot_inject_xpath(self):
  with self.assertRaises(ValueError):m.detail_queries(TOC.replace('number="1"','number="one"'))
 def test_streamed_counts_do_not_invent_allocation_values(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'out.xml';p.write_text('<trace-query-result><row/><row/><table/></trace-query-result>')
   self.assertEqual(m.xml_counts(p),{'row':2,'table':1,'trace-query-result':1})
if __name__=='__main__':unittest.main()
