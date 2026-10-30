#!/usr/bin/env python3
"""Seal/verify SAME-HEAD test binaries, preserving executable modes via tar."""
import hashlib,json,re,subprocess,sys
from pathlib import Path

mode,folder,proof=sys.argv[1:];root=Path(folder);path=Path(proof)
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
tree=subprocess.check_output(['git','rev-parse','HEAD^{tree}'],text=True).strip()
def manifest():
    files={}
    for f in sorted(root.rglob('*')):
        if f.is_file():
            assert root.resolve() in f.resolve().parents, 'Product symlink escaped compiled bundle'
            files[str(f.relative_to(root))]=hashlib.sha256(f.read_bytes()).hexdigest()
    assert files and any(x.endswith('.xctestrun') for x in files)
    return files
if mode=='seal':
    summaries=list(path.parent.glob('native-*.xcresult.summary.json'))
    assert len(summaries)==1
    data=json.loads(summaries[0].read_text())
    n=sum(len(re.findall(r'func (test\w+)\(',p.read_text())) for p in Path('native-ios/NativeTests').glob('*.swift'))
    assert data['totalTestCount']==data['passedTests']==n
    assert data['failedTests']==data['skippedTests']==data.get('expectedFailures',0)==0 and not data.get('testFailures')
    path.write_text(json.dumps({'sourceSHA':head,'sourceTree':tree,'nativeCount':n,
        'xcode':subprocess.check_output(['xcodebuild','-version'],text=True).strip(),
        'nativeSummarySHA256':hashlib.sha256(summaries[0].read_bytes()).hexdigest(),
        'files':manifest()},indent=2))
elif mode=='verify':
    data=json.loads(path.read_text())
    assert data['sourceSHA']==head and data['sourceTree']==tree, 'Compiled tests belong to another HEAD'
    assert data['xcode']==subprocess.check_output(['xcodebuild','-version'],text=True).strip()
    assert data['files']==manifest(), 'Compiled products changed'
else:raise ValueError(mode)
print('PASS: same-HEAD compiled products, exact file hashes and native results verified')
