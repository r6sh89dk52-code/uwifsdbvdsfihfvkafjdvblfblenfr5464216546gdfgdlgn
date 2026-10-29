#!/usr/bin/env python3
"""Start all UI cases only after three targeted cases truly pass."""
import json,subprocess,sys
from pathlib import Path
p=Path(sys.argv[1]);sha=(p/'SOURCE_SHA.txt').read_text().strip()
assert (p/'DIAGNOSED_3_SHA.txt').read_text().strip()==sha
classes=['N2BiometricInteractionTests','N2PremiumRedesignTests','N3ClinicalJourneyTests']
for cls in classes:
 s=json.loads((p/(cls+'.xcresult.summary.json')).read_text())
 assert s['totalTestCount']==1 and s['passedTests']==1 and s['failedTests']==0 and s['skippedTests']==0 and not s.get('testFailures'),cls
 assert (p/(cls+'-PASS_SHA.txt')).read_text().strip()==sha
subprocess.run(['git','diff','--exit-code',sha,'HEAD','--','native-ios','src','package.json','package-lock.json','scripts/prepare-n1s-ios-demo-resources.cjs','scripts/glass-audit/enroll-simulator.sh','scripts/glass-audit/prepare-auth-ui.sh'],check=True)
print('PASS: three targeted cases; identical current UI/app/resource/auth-preparation inputs')
