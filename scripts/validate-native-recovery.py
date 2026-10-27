#!/usr/bin/env python3
"""Promote unchanged IPA bytes only after real prior gates and exact-source XCTest pass."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import zipfile


def certify(a):
    source=os.environ['DANPER_SOURCE_SHA'];recipe=os.environ['GITHUB_SHA']
    prior=json.loads(a.prior_run.read_text())
    assert prior['id']==40532104867 and prior['head_sha']==source
    jobs=json.loads(a.prior_jobs.read_text())['jobs']
    expected_jobs={122287646596:'build',122292961858:'clinical_javascript_and_swift_macos',122287646414:'swift_linux'}
    gates={}
    for job_id,label in expected_jobs.items():
        job=next(j for j in jobs if j['id']==job_id)
        assert job['conclusion']=='success',job
        gates[label]={'status':'PASS','job_id':job_id,'run_id':prior['id']}
    rows=[json.loads(s) for s in (a.acceptance/'TEST_RESULTS.jsonl').read_text().splitlines()]
    assert rows and all(r['status']=='PASS' and r['source_sha']==source and r['recipe_sha']==recipe for r in rows)
    expected={'DANPERNativeTests':15,'DANPERNativeTests/N2PremiumDemoFixtureTests':1}
    for p in Path('native-ios/InteractionTests').glob('*.swift'):
        s=p.read_text();cls=re.search(r'final class (\w+)\s*:',s)
        if cls:
            for method in re.findall(r'func (test\w+)\s*\(',s):expected[f'DANPERInteractionTests/{cls[1]}/{method}']=1
    assert len(expected)==9,expected
    assert {r['selector'] for r in rows}==set(expected)
    assert len(rows)==len(expected),'Duplicate test records'
    for r in rows:
        s=r['summary'];assert s['passedTests']==expected[r['selector']] and s['failedTests']==0 and s['skippedTests']==0
        assert s['totalTestCount']==expected[r['selector']]
        assert s['result']=='Passed' and s['expectedFailures']==0
        assert s['devicesAndConfigurations']
        assert all(c['device']['modelName']=='iPhone 16' and c['device']['platform']=='iOS Simulator' for c in s['devicesAndConfigurations'])
        assert all(c['device']['osVersion'].split('.')[:2]==['18','5'] for c in s['devicesAndConfigurations']),s
    d=json.loads((a.candidate/'BUILD_PROVENANCE.json').read_text())
    assert d['commit']==source and d['status']=='CANDIDATE_UNSIGNED_NOT_CLINICALLY_VALIDATED'
    assert d['signed'] is False and d['architecture']=='arm64' and d['platform']=='iOS'
    ipa=a.candidate/d['ipa'];digest=hashlib.sha256(ipa.read_bytes()).hexdigest()
    assert digest==d['sha256']
    assert (a.candidate/'SHA256SUMS.txt').read_text().split()[0]==digest
    spec=importlib.util.spec_from_file_location('ipa_verifier','scripts/verify-native-ipa.py')
    verifier=importlib.util.module_from_spec(spec);spec.loader.exec_module(verifier)
    prefix='Payload/DANPERNative.app/'
    with zipfile.ZipFile(ipa) as z:
        assert z.testzip() is None
        names=z.namelist();assert len(names)==len(set(names))
        for name in names:
            assert name.startswith('Payload/') and '..' not in PurePosixPath(name).parts
            assert name=='Payload/' or name.startswith(prefix)
            assert not any(x in ('_CodeSignature','SyntheticFixtures','Documents','Library') for x in PurePosixPath(name).parts)
            assert not name.lower().endswith(('.mobileprovision','.danperbackup','.xlsx','.xls','.csv','.db','.sqlite','.sqlite3','.p12','.pfx','.pem','.key','.cer','.crt'))
        info=plistlib.loads(z.read(prefix+'Info.plist'))
        assert info['CFBundleIdentifier']=='pe.danper.saludmovil.native.preview'
        assert info['CFBundleExecutable']=='DANPERNative' and info.get('NSFaceIDUsageDescription')
        assert info['CFBundleShortVersionString']=='0.4.1' and info['CFBundleVersion']=='11'
        assert info['CFBundleSupportedPlatforms']==['iPhoneOS'] and info['UILaunchStoryboardName']=='LaunchScreen'
        assert prefix+'Assets.car' in names and any('/LaunchScreen.storyboardc/' in n for n in names)
        icons=info['CFBundleIcons']['CFBundlePrimaryIcon']['CFBundleIconFiles']
        assert any(n.startswith(prefix+icon) and n.endswith('.png') for icon in icons for n in names)
        assert verifier.inspect_macho(z.read(prefix+'DANPERNative'))=={'architecture':'arm64','platform':'iOS','signed':False}
        rp=prefix+'N1sDemoResources/'
        actual={n[len(rp):] for n in names if n.startswith(rp) and not n.endswith('/')}
        assert actual==verifier.RESOURCES==set(d['resource_sha256'])
        for n,sha in d['resource_sha256'].items():assert hashlib.sha256(z.read(rp+n)).hexdigest()==sha
    a.output.mkdir(parents=True,exist_ok=False)
    filename=f'DANPER_NATIVE_0.4.1_11_{source[:12]}_VALIDATED_UNSIGNED.ipa'
    shutil.copy2(ipa,a.output/filename)
    d.update(status='VALIDATED_UNSIGNED',ipa=filename,original_candidate=ipa.name,
             compiled_source_commit=source,test_source_commit=source,validation_recipe_commit=recipe,
             validation_run_url=f"https://github.com/{os.environ['GITHUB_REPOSITORY']}/actions/runs/{os.environ['GITHUB_RUN_ID']}",
             validation={'prior_gates':gates,'xctest':rows},promotion='Same IPA bytes; all required exact-source gates and XCTest passed')
    (a.output/'BUILD_PROVENANCE.json').write_text(json.dumps(d,indent=2)+'\n')
    (a.output/'SHA256SUMS.txt').write_text(f'{digest}  {filename}\n')
    (a.output/'VALIDATED_SHA.txt').write_text(source+'\n')
    print(json.dumps({'source_sha':source,'recipe_sha':recipe,'status':d['status'],'sha256':digest}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('candidate','acceptance','prior-run','prior-jobs','output'):p.add_argument('--'+name,type=Path,required=True)
    certify(p.parse_args())
