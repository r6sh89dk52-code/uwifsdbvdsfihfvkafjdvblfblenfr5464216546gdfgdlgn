#!/usr/bin/env python3
"""Reuse only immutable, passing Build 14 evidence; require fresh failed/missing UI."""
import hashlib
import json
import os
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

BASE = '4639b73908c1fd64f14266509bd40bfa215a5502'
RUN = 41003061702
REPO = 'r6sh89dk52-code/uwifsdbvdsfihfvkafjdvblfblenfr5464216546gdfgdlgn'
ARTIFACTS = {12957546521, 12954980903}
ALLOWED_CHANGES = {
    '.github/workflows/b11-clinical-release-gate.yml',
    'scripts/glass-audit/validate-macos.sh',
    'scripts/glass-audit/resume-build14.py',
}
REUSED_UI = {'N2Build222ShellTests': 1, 'N2GlassClinicalTests': 3,
             'N2MenuInteractionTests': 1, 'N2PremiumRedesignTests': 2}
REPLAY_UI = {'N2BiometricInteractionTests': 1, 'N3ClinicalJourneyTests-demo': 2,
             'N3ClinicalJourneyTests-protected': 1}


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def seal():
    head = git('rev-parse', 'HEAD')
    subprocess.run(['git', 'merge-base', '--is-ancestor', BASE, head], check=True)
    changed = set(git('diff', '--name-only', BASE, head).splitlines())
    assert changed <= ALLOWED_CHANGES, ('Tested inputs changed; full validation required', sorted(changed))
    # Pin the complete app/test/resource inputs, including the Build 14 identity.
    entries = subprocess.check_output(['git', 'ls-tree', '-rz', BASE]).split(b'\0')
    retained = [entry for entry in entries if entry and
                entry.split(b'\t', 1)[1].decode() not in ALLOWED_CHANGES]
    return head, hashlib.sha256(b'\0'.join(retained)).hexdigest()



def one(root, name):
    paths = list(Path(root).rglob(name))
    assert len(paths) == 1, (name, len(paths))
    return paths[0]


def passing(root, label, expected):
    path = one(root, label + '.xcresult.summary.json')
    data = json.loads(path.read_text())
    assert data['totalTestCount'] == expected and data['passedTests'] == expected, (label, data)
    assert data['failedTests'] == data['skippedTests'] == data.get('expectedFailures', 0) == 0, (label, data)
    assert not data.get('testFailures'), (label, data)
    return {'count': expected, 'summarySHA256': hashlib.sha256(path.read_bytes()).hexdigest()}


def api(path):
    request = urllib.request.Request('https://api.github.com/repos/' + REPO + '/' + path,
        headers={'Authorization': 'Bearer ' + os.environ['GITHUB_TOKEN'],
                 'Accept': 'application/vnd.github+json'})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def baseline(root, out):
    head, digest = seal()
    run = api('actions/runs/' + str(RUN))
    assert run['head_sha'] == BASE and run['status'] == 'completed' and run['conclusion'] == 'failure'
    artifacts = api('actions/runs/' + str(RUN) + '/artifacts')['artifacts']
    assert ARTIFACTS <= {a['id'] for a in artifacts if not a['expired']}
    jobs = api('actions/runs/' + str(RUN) + '/jobs')['jobs']
    assert any(j['id'] == 123891957933 and j['conclusion'] == 'success' for j in jobs)
    source = one(root, 'SOURCE_SHA.txt')
    assert source.read_text().strip() == BASE
    log = one(root, 'b11-linux-swift-test.log').read_text()
    assert re.search(r'Executed 417 tests, with 0 failures \(0 unexpected\)', log)
    assert not re.search(r'\b[1-9]\d* (?:tests? skipped|failures?)\b', log)
    assert '** BUILD SUCCEEDED **' in one(root, 'b11-ios-compile.log').read_text()
    evidence = source.parent
    results = {label: passing(evidence, label, count) for label, count in REUSED_UI.items()}
    passing(evidence, 'biometric-preflight', 1)
    native = passing(evidence, 'native-26', 26)
    # A known failed test must be recorded and rerun, never certified by reuse.
    failed = json.loads(one(evidence, 'N2BiometricInteractionTests.xcresult.summary.json').read_text())
    assert failed['totalTestCount'] == 1 and failed['failedTests'] == 1
    assert any('Esperar al sensor REAL' in f['failureText'] for f in failed['testFailures'])
    proof = {'sourceSHA': head, 'baselineSHA': BASE, 'baselineRun': RUN,
             'baselineArtifacts': sorted(ARTIFACTS), 'testedInputsSHA256': digest,
             'swiftTests': 417, 'native': native, 'reusedUI': results,
             'mustReplay': REPLAY_UI, 'priorBiometricFailure': failed['testFailures'],
             'priorRunPassed': False}
    Path(out).mkdir(parents=True, exist_ok=True)
    Path(out, 'BASELINE_PROOF.json').write_text(json.dumps(proof, indent=2))
    print('PASS: 417 Swift, Xcode, 26 native and 7 UI reused from immutable evidence; 4 UI still required.')


def final(root, out):
    head, digest = seal()
    proof = json.loads(one(root, 'BASELINE_PROOF.json').read_text())
    assert proof['sourceSHA'] == head and proof['baselineSHA'] == BASE
    assert proof['testedInputsSHA256'] == digest and proof['mustReplay'] == REPLAY_UI
    assert proof['swiftTests'] == 417 and proof['native']['count'] == 26
    assert {k: v['count'] for k, v in proof['reusedUI'].items()} == REUSED_UI
    covered = dict(REUSED_UI)
    for label, count in REPLAY_UI.items():
        folder = Path(root, 'B14_REPLAY_RESULT_' + label)
        assert one(folder, 'SOURCE_SHA.txt').read_text().strip() == head
        assert one(folder, 'REPLAY_LABEL.txt').read_text().strip() == label
        assert one(folder, 'REPLAY_PASS_SHA.txt').read_text().strip() == head
        passing(folder, 'biometric-preflight', 1)
        passing(folder, label, count)
        if label.endswith('-demo'):
            passing(folder, 'seed-' + label, 2)
        covered[label] = count
    assert sum(covered.values()) == 11 and len(covered) == 7
    Path(out).mkdir(parents=True, exist_ok=True)
    Path(out, 'ALL_GATES.json').write_text(json.dumps({
        'sourceSHA': head, 'baselineSHA': BASE, 'baselineRun': RUN,
        'swift': 417, 'native': 26, 'ui': covered, 'failures': 0, 'skips': 0,
        'priorBiometricFailureReplayed': True,
        'testedInputsSHA256': digest}, indent=2))
    Path(out, 'VALIDATED_SHA.txt').write_text(head + '\n')
    print('PASS: combined coverage 417 Swift, 26 native, all 11 UI; no failures/skips. IPA gate unlocked.')


if __name__ == '__main__':
    mode, root, out = sys.argv[1:]
    assert mode in ('baseline', 'final')
    (baseline if mode == 'baseline' else final)(root, out)
