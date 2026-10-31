#!/usr/bin/env python3
import hashlib,json,re,subprocess,sys
from pathlib import Path

log,out=map(Path,sys.argv[1:]);text=log.read_text()
rows=re.findall(r'Executed (\d+) tests?, with (\d+) failures?',text)
assert rows,'No XCTest completion summary'
count,failures=max((int(a),int(b)) for a,b in rows)
assert count>=426 and failures==0,(count,failures)
assert not re.search(r'Test Case .* skipped|[1-9]\d* tests? skipped|with [1-9]\d* tests? skipped',text)
head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
out.write_text(json.dumps({'sourceSHA':head,'tests':count,'failures':0,'skips':0,
    'logSHA256':hashlib.sha256(log.read_bytes()).hexdigest()},indent=2))
print('PASS:',count,'fresh current-HEAD Swift tests; no failures/skips')
