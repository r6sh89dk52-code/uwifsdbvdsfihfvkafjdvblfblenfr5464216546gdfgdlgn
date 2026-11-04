#!/usr/bin/env python3
"""A successful shell exit is not evidence that XCTest actually executed."""
import json,re,subprocess,sys
from pathlib import Path

SEEDED={'N2GlassClinicalTests','N2PremiumRedesignTests',
        'N3ClinicalJourneyTests-demo','N2AllergySaveInteractionTests'}

def counts():
    suites={}
    folder=Path(__file__).resolve().parents[2]/'native-ios/InteractionTests'
    for source in folder.glob('*.swift'):
        text=source.read_text();kind=re.search(r'final class (\w+):XCTestCase',text)
        if not kind:continue
        methods=re.findall(r'func (test\w+)\(',text)
        if kind[1]=='N3ClinicalJourneyTests':
            protected='testProtectedClinicalSourceCreationAndRelaunch'
            assert protected in methods
            suites[kind[1]+'-protected']=1
            suites[kind[1]+'-demo']=len(methods)-1
        else:suites[kind[1]]=len(methods)
    assert sum(suites.values())==14
    return suites

def passing(path,expected):
    data=json.loads(path.read_text())
    assert data['totalTestCount']==data['passedTests']==expected,(path,data)
    assert data['failedTests']==data['skippedTests']==data.get('expectedFailures',0)==0,(path,data)
    assert not data.get('testFailures'),(path,data)

def verify_inventory(path):
    expected=counts()
    rows=[line.split('\t') for line in path.read_text().splitlines()]
    assert len(rows)==len(expected) and all(len(row)==4 for row in rows),(path,rows)
    labels=[row[0] for row in rows]
    assert len(set(labels))==len(labels) and set(labels)==set(expected),(path,labels)
    for label,number,kind,selectors in rows:
        assert int(number)==expected[label],(label,number,expected[label])
        actual_kind=label.rsplit('-',1)[0] if label.startswith('N3ClinicalJourneyTests-') else label
        assert kind==actual_kind,(label,kind,actual_kind)
        prefix='-only-testing:DANPERInteractionTests/'+kind
        if label.startswith('N3ClinicalJourneyTests-'):
            source=Path(__file__).resolve().parents[2]/'native-ios/InteractionTests'/('N3ClinicalJourneyTests.swift')
            methods=re.findall(r'func (test\w+)\(',source.read_text())
            protected='testProtectedClinicalSourceCreationAndRelaunch'
            selected=[protected] if label.endswith('-protected') else [m for m in methods if m!=protected]
            required=[prefix+'/'+m for m in selected]
        else:required=[prefix]
        assert selectors.split()==required,(label,selectors,required)
    return sum(expected.values())

def verify(folder,label,head):
    verified=folder/'SHARD_VERIFIED_SHA.txt'
    verified.unlink(missing_ok=True)
    expected=counts()[label]
    for name in ('SOURCE_SHA.txt','SHARD_PASS_SHA.txt'):
        assert (folder/name).read_text().strip()==head,(folder,name)
    assert (folder/'SHARD_LABEL.txt').read_text().strip()==label
    passing(folder/'biometric-preflight.xcresult.summary.json',1)
    if label in ('N2BiometricInteractionTests','N3ClinicalJourneyTests-protected'):
        passing(folder/'permission-preflight.xcresult.summary.json',1)
        passing(folder/'system-auth-preflight.xcresult.summary.json',1)
    passing(folder/(label+'.xcresult.summary.json'),expected)
    if label in SEEDED:
        passing(folder/('seed-'+label+'.xcresult.summary.json'),2)
    verified.write_text(head+'\n')
    return expected

if __name__=='__main__':
    if len(sys.argv)==3 and sys.argv[1]=='--inventory':
        number=verify_inventory(Path(sys.argv[2]))
        print('PASS: source-discovered UI inventory and selectors:',number,'required cases; not execution evidence')
        raise SystemExit(0)
    head=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    number=verify(Path(sys.argv[1]),sys.argv[2],head)
    print('PASS:',sys.argv[2],number,'actual XCTest cases; no failures/skips, current HEAD')
