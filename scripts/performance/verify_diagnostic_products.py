"""Verify an explicit composite; this never certifies functional app tests."""
import hashlib,json,subprocess,sys
from pathlib import Path

def manifest(root):
    files={}
    for p in sorted(root.rglob('*')):
        if p.is_file():
            assert root.resolve() in p.resolve().parents
            files[str(p.relative_to(root))]=hashlib.sha256(p.read_bytes()).hexdigest()
    return files

def verify(root,proof):
    d=json.loads(proof.read_text());assert d['diagnosticUIRunnerOnly'] and d['appAndNativeBinariesUnmodified']
    assert d['sourceSHA']==subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    assert d['files']==manifest(root)
    assert d['xcode']==subprocess.check_output(['xcodebuild','-version'],text=True).strip()
    original=json.loads(Path(d['originalProofPath']).read_text())
    assert hashlib.sha256(Path(d['originalProofPath']).read_bytes()).hexdigest()==d['originalProofSHA256']
    prefix='Debug-iphonesimulator/DANPERInteractionTests-Runner.app/'
    assert {k:v for k,v in d['files'].items() if not k.startswith(prefix)}=={k:v for k,v in original['files'].items() if not k.startswith(prefix)}
    print('PASS: diagnostic-only UI runner composition; sealed app and native binaries unchanged. NOT app approval.')

if __name__=='__main__':verify(Path(sys.argv[1]),Path(sys.argv[2]))
