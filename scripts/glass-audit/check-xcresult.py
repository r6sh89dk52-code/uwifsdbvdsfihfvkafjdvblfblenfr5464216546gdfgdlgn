#!/usr/bin/env python3
import json, subprocess, sys
bundle, expected = sys.argv[1], int(sys.argv[2])
data=json.loads(subprocess.check_output(['xcrun','xcresulttool','get','test-results','summary','--path',bundle]))
with open(bundle+'.summary.json','w') as f: json.dump(data,f,indent=2)
assert data['totalTestCount']==expected,(bundle,data)
assert data['failedTests']==0 and data['skippedTests']==0,(bundle,data)
assert data.get('testFailures',[])==[],(bundle,data)
print('PASS',bundle,expected,'tests; no failures/skips')
