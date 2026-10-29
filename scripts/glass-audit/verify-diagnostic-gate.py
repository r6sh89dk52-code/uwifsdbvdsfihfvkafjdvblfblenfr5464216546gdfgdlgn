#!/usr/bin/env python3
"""Aggregate individual genuine passes only when each case's inputs are equal."""
import json,re,subprocess,sys
from pathlib import Path
root,request=Path(sys.argv[1]),json.loads(Path(sys.argv[2]).read_text())
methods={
 'N2BiometricInteractionTests':'testAutomaticBiometryCancellationRetryAndForeground',
 'N2PremiumRedesignTests':'testDemoNavigationAttentionAndVersion',
 'N3ClinicalJourneyTests':'testProtectedClinicalSourceCreationAndRelaunch'}
entries=request['diagnostics'];assert len(entries)==3 and {e['class'] for e in entries}==set(methods)
def git(*args):return subprocess.check_output(['git',*args],text=True).strip()
common=['native-ios/App','native-ios/Sources','native-ios/NativeTests','native-ios/Package.swift','native-ios/Package.resolved','native-ios/project.yml','native-ios/scripts','src','package.json','package-lock.json','scripts/prepare-n1s-ios-demo-resources.cjs','scripts/glass-audit/prepare.sh']
proof=[];toolchains=set();devices=set()
for e in entries:
 cls=e['class'];expected=cls+'/'+methods[cls]
 assert isinstance(e['run'],int) and e['run']>0 and isinstance(e['artifact'],int) and e['artifact']>0
 assert re.fullmatch('[0-9a-f]{40}',e['sourceSHA'])
 p=root/('run-'+str(e['run']));sha=(p/'SOURCE_SHA.txt').read_text().strip();assert sha==e['sourceSHA']
 assert (p/'BUILD_SUCCESS_SHA.txt').read_text().strip()==sha
 assert expected in (p/'selected-cases.txt').read_text().splitlines()
 assert '-only-testing:DANPERInteractionTests/'+expected in (p/(cls+'.log')).read_text()
 s=json.loads((p/(cls+'.xcresult.summary.json')).read_text())
 assert s['totalTestCount']==1 and s['passedTests']==1 and s['failedTests']==0 and s['skippedTests']==0 and not s.get('testFailures'),cls
 assert (p/(cls+'-PASS_SHA.txt')).read_text().strip()==sha
 if cls=='N2PremiumRedesignTests':
  seed=json.loads((p/('seed-'+cls+'.xcresult.summary.json')).read_text())
  assert seed['totalTestCount']==2 and seed['passedTests']==2 and seed['failedTests']==0 and seed['skippedTests']==0
 paths=common+['native-ios/InteractionTests/'+cls+'.swift']
 if cls!='N2PremiumRedesignTests':
  paths+=['scripts/glass-audit/attach-simulator-display.sh','scripts/glass-audit/enroll-simulator.sh','scripts/glass-audit/prepare-auth-ui.sh','scripts/glass-audit/simulator-ready-bridge.py','native-ios/InteractionTests/SimulatorBiometricEvents.swift']
 # Premium explicitly launches DEMO and never invokes LAContext. Auth process
 # preparation is not one of its code/data inputs; its fixture and own source are.
 subprocess.run(['git','diff','--exit-code',sha,'HEAD','--',*paths],check=True)
 changed=git('diff','--name-only',sha,'HEAD').splitlines()
 allowed_tests={'native-ios/InteractionTests/'+c+'.swift' for c in methods if c!=cls}
 if cls=='N2PremiumRedesignTests':allowed_tests.add('native-ios/InteractionTests/SimulatorBiometricEvents.swift')
 unknown=[v for v in changed if v not in allowed_tests and not v.startswith(('.github/','docs/','scripts/glass-audit/'))]
 assert not unknown,('Unreviewed external input changes',cls,unknown)
 toolchains.add((p/'xcode-version.txt').read_text())
 device=s['devicesAndConfigurations'][0]['device']
 devices.add((device['architecture'],device['osVersion'],device['osBuildNumber']))
 trees={v:git('rev-parse','HEAD:'+v) for v in paths}
 proof.append({**e,'test':expected,'passed':1,'failed':0,'skipped':0,'identicalInputTrees':trees})
assert len(toolchains)==1 and len(devices)==1
arch,version,build=devices.pop()
report={'currentSHA':git('rev-parse','HEAD'),'cases':proof,'xcodeVersion':toolchains.pop(),'architecture':arch,'runtimeVersion':version,'runtimeBuild':build,'allThreePassed':True,'overallFailedRunsAreNotRelabeled':True}
# A simulator build may be reused only when its ENTIRE native tree (including
# all UI methods), external resources and compiler inputs equal this checkout.
report['simulatorBuild']=None
for e in entries:
 sha=e['sourceSHA']
 buildpaths=['native-ios','src','package.json','package-lock.json','scripts/prepare-n1s-ios-demo-resources.cjs','scripts/glass-audit/prepare.sh']
 same=subprocess.run(['git','diff','--quiet',sha,'HEAD','--',*buildpaths]).returncode==0
 if same:
  cachekey='glass-ui-'+report['architecture']+'-'+report['xcodeVersion'].replace(' ','_').replace('\n','_')+'-'+sha
  report['simulatorBuild']={'sourceSHA':sha,'run':e['run'],'artifact':e['artifact'],'cacheKey':cachekey,'nativeTree':git('rev-parse',sha+':native-ios'),'currentNativeTree':git('rev-parse','HEAD:native-ios')}
  break
(root/'DIAGNOSTIC_GATE.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: all three individual cases, identical relevant inputs, pinned run/artifact/SHA provenance')
