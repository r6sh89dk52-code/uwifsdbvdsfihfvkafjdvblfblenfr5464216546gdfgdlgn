#!/usr/bin/env python3
"""Reuse only proven non-biometric suites when every tested input is identical."""
from pathlib import Path
import json,re,subprocess,sys,shutil,hashlib
baseline=Path(sys.argv[1]); out=Path(sys.argv[2]); out.mkdir(parents=True,exist_ok=True)
ce='ce974457851aca4b4316ac3f2334f530791be314'
def git(*args):return subprocess.check_output(['git',*args],text=True).strip()
expected_hashes={'SOURCE_SHA.txt': '4ff8882e6c0f59d02efa902ea72d0a01000ff5cbb5627bf0be3c91b900a7177d', 'swift-412.log': '0248ff1aa4d5f321d881edf8cc7e009bea7d6faf8b350a62706bba0cd3950f33', 'javascript-results.json': '6237926ff7a99d92aa08dd844feb42ef07d811869b288c285082f28250e5a750', 'native-23.xcresult.summary.json': '0fff1858254621ebbd920ba80dd4cb45988b2ddd7a9518bfe383839350a334e3', 'test-n1r-native-xlsx.log': '08f43a55954dc1618b87e52adecc3187c587932bfe7b66316ff9cf20a8abe1fe', 'test-n1s-full-native-workbooks.log': '95c618a4458cf43979de016ae43dc9f2a3a3727ed12fc02d31cc5855fee6ef87'}
for name,digest in expected_hashes.items():assert hashlib.sha256((baseline/name).read_bytes()).hexdigest()==digest,name
assert (baseline/'SOURCE_SHA.txt').read_text().strip()==ce
subprocess.run(['git','diff','--exit-code','HEAD','--','native-ios','src','package.json','package-lock.json'],check=True)
allowed={'.github/workflows/glass-final-audit.yml','scripts/glass-audit/validate-macos.sh',
 'scripts/glass-audit/enroll-simulator.sh','scripts/glass-audit/verify-reuse.py',
 'docs/GLASS_INDEPENDENT_AUDIT_20261028.md'}
changed=set(git('diff','--name-only',ce,'HEAD').splitlines())
assert changed<=allowed,('Tested inputs changed; execute full suites instead',changed-allowed)
identical={p:git('rev-parse',f'HEAD:{p}') for p in ['native-ios','src','package.json','package-lock.json']}
for p,h in identical.items():assert git('rev-parse',f'{ce}:{p}')==h,p
swift=(baseline/'swift-412.log').read_text()
assert re.search(r'Executed 412 tests, with 0 failures',swift)
assert "Test Suite 'All tests' passed" in swift
assert not re.search(r'\d+ tests? (?:were )?skipped',swift)
js=json.loads((baseline/'javascript-results.json').read_text())
assert len(js)==62 and all(x['exit']==0 for x in js)
assert sum(x['group']=='javascript-50' for x in js)==50
assert sum(x['group']=='additional-12' for x in js)==12
native=json.loads((baseline/'native-23.xcresult.summary.json').read_text())
assert native['totalTestCount']==23 and native['passedTests']==22 and native['failedTests']==1 and native['skippedTests']==0
failures=native['testFailures']
assert len(failures)==1 and failures[0]['testIdentifierString']=='N2BiometricEnvironmentTests/testIsolatedSimulatorActuallyOffersFaceID()'
assert 'Code=-7' in failures[0]['failureText'] and 'not enrolled' in failures[0]['failureText']
for name in ['test-n1r-native-xlsx.log','test-n1s-full-native-workbooks.log']:
 assert 'PASS' in (baseline/name).read_text(),name
for name in ['swift-412.log','javascript-results.json','test-n1r-native-xlsx.log','test-n1s-full-native-workbooks.log']:
 shutil.copy2(baseline/name,out/('reused-ce-'+name))
result={'baselineSHA':ce,'baselineRun':40790429936,'currentSHA':git('rev-parse','HEAD'),
 'baselineArtifactID':12863355350,'evidenceFileSHA256':expected_hashes,'identicalInputTrees':identical,'changedInfrastructureOnly':sorted(changed),
 'reused':{'swift':412,'javascriptOriginal':50,'additionalGuards':12,'crossWorkbookChecks':2},
 'notReused':'native23, failed biometric environment and all11 UI must run on corrected checkout; Release ARM64 must rebuild'}
(out/'REUSED_RESULTS.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
