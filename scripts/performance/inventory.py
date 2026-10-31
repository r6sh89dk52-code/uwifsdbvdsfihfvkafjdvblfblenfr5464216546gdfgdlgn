#!/usr/bin/env python3
"""Static action map, explicitly separate from measured behavior."""
import json,re,sys
from pathlib import Path

out=Path(sys.argv[1]);out.parent.mkdir(parents=True,exist_ok=True)
files=[]
for path in sorted(Path('native-ios/App').glob('*.swift')):
    source=path.read_text();actions=[];owner='declaration'
    for number,line in enumerate(source.splitlines(),1):
        method=re.search(r'\bfunc\s+(\w+)',line)
        if method:owner=method[1]
        elif re.search(r'\bvar\s+body\s*:',line):owner='body'
        kind=re.search(r'\b(Button|NavigationLink|DanperToolLink|DanperChoiceField|DanperInlineSearch|fileImporter|fileExporter)\b',line)
        calls=re.findall(r'\bvault\s*\.\s*(\w+)',line)
        if kind or calls:
            literal=re.search(r'"([^"\n]*)"',line)
            actions.append({'line':number,'owner':owner,'kind':kind[1] if kind else 'vault call',
                'label':literal[1] if literal else None,'vaultCalls':calls,'measurement':'not implied by static inventory'})
    files.append({'path':str(path),'views':re.findall(r'struct\s+(\w+)\s*:\s*View',source),
                  'actions':actions,'tasks':len(re.findall(r'\bTask\s*[<{]',source)),
                  'mainActorAnnotations':source.count('@MainActor')})
out.write_text(json.dumps({'kind':'static source inventory; not an execution trace','files':files},indent=2,ensure_ascii=False))
print('Static inventory:',len(files),'Swift files,',sum(len(f['actions']) for f in files),'action/call sites')
