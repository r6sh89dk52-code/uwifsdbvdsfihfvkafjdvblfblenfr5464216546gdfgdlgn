#!/usr/bin/env python3
"""Package ONLY a fully checked exact-source unsigned candidate, never install."""
import hashlib,json,os,plistlib,runpy,subprocess,sys,tarfile,urllib.request,zipfile
from pathlib import Path,PurePosixPath

SOURCE='3e4484663c9373c0138abec0288d617dc137f632'
REPO='r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn'
BUNDLE='pe.danper.saludmovil.native.iloaderpreview'
GATE_RUN=41885631401
# Same immutable Actions run: package only after the real compile job passed.
# SOURCE/GATE_RUN are literal, never overridden by the caller/environment.
RELEASE_RUN=int(os.environ.get('GITHUB_RUN_ID','0'))
RELEASE_WORKFLOW=os.environ.get('GITHUB_SHA','UNBOUND')

def checked_release_run(run,jobs):
    assert RELEASE_RUN>0 and len(RELEASE_WORKFLOW)==40
    assert run['id']==RELEASE_RUN and run['head_sha']==RELEASE_WORKFLOW
    assert run['path']=='.github/workflows/b15-arm64-release-check.yml'
    assert run['head_branch']=='audit/b15-profile-device-9143997-20261101'
    assert run['event']=='push' and run['status']=='in_progress' and run['conclusion'] is None
    assert len(jobs)==3 and {j['name'] for j in jobs}=={'await-final-gates','arm64-release','package'}
    by={j['name']:j for j in jobs}
    assert all(by[n]['status']=='completed' and by[n]['conclusion']=='success' for n in ['await-final-gates','arm64-release'])
    assert by['package']['status']=='in_progress' and by['package']['conclusion'] is None


def checked_gate(g):
    assert g['sourceSHA']==SOURCE,'Earlier source is not current certification'
    assert g['swift']==439 and g['native']==30 and g['javascript']==62
    assert g['ui']=={'N2MenuInteractionTests':1,'N2Build222ShellTests':1,'N2GlassClinicalTests':3,
      'N3ClinicalJourneyTests-protected':1,'N3ClinicalJourneyTests-demo':2,'N2PremiumRedesignTests':2,
      'N2BiometricInteractionTests':2,'N2AllergySaveInteractionTests':2}
    assert g['failures']==g['skips']==0 and g['IPA'] is False
    b=g['corePerformanceBudgets'];assert b['failures']==0 and len(b['checks'])==9
    measured=runpy.run_path('scripts/performance/core-budgets.py')['validate'](g['physicalV2Performance'])
    assert b==measured,'Saved budgets do not match raw current measurements'
    c=g['build14ForwardCompatibility'];assert c['sourceSHA']==SOURCE
    assert c['producerSHA']=='9b1da6d4cdead4729bcade6843abcbcfc287e870'
    assert c['tests']==1 and c['failures']==0
    assert all(c[k] for k in ['build14JournalRead','build14BackupRead','historicalRectificationPersisted','newBackupRoundTrip','stockUnchanged','workersAndOriginalVisitsUnchanged'])
    return g

def get(path):
    request=urllib.request.Request('https://api.github.com/repos/'+REPO+'/'+path,
      headers={'Authorization':'Bearer '+os.environ['GH_TOKEN'],'Accept':'application/vnd.github+json'})
    return json.load(urllib.request.urlopen(request,timeout=30))

def current_pr():
    p=get('pulls/10')
    assert p['head']['sha']==SOURCE and p['draft'] and not p['merged']
    assert p['base']['sha']=='9b1da6d4cdead4729bcade6843abcbcfc287e870'

