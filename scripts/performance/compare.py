#!/usr/bin/env python3
import json,sys
from pathlib import Path

before,after,output=map(Path,sys.argv[1:])
a=json.loads(before.read_text());b=json.loads(after.read_text())
assert a['workers']==b['workers']==9_648
assert a['initialVisits']==b['initialVisits'] and a['snapshotBytes']==b['snapshotBytes']
old={x['action']:x for x in a['actions']};new={x['action']:x for x in b['actions']}
assert old.keys()==new.keys()
rows=[]
for label in old:
    x,y=old[label],new[label]
    assert x['n']==y['n'] and x['n']>=3
    rows.append({'action':label,'before_p50_ms':x['p50_ms'],'after_p50_ms':y['p50_ms'],
        'change_percent':(x['p50_ms']-y['p50_ms'])/x['p50_ms']*100,
        'before_p95_ms':x.get('p95_ms'),'after_p95_ms':y.get('p95_ms'),
        'samples':x['n'],'interpretation':'measured core-only synthetic benchmark; not physical iPhone latency'})
resources={}
for label,path in [('before',before),('after',after)]:
    file=Path(str(path)+'.resources.json')
    if file.exists():resources[label]=json.loads(file.read_text())
output.write_text(json.dumps({'resourceScope':'Whole prepared Core/XCTest workload, compiler excluded; not physical iPhone memory','resources':resources,'workers':9_648,'initialVisits':a['initialVisits'],
    'conditions':b['configuration'],'beforeStoreLifecycle':a.get('storeLifecycle','new journal/core per operation'),'afterStoreLifecycle':b.get('storeLifecycle'),'operations':rows},indent=2))
for row in rows:print(row['action'],round(row['before_p50_ms'],3),'->',round(row['after_p50_ms'],3),'ms')
