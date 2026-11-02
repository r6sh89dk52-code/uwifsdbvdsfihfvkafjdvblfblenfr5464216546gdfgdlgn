#!/usr/bin/env python3
"""Core-only synthetic budgets. Never assert physical iPhone/UI latency."""
import json,math,sys
from pathlib import Path

RATIOS={'allergy_confirmed_encrypted_save':.85,'draft_confirmed_encrypted_save':.65,
 'dispensing_readonly_refresh':.25,'nursing_98_export':.90,'encrypted_backup_verified':.95}
SEARCH_P95_MS={'worker_search_last':5.,'worker_search_common':25.}
def positive(value):
 if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value) or value<=0:
  raise ValueError('Missing, nonfinite or nonpositive timing/resource value')
 return value

def validate(data):
 if data.get('workers')!=9648 or data.get('initialVisits')!=1005:raise ValueError('Different synthetic scale')
 ops=data.get('operations',[])
 if len(ops)!=12:raise ValueError('Incomplete v2 workload')
 by={x['action']:x for x in ops}
 if len(by)!=len(ops):raise ValueError('Duplicate operation')
 checks=[]
 def check(name,actual,limit,unit):
  if actual>limit:raise ValueError(f'{name}: {actual:.6f} {unit} exceeds {limit:.6f}')
  checks.append(dict(action=name,actual=actual,limit=limit,unit=unit))
 for name,limit in RATIOS.items():
  op=by[name]
  if op.get('samples',0)<3:raise ValueError('Insufficient median samples')
  ratio=positive(op.get('after_p50_ms'))/positive(op.get('before_p50_ms'))
  check(name,ratio,limit,'after/before')
 for name,limit in SEARCH_P95_MS.items():
  op=by[name]
  if op.get('samples',0)<100:raise ValueError('Insufficient search percentile samples')
  check(name,positive(op.get('after_p95_ms')),limit,'core p95 ms')
 resources=data['resources'];before=resources['before'];after=resources['after']
 check('whole_core_workload_cpu',positive(after.get('user_cpu_s'))/positive(before.get('user_cpu_s')),.90,'after/before CPU')
 check('whole_core_workload_rss',positive(after.get('peak_rss_kib'))/positive(before.get('peak_rss_kib')),1.10,'after/before RSS')
 return {'scope':'Fixed fictitious Core v2 workload; not SwiftUI/device latency','checks':checks,
  'failures':0,'physicalDeviceValidated':False,'IPA':False}

if __name__=='__main__':
 source,output=map(Path,sys.argv[1:]);report=validate(json.loads(source.read_text()))
 output.write_text(json.dumps(report,indent=2)+'\n')
 print('PASS: 9 synthetic Core performance budgets; no iPhone latency claim; no IPA')
