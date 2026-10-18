#!/usr/bin/env node
// Static guard against accidentally routing a real clinical screen to the
// synthetic evaluation store, or conversely. This is not a substitute for
// iOS compilation, XCTests, authentication or data-recovery testing.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const app=path.join(root,'native-ios','App');
const views=[
'N2NativeHistoryView.swift',
'N2ClinicalCorrectionView.swift',
'N2NativeWorkerEditorView.swift',
'N2NativeClinicalFormView.swift',
'N2NativeInventoryView.swift',
'N2VerifiedIndicatorExportView.swift',
'N2NativeBackupExportView.swift',
'N2NativeDraftsDashboard.swift',
'N2ReconciliationView.swift',
'N2VerifiedNursingExportView.swift'
];
for(const item of views) {
 const source=fs.readFileSync(path.join(app,item),'utf8');
 assert(!source.includes('N2SyntheticTrialIOSVault.shared'),
        item+' must never bind directly to the DEMO vault');
 assert(!source.includes('N2ProtectedClinicalIOSVault.shared'),
        item+' must never bind directly to the CLINICAL vault');
 assert(source.includes('@Environment(\\.n2WorkspaceVault) private var vault'),
        item+' must declare the fixed source environment');
 assert(/\bawait\s+vault\s*\./.test(source),
        item+' must use a source-bound router');
}
const router=fs.readFileSync(path.join(app,'N2WorkspaceVault.swift'),'utf8');
const clinical=fs.readFileSync(path.join(app,'N2ProtectedClinicalIOSVault.swift'),'utf8');
const demo=fs.readFileSync(path.join(app,'N2SyntheticTrialIOSVault.swift'),'utf8');
const calls=[...router.matchAll(/N2SyntheticTrialIOSVault\.shared\.(\w+)\(/g)].map(m=>m[1]);
assert.equal(calls.length,29,'The bridge must expose the entire supported surface.');
for(const method of calls) {
 assert(clinical.includes('func '+method+'('),'Missing clinical method: '+method);
 assert(demo.includes('func '+method+'('),'Missing demo method: '+method);
 assert(router.includes('N2ProtectedClinicalIOSVault.shared.'+method+'('),
        'Missing clinical implementation in router: '+method);
}
const gate=fs.readFileSync(path.join(app,'N2ClinicalWorkspaceView.swift'),'utf8');
assert(gate.includes('.environment(\\.n2WorkspaceVault,.clinical)'));
assert(gate.includes('evaluatePolicy(.deviceOwnerAuthentication'));
assert(gate.includes('if phase != .active {onClose()}'));
const rootUI=fs.readFileSync(path.join(app,'NativeRootView.swift'),'utf8');
assert(rootUI.includes('N2ClinicalWorkspaceGateView()'));
assert(rootUI.includes('N2SyntheticTrialIOSVault.shared.startSyntheticDemo()'));
console.log('PASS: '+views.length+' views route via immutable workspace; '+calls.length+
 ' clinical/demo vault methods, separate authenticated clinical gate, no automatic migration.');
