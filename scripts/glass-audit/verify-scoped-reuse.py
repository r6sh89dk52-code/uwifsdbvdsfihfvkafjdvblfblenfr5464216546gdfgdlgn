#!/usr/bin/env python3
"""Use pinned final ARM64 evidence; prove every actual Swift input is unchanged."""
import hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
baseline,out=map(Path,sys.argv[1:3]);out.mkdir(parents=True,exist_ok=True)
def git(*args):return subprocess.check_output(['git',*args],text=True).strip()
ref='2b76453cd51b2998ac300d9c6d435ec871b56cc1'
assert (baseline/'SOURCE_SHA.txt').read_text().strip()==ref
assert (baseline/'SWIFT_VALIDATED_SHA.txt').read_text().strip()==ref
log=baseline/'swift-412.log'
assert hashlib.sha256(log.read_bytes()).hexdigest()=='29766122b94011a27d2820d9cca429458ba10c5b08851b9c032688ba44ca4743'
assert re.search(r'Executed 412 tests, with 0 failures',log.read_text())
assert not re.search(r'\d+ tests? (?:were )?skipped',log.read_text())
subprocess.run(['git','diff','--exit-code','HEAD','--','native-ios','src','package.json','package-lock.json'],check=True)
common=['native-ios/Package.swift','native-ios/Package.resolved','native-ios/Sources','native-ios/Tests','src','package.json','package-lock.json','scripts/glass-audit/prepare.sh']
# Swift package tests consume these sources plus fixture/template/generator inputs.
# UI/app and pipeline files are not compiled/imported by Swift Package targets.
# This one modified Node guard only hashes UI assets; it produces no Swift fixtures.
ignore=('.github/','docs/','scripts/glass-audit/','native-ios/App/','native-ios/NativeTests/','native-ios/InteractionTests/','native-ios/scripts/')
ignorefiles={'native-ios/project.yml','scripts/test-n2-glass-clinical.cjs','scripts/test-n2-build222-ui-parity.cjs'}
external=[p for p in git('diff','--name-only',ref,'HEAD').splitlines() if p not in ignorefiles and not p.startswith(ignore)]
xcode=(out/'xcode-version.txt').read_bytes()==(baseline/'xcode-version.txt').read_bytes()
arch=(out/'architecture.txt').read_bytes()==(baseline/'architecture.txt').read_bytes()
rows={p:{'baseline':git('rev-parse',ref+':'+p),'current':git('rev-parse','HEAD:'+p)} for p in common}
identical=all(v['baseline']==v['current'] for v in rows.values()) and not external and xcode and arch
report={'currentSHA':git('rev-parse','HEAD'),'baselineRun':40861610616,'baselineArtifact':12893306113,
 'baselineSHA':ref,'xcodeIdentical':xcode,'architectureIdentical':arch,'changedExternalInputs':external,
 'reviewedNonSwiftGuard':'scripts/test-n2-glass-clinical.cjs (UI asset digest only; no Swift fixtures)',
 'suites':{'swift':{'baselineSHA':ref,'inputs':rows,'identical':identical,'evidenceSHA256':hashlib.sha256(log.read_bytes()).hexdigest()},
 'native':{'baselineSHA':ref,'identical':False,'reason':'App/avatar/build and native greeting tests changed; run all26'}},
 'ui':'never reused; all11 UI execute on current code','javascript':'all62 guards execute because app/assets/build/guard inputs changed'}
(out/'SCOPED_REUSE.json').write_text(json.dumps(report,indent=2)+'\n')
if identical:shutil.copy2(log,out/'verified-reused-swift-412.log')
print('Swift:','REUSE PROVEN' if identical else 'MUST RERUN','; native: MUST RERUN26; UI: MUST RERUN11; JS: MUST RERUN62')
