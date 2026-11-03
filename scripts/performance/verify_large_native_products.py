"""Fresh diagnostic product proof, never fabricated functional/native approval."""
import hashlib,json,subprocess,sys
from pathlib import Path

def manifest(root):
 files={}
 for p in sorted(root.rglob('*')):
  if p.is_file():
   assert root.resolve() in p.resolve().parents
   files[str(p.relative_to(root))]=hashlib.sha256(p.read_bytes()).hexdigest()
 return files
if __name__=='__main__':
 mode,folder,proof=sys.argv[1:];root=Path(folder);p=Path(proof)
 head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
 # No product source edit is permitted; only the extra NativeTests fixture.
 subprocess.run(['git','diff','--exit-code','HEAD','--','native-ios/App','native-ios/Sources','native-ios/project.yml'],check=True)
 fixture=Path('native-ios/NativeTests/N2LargeRosterProfileFixture.swift')
 fixture_sha=hashlib.sha256(fixture.read_bytes()).hexdigest()
 synthetic_sha=hashlib.sha256(Path('native-ios/NativeTests/SyntheticFixtures/n2-synthetic-clinical.json').read_bytes()).hexdigest()
 xcode=subprocess.check_output(['xcodebuild','-version'],text=True).strip()
 if mode=='seal':
  assert any(n.endswith('.xctestrun') for n in manifest(root))
  p.write_text(json.dumps({'sourceSHA':head,'xcode':xcode,'files':manifest(root),'fixtureSHA256':fixture_sha,'syntheticFixtureSHA256':synthetic_sha,
   'diagnosticNativeLoadOnly':True,'appCoreSourcesUnmodified':True,'freshBuildNotOriginalArtifact':True,
   'allNativeTestsApproved':False,'allUITestsApproved':False,'IPA':False},indent=2))
 elif mode=='verify':
  d=json.loads(p.read_text());assert d['diagnosticNativeLoadOnly'] and d['appCoreSourcesUnmodified']
  assert d['sourceSHA']==head and d['xcode']==xcode and d['fixtureSHA256']==fixture_sha and d['syntheticFixtureSHA256']==synthetic_sha and d['files']==manifest(root)
 else:raise ValueError(mode)
 print('PASS diagnostic-only fresh native load products; no full app/UI approval inferred')
