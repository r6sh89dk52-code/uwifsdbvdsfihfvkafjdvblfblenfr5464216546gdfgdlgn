#!/usr/bin/env python3
"""Seal only actual mandatory successes for the current exact checkout."""
import json,re,subprocess,sys
from pathlib import Path
out=Path(sys.argv[1]);sha=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
for name in ['SOURCE_SHA.txt','SWIFT_VALIDATED_SHA.txt','JAVASCRIPT_VALIDATED_SHA.txt','CORE_NATIVE_SHA.txt','VALIDATED_SHA.txt']:
 assert (out/name).read_text().strip()==sha,name
js=json.loads((out/'javascript-results.json').read_text());assert len(js)==62 and all(r['exit']==0 for r in js)
for name in ['test-n1r-native-xlsx.log','test-n1s-full-native-workbooks.log']:assert 'PASS' in (out/name).read_text(),name
reuse=json.loads((out/'SCOPED_REUSE.json').read_text());assert reuse['currentSHA']==sha
if reuse['suites']['swift']['identical']:
 assert (out/'verified-reused-swift-412.log').is_file()
else:
 assert re.search(r'Executed 412 tests, with 0 failures',(out/'swift-412.log').read_text())
np=out/('verified-reused-native-23.xcresult.summary.json' if reuse['suites']['native']['identical'] else 'native-23.xcresult.summary.json')
s=json.loads(np.read_text());assert s['totalTestCount']==23 and s['passedTests']==23 and s['failedTests']==0 and s['skippedTests']==0 and not s.get('testFailures')
ui=[]
for line in (out/'ui-classes.tsv').read_text().splitlines():
 cls,count=line.split('\t');s=json.loads((out/(cls+'.xcresult.summary.json')).read_text())
 assert s['totalTestCount']==int(count) and s['passedTests']==int(count) and s['failedTests']==0 and s['skippedTests']==0 and not s.get('testFailures'),cls
 ui.append({'class':cls,'passed':int(count)})
assert sum(s['passed'] for s in ui)==11
gate=json.loads((out/'DIAGNOSTIC_GATE.json').read_text());assert gate['currentSHA']==sha and gate['allThreePassed'] and len(gate['cases'])==3
request=json.loads(Path('.github/glass-final-release-request.json').read_text())
manifest={'sourceSHA':sha,'swift':{'passed':412,'reused':reuse['suites']['swift']['identical']},'native':{'passed':23,'reused':reuse['suites']['native']['identical']},'javascript':{'passed':62,'crossWorkbookControls':2,'reused':False},'ui':{'passed':11,'failed':0,'skipped':0,'classes':ui,'reused':False},'targetedDiagnostic':request,'physicalDeviceValidated':False}
(out/'VALIDATION_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
(out/'ALL_CONTROLS_SHA.txt').write_text(sha+'\n')
print('PASS: all mandatory controls sealed for',sha)