def current_runs():
    current_pr()
    assert os.environ['GITHUB_REPOSITORY']==REPO and os.environ['GITHUB_JOB']=='package'
    run=get('actions/runs/'+str(GATE_RUN))
    assert run['head_sha']==SOURCE and run['status']=='completed' and run['conclusion']=='success'
    release=get('actions/runs/'+str(RELEASE_RUN))
    release_jobs=get('actions/runs/'+str(RELEASE_RUN)+'/jobs?per_page=100')['jobs']
    checked_release_run(release,release_jobs)
    # Optional historical profiling experiments do not substitute for any
    # mandatory final-source job. Require the complete current workflow,
    # including its current Instruments and 14 genuine UI cases.
    gate=get('actions/runs/'+str(GATE_RUN))
    assert gate['path']=='.github/workflows/b15-site-allergy-performance-gate.yml'
    jobs=get('actions/runs/'+str(GATE_RUN)+'/jobs?per_page=100')['jobs']
    suites=['N2MenuInteractionTests','N2Build222ShellTests','N2GlassClinicalTests',
      'N3ClinicalJourneyTests-protected','N3ClinicalJourneyTests-demo','N2PremiumRedesignTests',
      'N2BiometricInteractionTests','N2AllergySaveInteractionTests']
    expected={'javascript','native-build','performance','performance-v2','swift-core / swift-core','instruments','complete'}|{'ui ('+x+')' for x in suites}
    assert len(jobs)==len(expected) and {j['name'] for j in jobs}==expected
    assert all(j['status']=='completed' and j['conclusion']=='success' for j in jobs)

def digest(data):return hashlib.sha256(data).hexdigest()
def manifest(app):return {str(f.relative_to(app)):digest(f.read_bytes()) for f in sorted(app.rglob('*')) if f.is_file()}
def safe_member(name):
    path=PurePosixPath(name)
    assert not path.is_absolute() and '..' not in path.parts and path.parts[0]=='DANPERNative.app'

