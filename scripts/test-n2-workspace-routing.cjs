#!/usr/bin/env node
'use strict';
// Exercise the real audit with in-memory Swift mutations; no vault is opened.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const audit=fs.readFileSync(path.join(__dirname,'audit-n2-workspace-routing.cjs'),'utf8');
function run(change) {
 const fakeFS={...fs,readFileSync(file,...args) {
  const source=fs.readFileSync(file,...args);
  return change(path.basename(file),source);
 }};
 vm.runInNewContext(audit,{__dirname,require:name=>name==='node:fs'?fakeFS:require(name),console:{log(){}}});
}
run((_,s)=>s);
run((file,s)=>file==='N2WorkspaceVault.swift'
 ?s.replace(/(N2(?:SyntheticTrial|ProtectedClinical)IOSVault)\.shared\s*\.\s*(\w+)\(/g,'$1 \n . shared \n . $2 \n ('):s);
for(const method of ['correctUnusedLot','automaticCutAccounting','exportOccupationalVigilance']) {
 assert.throws(()=>run((file,s)=>file==='N2WorkspaceVault.swift'
  ?s.replace(new RegExp('(N2ProtectedClinicalIOSVault\\.shared\\s*\\.\\s*)'+method+'\\('),'$1inspect('):s),
  /duplicate|route/i,'Must reject missing/swapped '+method);
}
assert.throws(()=>run((file,s)=>file==='N2SyntheticTrialIOSVault.swift'
 ?s.replace(/func\s+correctUnusedLot\s*\(/,'func missingUnusedLot('):s),/DEMO must implement/);
assert.throws(()=>run((file,s)=>file==='N2ProtectedClinicalIOSVault.swift'
 ?s+'\nfunc correctUnusedLot() {}':s),/CLINICAL must implement exactly one/);
assert.throws(()=>run((file,s)=>file==='N2WorkspaceVault.swift'
 ?s+'\nfunc unroutedOperation() {}':s),/Every bridge operation/);
// Equal global sets alone cannot catch calls exchanged between operations.
assert.throws(()=>run((file,s)=>file==='N2WorkspaceVault.swift'
 ?s.replace(/(N2SyntheticTrialIOSVault\.shared\s*\.\s*)(readDrafts|readHistory)\(/g,
  (_,prefix,method)=>prefix+(method==='readDrafts'?'readHistory':'readDrafts')+'('):s),/Incorrect DEMO route/);

for(const [file,marker] of [
 ['DANPERNativeApp.swift','.allowsHitTesting(authenticated && scenePhase == .active)'],
 ['DANPERNativeApp.swift','else if onboardingFinished || hasClinicalSource {'],
 ['N2ClinicalWorkspaceView.swift','invalidSource=summary == nil && evidence'],
 ['N2ClinicalWorkspaceView.swift','guard accepted,cycle==gateCycle,scenePhase == .active']]) {
 assert.throws(()=>run((name,source)=>name===file?source.replace(marker,'REMOVED_PROTECTION'):source),
  undefined,'Must reject removed protection: '+marker);
}
console.log('PASS: routing audit accepts multiline member access and rejects missing, duplicate, unrouted and cross-wired operations.');
