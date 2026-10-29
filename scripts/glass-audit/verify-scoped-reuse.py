#!/usr/bin/env python3
"""Prove Swift/native input identity independently; never infer UI success."""
import hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
baseline,out=map(Path,sys.argv[1:3]);out.mkdir(parents=True,exist_ok=True)
def git(*args):return subprocess.check_output(['git',*args],text=True).strip()
def blob(ref,path):return git('rev-parse',ref+':'+path)
def verified(name,digest):
 p=baseline/name
 assert hashlib.sha256(p.read_bytes()).hexdigest()==digest,name
 return p
subprocess.run(['git','diff','--exit-code','HEAD','--','native-ios','src','package.json','package-lock.json'],check=True)
ce='ce974457851aca4b4316ac3f2334f530791be314'
native='9280d7871f7c39fd21c4484e9f40a2b504a841f9'
assert (baseline/'SOURCE_SHA.txt').read_text().strip()==native
swift=verified('reused-ce-swift-412.log','0248ff1aa4d5f321d881edf8cc7e009bea7d6faf8b350a62706bba0cd3950f33')
summary=verified('native-23.xcresult.summary.json','0da062623aad12c43114e738c7ee28a8d736e1acf950b412a6231c8b4e059f55')
assert re.search(r'Executed 412 tests, with 0 failures',swift.read_text())
assert not re.search(r'\d+ tests? (?:were )?skipped',swift.read_text())
s=json.loads(summary.read_text());assert s['totalTestCount']==23 and s['passedTests']==23 and s['failedTests']==0 and s['skippedTests']==0 and not s.get('testFailures')
common=['native-ios/Package.swift','native-ios/Package.resolved','native-ios/Sources','native-ios/Tests','src','package.json','package-lock.json','scripts/glass-audit/prepare.sh']
nativepaths=common+['native-ios/App','native-ios/NativeTests','native-ios/project.yml','native-ios/scripts']
# These paths are not inputs of Swift Package tests. Everything else in the
# repository is conservatively an external fixture/template/generator input.
ignore=('.github/','docs/','scripts/glass-audit/','native-ios/App/','native-ios/NativeTests/','native-ios/InteractionTests/','native-ios/scripts/')
ignorefiles={'native-ios/project.yml'}
changed=git('diff','--name-only',ce,'HEAD').splitlines()
external=[p for p in changed if p not in ignorefiles and not p.startswith(ignore)]
xcode=(out/'xcode-version.txt').read_bytes()==(baseline/'xcode-version.txt').read_bytes()
device=s['devicesAndConfigurations'][0]['device']
architecture=(out/'architecture.txt').read_text().strip()
runtime=any(r.get('isAvailable') and r['version']==device['osVersion'] and r['buildversion']==device['osBuildNumber'] for r in json.loads((out/'runtimes.json').read_text())['runtimes'])
arch=architecture==device['architecture']
proof={}
for label,ref,paths in [('swift',ce,common),('native',native,nativepaths)]:
 rows={p:{'baseline':blob(ref,p),'current':blob('HEAD',p)} for p in paths}
 proof[label]={'baselineSHA':ref,'inputs':rows,'identical':all(v['baseline']==v['current'] for v in rows.values()) and not external and xcode and arch and (runtime or label=='swift')}
report={'currentSHA':git('rev-parse','HEAD'),'recoveredRun':40806554927,'recoveredArtifact':12868187797,'nativeTestRun':40795027687,'xcodeIdentical':xcode,'runtimeIdentical':runtime,'architectureIdentical':arch,'changedExternalInputs':external,'suites':proof,'ui':'never reused; all 11 must pass on corrected interaction-test sources','javascript':'run all 62 guards and both cross-workbook controls on this checkout'}
(out/'SCOPED_REUSE.json').write_text(json.dumps(report,indent=2)+'\n')
if proof['swift']['identical']:shutil.copy2(swift,out/'verified-reused-swift-412.log')
if proof['native']['identical']:
 shutil.copy2(summary,out/'verified-reused-native-23.xcresult.summary.json')
 shutil.copy2(baseline/'native-23.log',out/'verified-reused-native-23.log')
for k,v in proof.items():print(k,'REUSE PROVEN' if v['identical'] else 'MUST RERUN')