def main():
    root=Path(os.environ['DANPER_PACKAGE_ROOT']).resolve();root.mkdir(parents=True,exist_ok=True)
    checked_gate(json.loads((root/'gates/FINAL_GATES.json').read_text()))
    current_runs()
    proof=root/'release';identity=json.loads((proof/'RELEASE_IDENTITY.json').read_text())
    assert (proof/'SOURCE_SHA.txt').read_text().strip()==SOURCE
    assert identity['sourceSHA']==SOURCE and identity['workflowSHA']==RELEASE_WORKFLOW
    assert identity['bundleID']==BUNDLE and identity['sameBundleAsBuild14']
    assert identity['version']=='0.4.2' and identity['build']=='15' and identity['architecture']=='arm64'
    assert not identity['signed'] and not identity['IPA'] and not identity['clinicalDatasetsBundled'] and identity['testClockAbsent']
    payload=root/'package/Payload';payload.mkdir(parents=True,exist_ok=True)
    app=payload/'DANPERNative.app';assert not app.exists()
    with tarfile.open(proof/'COMPILED_ARM64_APP.tgz') as t:
        members=t.getmembers()
        for m in members:safe_member(m.name);assert m.isdir() or m.isfile()
        t.extractall(payload,filter='data')
    original=json.loads((proof/'APP_SHA256.json').read_text());assert len(original)==22 and manifest(app)==original
    p=plistlib.loads((app/'Info.plist').read_bytes())
    assert p['CFBundleIdentifier']==BUNDLE and p['CFBundleShortVersionString']=='0.4.2' and p['CFBundleVersion']=='15'
    assert p['CFBundleSupportedPlatforms']==['iPhoneOS'] and p['MinimumOSVersion']=='17.0'
    assert p['NSFaceIDUsageDescription'] and p['UILaunchStoryboardName']=='LaunchScreen'
    assert list(app.rglob('LaunchScreen.storyboardc'))
    assert not (app/'embedded.mobileprovision').exists() and not (app/'_CodeSignature').exists()
    assert not list(app.rglob('*.xctest')) and not list(app.rglob('SyntheticFixtures'))
    exe=app/p['CFBundleExecutable'];assert os.access(exe,os.X_OK)
    assert subprocess.check_output(['lipo','-archs',str(exe)],text=True).strip()=='arm64'
    header=subprocess.check_output(['otool','-l',str(exe)],text=True)
    assert 'LC_ENCRYPTION_INFO' not in header or 'cryptid 0' in header
    assert subprocess.run(['codesign','--verify',str(app)],capture_output=True).returncode!=0
    assert b'DANPER_GREETING_TEST_LOCAL' not in exe.read_bytes()
    assert b'diagnosticKeychainReadCount' not in exe.read_bytes()
    expected={'n1s-indicator-plan.json','n1s-indicator-template-store.zip','n1s-nursing-plan.json','n1s-nursing-template-store.zip','n2-ambulatory-products.json','n2-nursing-catalog.json','n2-approved-mappings.json','n2-organization-areas.json'}
    assert {f.name for f in (app/'N1sDemoResources').iterdir()}==expected
    assert subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()==SOURCE
    subprocess.run(['git','diff','--exit-code','HEAD','--','native-ios/App','native-ios/Sources','native-ios/project.yml'],check=True)
    assets=json.loads(subprocess.check_output(['/usr/bin/assetutil','--info',str(app/'Assets.car')]))
    names={a.get('Name') for a in assets};assert {'ClinicalAvatar','ClinicalPortrait'}<=names
    contents={'distributionResources':sorted(expected),'compiledAssetNames':sorted(n for n in names if n),
      'testClockAbsentInRelease':True,'clinicalDatasetsBundled':False}
    for name,key,expected_digest in [('ClinicalAvatar','avatarSHA256','51d79d1d46607d4b9e58599e861428790a06c55ebff391c85d28a0b5a829fdcf'),('ClinicalPortrait','portraitSHA256','c43917268ce67191a70e2b6549747229b3e7414b21c951bf4432d3257f177291')]:
        value=digest(Path('native-ios/App/Assets.xcassets',name+'.imageset',name+'.png').read_bytes());assert value==expected_digest;contents[key]=value
    provenance={'sourceSHA':SOURCE,'packagingWorkflowSHA':os.environ['GITHUB_SHA'],'gateRun':GATE_RUN,
      'releaseRun':RELEASE_RUN,'historicalProfileRun':41654953204,'historicalProfileSourceSHA':'4daba9649824b58dedc57721d8cd1ad5af035963','historicalProfileNotCurrentApproval':True,'bundleID':BUNDLE,'version':'0.4.2','build':'15',
      'architecture':'arm64','signed':False,'candidateOnly':True,'physicalDeviceValidated':False,
      'physicalContainerValidated':False,'requiresSameSigningTeamForUpdate':True,'IPA':True}
    (app/'DANPER_CONTENTS.json').write_text(json.dumps(contents,indent=2))
    (app/'DANPER_BUILD.json').write_text(json.dumps(provenance,indent=2))
    final=manifest(app);assert len(final)==24 and all(final[k]==v for k,v in original.items())
    out=root/'ipa';out.mkdir();(out/'APP_SHA256.json').write_text(json.dumps(final,indent=2))
    ipa=out/'DANPER_SALUD_MOVIL_0.4.2_15_ILOADER_UNSIGNED.ipa'
    subprocess.run(['/usr/bin/ditto','-c','-k','--norsrc','--keepParent','Payload',str(ipa)],cwd=payload.parent,check=True)
    with zipfile.ZipFile(ipa) as z:
        assert z.testzip() is None
        assert all(n.startswith('Payload/') and '..' not in PurePosixPath(n).parts for n in z.namelist())
        files=[n for n in z.namelist() if not n.endswith('/')]
        assert len(files)==len(set(files))==len(final)
        prefix='Payload/DANPERNative.app/'
        assert set(files)=={prefix+n for n in final}
        assert all(digest(z.read(prefix+n))==value for n,value in final.items())
        info=plistlib.loads(z.read(prefix+'Info.plist'));assert info['CFBundleIdentifier']==BUNDLE and info['CFBundleVersion']=='15'
    provenance['ipaSHA256']=digest(ipa.read_bytes());(out/'IPA_PROVENANCE.json').write_text(json.dumps(provenance,indent=2))
    (out/'SHA256SUMS.txt').write_text(provenance['ipaSHA256']+'  '+ipa.name+'\n')
    (out/'LIMITATIONS.txt').write_text('Unsigned Build15 candidate. Same AppleID/signing team/BundleID needed to update existing installation. Physical iPhone/container and downgrade not certified. Never uninstall existing app or reimport old history. Keep verified encrypted Build14 backup and password.\n')
    current_pr() # Fail closed if another source has advanced before artifact upload.
    print('PASS exact-source unsigned candidate ZIP/hashes/identity. No device installation performed.')
if __name__=='__main__':main()
