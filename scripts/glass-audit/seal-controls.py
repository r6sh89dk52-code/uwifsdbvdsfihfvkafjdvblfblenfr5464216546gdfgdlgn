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
jsreuse=json.loads((out/'JAVASCRIPT_REUSE.json').read_text());assert jsreuse['currentSHA']==sha
assert jsreuse['reusedCount']+jsreuse['executedCount']==62
if jsreuse['reused']:assert sum(r.get('reused',False) for r in js)==jsreuse['reusedCount']
if reuse['suites']['swift']['identical']:
 assert (out/'verified-reused-swift-412.log').is_file()
else:
 assert re.search(r'Executed 412 tests, with 0 failures',(out/'swift-412.log').read_text())
np=out/('verified-reused-native-23.xcresult.summary.json' if reuse['suites']['native']['identical'] else 'native-26.xcresult.summary.json')
s=json.loads(np.read_text());assert s['totalTestCount']==26 and s['passedTests']==26 and s['failedTests']==0 and s['skippedTests']==0 and not s.get('testFailures')
ui=[]
for line in (out/'ui-classes.tsv').read_text().splitlines():
 cls,count,source_class,selectors=line.split('\t');s=json.loads((out/(cls+'.xcresult.summary.json')).read_text())
 assert s['totalTestCount']==int(count) and s['passedTests']==int(count) and s['failedTests']==0 and s['skippedTests']==0 and not s.get('testFailures'),cls
 ui.append({'label':cls,'class':source_class,'selectors':selectors.split(),'passed':int(count)})
assert sum(s['passed'] for s in ui)==11
gate=json.loads((out/'DIAGNOSTIC_GATE.json').read_text());assert gate['currentSHA']==sha
assert (gate.get('allThreePassed') and len(gate['cases'])==3) or (gate.get('targetedPassed') and {e['label'] for e in gate['cases']}=={'iPhone-16','iPhone-SE-3rd-generation','greeting-native','seed-iPhone-16','seed-iPhone-SE-3rd-generation'})
request=json.loads(Path('.github/glass-final-release-request.json').read_text())
simulator_build=json.loads((out/'SIMULATOR_BUILD_REUSE.json').read_text())
if simulator_build['reused']:assert simulator_build['codeInputSHA']==sha and not simulator_build['uiResultsReused']
manifest={'sourceSHA':sha,'simulatorBuild':simulator_build,'swift':{'passed':412,'reused':reuse['suites']['swift']['identical']},'native':{'passed':26,'reused':reuse['suites']['native']['identical']},'javascript':{'passed':62,'crossWorkbookControls':2,'crossWorkbookControlsReused':False,'reuseProof':jsreuse},'ui':{'passed':11,'failed':0,'skipped':0,'classes':ui,'reused':False},'targetedDiagnostic':request,'physicalDeviceValidated':False}
(out/'VALIDATION_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
(out/'ALL_CONTROLS_SHA.txt').write_text(sha+'\n')
print('PASS: all mandatory controls sealed for',sha)
