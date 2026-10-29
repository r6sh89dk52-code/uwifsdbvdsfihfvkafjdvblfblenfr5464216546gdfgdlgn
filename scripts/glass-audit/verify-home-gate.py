#!/usr/bin/env python3
"""Gate final validation on actual affected home/access passes and equal inputs."""
import json,subprocess,sys
from pathlib import Path
root,request=Path(sys.argv[1]),json.loads(Path(sys.argv[2]).read_text())
e=request['targetedHome'];ref=e['sourceSHA'];p=root/('run-'+str(e['run']))
def git(*args):return subprocess.check_output(['git',*args],text=True).strip()
assert len(ref)==40 and (p/'SOURCE_SHA.txt').read_text().strip()==ref
for marker in ['BUILD_SUCCESS_SHA.txt','ACCESS_VISUAL_PASS_SHA.txt']:assert (p/marker).read_text().strip()==ref
expected={
 'iPhone-16':(4,['DANPERInteractionTests/N2GlassClinicalTests','DANPERInteractionTests/N2PremiumRedesignTests/testAccessLightAndDark']),
 'iPhone-SE-3rd-generation':(2,['DANPERInteractionTests/N2GlassClinicalTests/testLocalDisplayNamePersistsWithoutChangingClinicalIdentity','DANPERInteractionTests/N2PremiumRedesignTests/testAccessLightAndDark']),
 'greeting-native':(3,['DANPERNativeTests/DanperGreetingTests']),
 'seed-iPhone-16':(2,['DANPERNativeTests/N2PremiumDemoFixtureTests','DANPERNativeTests/N2SimpleInventoryNativeTests']),
 'seed-iPhone-SE-3rd-generation':(2,['DANPERNativeTests/N2PremiumDemoFixtureTests','DANPERNativeTests/N2SimpleInventoryNativeTests'])}
proof=[];devices=[]
for label,(count,selectors) in expected.items():
 s=json.loads((p/(label+'.xcresult.summary.json')).read_text())
 assert s['totalTestCount']==count and s['passedTests']==count and s['failedTests']==0 and s['skippedTests']==0 and not s.get('testFailures'),label
 log=(p/(label+'.log')).read_text()
 for selector in selectors:assert '-only-testing:'+selector in log,(label,selector)
 device=s['devicesAndConfigurations'][0]['device'];devices.append(device)
 proof.append({'label':label,'passed':count,'failed':0,'skipped':0,'selectors':selectors})
paths=['native-ios','src','package.json','package-lock.json','scripts/prepare-n1s-ios-demo-resources.cjs','scripts/glass-audit/prepare.sh','scripts/glass-audit/access-visual.sh','scripts/glass-audit/identity.cjs','scripts/test-n2-glass-clinical.cjs','scripts/test-n2-premium-redesign.cjs','scripts/test-n2-build222-ui-parity.cjs']
subprocess.run(['git','diff','--exit-code',ref,'HEAD','--',*paths],check=True)
unknown=[v for v in git('diff','--name-only',ref,'HEAD').splitlines() if not v.startswith(('.github/','docs/','scripts/glass-audit/'))]
assert not unknown,unknown
architectures={d['architecture'] for d in devices};runtimes={(d['osVersion'],d['osBuildNumber']) for d in devices}
assert len(architectures)==1 and architectures <= {'arm64','x86_64'} and len(runtimes)==1
arch=architectures.pop()
version,build=runtimes.pop();xcode=(p/'xcode-version.txt').read_text()
assert (p/'architecture.txt').read_text().strip()==arch
report={'currentSHA':git('rev-parse','HEAD'),'targetedPassed':True,'cases':proof,'targetedSource':e,
 'architecture':arch,'runtimeVersion':version,'runtimeBuild':build,'xcodeVersion':xcode,
 'identicalInputTrees':{v:git('rev-parse','HEAD:'+v) for v in paths},
 'simulatorBuild':{'sourceSHA':ref,'run':e['run'],'artifact':e['artifact'],
  'cacheKey':'glass-ui-'+arch+'-'+xcode.replace(' ','_').replace('\n','_')+'-'+ref,
  'nativeTree':git('rev-parse',ref+':native-ios'),'currentNativeTree':git('rev-parse','HEAD:native-ios')},
 'uiResultsReusedForFinal':False}
(root/'DIAGNOSTIC_GATE.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: affected home/access UI and greeting native tests; current inputs identical; all11 final UI still required')
