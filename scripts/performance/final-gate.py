#!/usr/bin/env python3
"""No previous SHA is accepted as certification for this candidate."""
import json,re,subprocess,sys
from pathlib import Path

root=Path(sys.argv[1]);head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
def passing(path,n):
    d=json.loads(path.read_text())
    assert d['totalTestCount']==d['passedTests']==n,(path,d)
    assert d['failedTests']==d['skippedTests']==d.get('expectedFailures',0)==0 and not d.get('testFailures'),(path,d)
def marker(folder,name):assert (folder/name).read_text().strip()==head,(folder,name)
native=root/'B15_NATIVE_RESULTS';marker(native,'SOURCE_SHA.txt');marker(native,'CORE_NATIVE_SHA.txt')
n=sum(len(re.findall(r'func (test\w+)\(',p.read_text())) for p in Path('native-ios/NativeTests').glob('*.swift'))
passing(native/('native-'+str(n)+'.xcresult.summary.json'),n)
suites={}
for p in Path('native-ios/InteractionTests').glob('*.swift'):
    s=p.read_text();c=re.search(r'final class (\w+):XCTestCase',s)
    if not c:continue
    methods=re.findall(r'func (test\w+)\(',s)
    if c[1]=='N3ClinicalJourneyTests':suites.update({c[1]+'-demo':len(methods)-1,c[1]+'-protected':1})
    else:suites[c[1]]=len(methods)
assert sum(suites.values())==13
for label,count in suites.items():
    folder=root/('B15_UI_RESULT_'+label)
    marker(folder,'SOURCE_SHA.txt');marker(folder,'SHARD_PASS_SHA.txt')
    assert (folder/'SHARD_LABEL.txt').read_text().strip()==label
    passing(folder/'biometric-preflight.xcresult.summary.json',1)
    passing(folder/(label+'.xcresult.summary.json'),count)
    if label in ('N2GlassClinicalTests','N2PremiumRedesignTests','N3ClinicalJourneyTests-demo','N2AllergySaveInteractionTests'):
        passing(folder/('seed-'+label+'.xcresult.summary.json'),2)
swift=json.loads((root/'swift'/'swift-results.json').read_text())
assert swift['sourceSHA']==head and swift['tests']>=426 and swift['failures']==swift['skips']==0
marker(root/'javascript','SOURCE_SHA.txt');js=json.loads((root/'javascript'/'javascript-results.json').read_text())
assert len(js)==62 and all(x['exit']==0 for x in js)
marker(root/'performance','SOURCE_SHA.txt');perf=json.loads((root/'performance'/'comparison.json').read_text())
assert perf['workers']==9_648 and len(perf['operations'])==11
assert set(perf['resources'])=={'before','after'}
assert all(x['peak_rss_kib']>0 and x['wall_s']>0 for x in perf['resources'].values())
report={'sourceSHA':head,'swift':swift['tests'],'native':n,'ui':suites,'javascript':62,
    'failures':0,'skips':0,'performance':perf,'IPA':False,'physicalDeviceValidated':False}
compat=json.loads((root/'performance'/'compatibility.json').read_text())
assert compat['sourceSHA']==head and compat['tests']==1 and compat['failures']==0
assert compat['build14JournalRead'] and compat['build14BackupRead'] and compat['stockUnchanged']
report['build14ForwardCompatibility']=compat
profiles=list(root.rglob('profiling-status.json'))
report['instruments']=[json.loads(p.read_text()) for p in profiles]
(root/'FINAL_GATES.json').write_text(json.dumps(report,indent=2))
print('PASS: all current-HEAD Swift, Xcode, native, UI, JS and synthetic performance gates. No IPA generated.')
