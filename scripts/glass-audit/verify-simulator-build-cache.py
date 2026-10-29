#!/usr/bin/env python3
"""Reuse binaries, never UI verdicts; require exact code tree/toolchain/cache key."""
import hashlib,json,os,plistlib,subprocess,sys
from pathlib import Path
out=Path(sys.argv[1]);dd=out/'DerivedData';report={'reused':False}
try:
 gate=json.loads((out/'DIAGNOSTIC_GATE.json').read_text());build=gate.get('simulatorBuild')
 assert build and build['nativeTree']==build['currentNativeTree']
 assert os.environ.get('DANPER_RESTORED_CACHE_KEY')==build['cacheKey']
 current=subprocess.check_output(['git','rev-parse','HEAD:native-ios'],text=True).strip()
 assert current==build['nativeTree']
 products=dd/'Build/Products/Debug-iphonesimulator'
 app=products/'DANPERNative.app';runner=products/'DANPERInteractionTests-Runner.app'
 bundles=[app,runner,runner/'PlugIns/DANPERInteractionTests.xctest']
 natives=list(products.rglob('DANPERNativeTests.xctest'));assert natives
 bundles+=natives
 # Generated resources are ignored by Git; compare their actual bytes too.
 resource_count=0
 for source,target in [(Path('native-ios/App/N1sDemoResources'),app/'N1sDemoResources'),(Path('native-ios/NativeTests/SyntheticFixtures'),natives[0]/'SyntheticFixtures')]:
  if source.exists():
   current_files={str(p.relative_to(source)) for p in source.rglob('*') if p.is_file()}
   cached_files={str(p.relative_to(target)) for p in target.rglob('*') if p.is_file()}
   assert current_files==cached_files,(source,'resource inventory changed')
   for name in current_files:
    assert (source/name).read_bytes()==(target/name).read_bytes(),(source,name,'resource bytes changed')
    resource_count+=1
 generated_areas=Path('native-ios/App/DANPEROfficialAreas.json')
 if generated_areas.exists():
  assert generated_areas.read_bytes()==(app/'DANPEROfficialAreas.json').read_bytes()
  resource_count+=1
 assert list((dd/'Build/Products').glob('*.xctestrun'))
 hashes={}
 for bundle in bundles:
  info=plistlib.loads((bundle/'Info.plist').read_bytes())
  exe=bundle/info['CFBundleExecutable'];assert exe.is_file()
  arch=subprocess.check_output(['lipo','-archs',str(exe)],text=True).strip()
  assert arch==gate['architecture'],(exe,arch)
  subprocess.run(['codesign','--verify','--deep',str(bundle)],check=True,capture_output=True)
  for p in bundle.rglob('*'):
   if p.is_file():hashes[str(p.relative_to(dd))]=hashlib.sha256(p.read_bytes()).hexdigest()
 assert plistlib.loads((app/'Info.plist').read_bytes())['CFBundleSupportedPlatforms']==['iPhoneSimulator']
 (out/'SIMULATOR_BUILD_FILES_SHA256.json').write_text(json.dumps(hashes,indent=2)+'\n')
 report.update(reused=True,provenance=build,codeInputSHA=gate['currentSHA'],files=len(hashes),generatedResourcesCompared=resource_count,uiResultsReused=False)
except (AssertionError,OSError,KeyError,ValueError,subprocess.SubprocessError) as e:
 report['reason']=str(e) or type(e).__name__
(out/'SIMULATOR_BUILD_REUSE.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: identical signed simulator build cache verified' if report['reused'] else 'Simulator binaries require rebuilding: '+report['reason'])
sys.exit(0 if report['reused'] else 1)
