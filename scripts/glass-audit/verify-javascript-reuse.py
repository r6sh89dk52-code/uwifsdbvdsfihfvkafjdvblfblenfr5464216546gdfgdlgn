#!/usr/bin/env python3
"""Reuse only immutable passing JS outcomes with equal inputs and runtime."""
import hashlib,json,shutil,subprocess,sys
from pathlib import Path

def git(*args):return subprocess.check_output(['git',*args],text=True).strip()
def verify(approved,out,request):
 sha=git('rev-parse','HEAD');report={'currentSHA':sha,'reused':False,'reusedCount':0,'executedCount':0}
 try:
  origin=request['javascriptBaseline'];ref=origin['sourceSHA']
  assert (approved/'SOURCE_SHA.txt').read_text().strip()==ref
  runtime=json.loads(subprocess.check_output(['node','-p','JSON.stringify({version:process.version,platform:process.platform,arch:process.arch})'],text=True))
  assert runtime==origin['runtime'],('Node runtime changed',runtime)
  # Reviewed pipeline-only edits are not read by these 62 unchanged guards.
  allowed={'.github/glass-final-release-request.json','.github/workflows/glass-ui-release.yml','docs/GLASS_RESUME_20261029.md','scripts/glass-audit/prepare-scoped-final.sh','scripts/glass-audit/seal-controls.py','scripts/glass-audit/verify-javascript-reuse.py'}
  changed=set(git('diff','--name-only',ref,'HEAD').splitlines())
  dirty=set(git('diff','--name-only','HEAD').splitlines())
  assert (changed|dirty)<=allowed,('Unproven JS input change',sorted((changed|dirty)-allowed))
  def digest(revision):
   rows=git('ls-tree','-r',revision).splitlines()
   return hashlib.sha256(('\n'.join(r for r in rows if r.split('\t',1)[1] not in allowed)).encode()).hexdigest()
  before,after=digest(ref),digest('HEAD');assert before==after
  raw=(approved/'javascript-results.json').read_bytes();rows=json.loads(raw)
  assert len(rows)==62 and len({r['file'] for r in rows})==62 and all(r['exit']==0 for r in rows)
  identity='scripts/glass-audit/identity.cjs';assert sum(r['file']==identity for r in rows)==1
  hashes={}
  for r in rows:
   assert Path(r['file']).is_file()
   name=r['file'].replace('/','_')+'.log';data=(approved/name).read_bytes()
   hashes[name]=hashlib.sha256(data).hexdigest()
  # Identity emits the current source SHA, so execute it on this checkout.
  actual=subprocess.run(['node',identity],capture_output=True,text=True)
  if actual.returncode:
   (out/'current-identity.log').write_text(actual.stdout+actual.stderr)
   report.update(executedCount=1,currentIdentityFailed=True)
   report['reason']='Current identity guard failed; do not fall back or hide it'
   (out/'JAVASCRIPT_REUSE.json').write_text(json.dumps(report,indent=2)+'\n')
   return 2
  for r in rows:
   name=r['file'].replace('/','_')+'.log';shutil.copy2(approved/name,out/name)
   r.update(reused=r['file']!=identity,sourceSHA=ref if r['file']!=identity else sha)
  (out/(identity.replace('/','_')+'.log')).write_text(actual.stdout+actual.stderr)
  (out/'javascript-results.json').write_text(json.dumps(rows,indent=2)+'\n')
  (out/'javascript.log').write_text('61 prior PASS outcomes reused with identical inputs/runtime; current identity guard PASS.\nOriginal run log follows:\n'+(approved/'javascript.log').read_text())
  report.update(reused=True,reusedCount=61,executedCount=1,baseline=origin,identicalInputDigest=after,reviewedChangedNonInputs=sorted(changed),nodeRuntime=runtime,baselineResultsSHA256=hashlib.sha256(raw).hexdigest(),baselineLogSHA256=hashes,overallFailedRunIsNotRelabeled=True)
 except (AssertionError,OSError,ValueError,KeyError,subprocess.SubprocessError) as error:
  report['reason']=str(error) or type(error).__name__
  (out/'JAVASCRIPT_REUSE.json').write_text(json.dumps(report,indent=2)+'\n')
  print('JS identity not proven; run all 62:',report['reason']);return 1
 (out/'JAVASCRIPT_REUSE.json').write_text(json.dumps(report,indent=2)+'\n')
 print('PASS: 61 JS outcomes reused by input/runtime proof; current identity guard executed')
 return 0

if __name__=='__main__':
 approved,out=map(Path,sys.argv[1:3]);out.mkdir(parents=True,exist_ok=True)
 raise SystemExit(verify(approved,out,json.loads(Path('.github/glass-final-release-request.json').read_text())))
