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
'N2SimpleInventoryView.swift',
'N2SimpleProductEditor.swift',
'N2SimpleMigrationViews.swift',
'N2SimpleCutView.swift',
'N2ClinicalCorrectionView.swift',
'N2NativeWorkerEditorView.swift',
'N2NativeClinicalFormView.swift',
'N2NativeInventoryView.swift',
'N2VerifiedIndicatorExportView.swift',
'N2NativeBackupExportView.swift',
'N2NativeDraftsDashboard.swift',
'N2ReconciliationView.swift',
'N2VerifiedNursingExportView.swift',
'N2OccupationalVigilanceExportView.swift',
'N2OperationalMappingView.swift',
'N2PendingDispensingView.swift',
'N2AuxiliaryInventoryView.swift',
'N2ContainerStateView.swift'
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
// Whitespace includes line breaks on either side of both member-access dots.
const routedCalls=(source,vault)=>[...source.matchAll(new RegExp(
 '\\b'+vault+'\\s*\\.\\s*shared\\s*\\.\\s*(\\w+)\\s*\\(', 'g'))].map(m=>m[1]);
const declarations=source=>[...source.matchAll(/\bfunc\s+(\w+)\s*\(/g)].map(m=>m[1]);
const unique=(items,label)=>assert.equal(new Set(items).size,items.length,label+' contains duplicate methods');
const sorted=items=>[...items].sort();
const demoType='N2SyntheticTrialIOSVault',clinicalType='N2ProtectedClinicalIOSVault';
const calls=routedCalls(router,demoType),clinicalCalls=routedCalls(router,clinicalType);
const methods=declarations(router);
unique(methods,'Workspace bridge');unique(calls,'DEMO routes');unique(clinicalCalls,'CLINICAL routes');
assert.deepEqual(sorted(calls),sorted(methods),'Every bridge operation needs a DEMO route');
assert.deepEqual(sorted(clinicalCalls),sorted(methods),'Every bridge operation needs a CLINICAL route');
const required=[
 'correctUnusedLot','automaticCutAccounting','exportOccupationalVigilance',
 'closeContainers','confirmPendingDispensing','registerAuxiliaryLot',
 'auxiliaryAccounting','confirmOperationalMapping','retryDispensing'
];
for(const method of required)assert(calls.includes(method),'Missing required capability: '+method);
for(const [label,source] of [['CLINICAL',clinical],['DEMO',demo]]) {
 const implemented=declarations(source);
 for(const method of methods)assert.equal(implemented.filter(name=>name===method).length,1,
  label+' must implement exactly one '+method);
}
// Compare within each operation as well: swapped or cross-wired calls must fail.
const blocks=[...router.matchAll(/\bfunc\s+(\w+)\s*\([\s\S]*?(?=\bfunc\s+\w+\s*\(|$)/g)];
for(const [block,method] of blocks) {
 assert.deepEqual(routedCalls(block,demoType),[method],'Incorrect DEMO route in '+method);
 assert.deepEqual(routedCalls(block,clinicalType),[method],'Incorrect CLINICAL route in '+method);
}
const gate=fs.readFileSync(path.join(app,'N2ClinicalWorkspaceView.swift'),'utf8');
assert(gate.includes('.environment(\\.n2WorkspaceVault,.clinical)'));
assert(gate.includes('evaluatePolicy(.deviceOwnerAuthentication'));
assert(gate.includes('var authenticatedLaunch=false'));
assert(gate.includes('if !checked {'));
assert(gate.includes('else if invalidSource {'));
assert(gate.includes('else if summary != nil {'));
assert(gate.includes('authenticatedLaunch || authorized || inheritedAuthentication'));
assert(gate.includes('guard accepted,cycle==gateCycle,scenePhase == .active'));
assert(gate.includes('invalidSource=summary == nil && evidence'));
assert(gate.includes('hasStoredClinicalSource()'));
assert(!gate.includes('.fullScreenCover('));
const launch=fs.readFileSync(path.join(app,'DANPERNativeApp.swift'),'utf8');
assert(launch.includes('if authenticated || sessionStarted {'));
assert(launch.includes('else if onboardingFinished || hasClinicalSource {'));
assert(launch.includes('hasClinicalSource=exists'));
assert(launch.includes('.onChange(of:sourceResolved)'));
assert(launch.includes('automaticUnlockScheduled=true'));
assert(launch.indexOf('access.reserveAutomatic()')>launch.indexOf('Task.sleep(for:.milliseconds(350))'));
assert(launch.includes('guard scenePhase == .active,!manualRetryAvailable,access.reserveAutomatic()'));
assert(launch.includes('guard (onboardingFinished || hasClinicalSource),scenePhase'));
assert(launch.includes('.opacity(authenticated && scenePhase == .active ? 1 : 0)'));
assert(launch.includes('.accessibilityHidden(!authenticated || scenePhase != .active)'));
assert(launch.includes('.allowsHitTesting(authenticated && scenePhase == .active)'));
assert(launch.includes('N2ClinicalWorkspaceGateView(authenticatedLaunch:true,sessionUnlocked:authenticated'));
assert(launch.includes('cycle==authCycle'));
assert(gate.includes('guard !layoutOnly,sessionAuthenticated'));
assert(gate.includes('.accessibilityHidden(scenePhase != .active)'));
const rootUI=fs.readFileSync(path.join(app,'NativeRootView.swift'),'utf8');
assert(rootUI.includes('N2ClinicalWorkspaceGateView()'));
assert(rootUI.includes('N2SyntheticTrialIOSVault.shared.startSyntheticDemo()'));
const resetView=fs.readFileSync(path.join(app,'N2DemoResetView.swift'),'utf8');
const resetActor=fs.readFileSync(path.join(app,'N2SyntheticTrialIOSVault.swift'),'utf8');
const scope=fs.readFileSync(path.join(root,'native-ios','Sources','DanperCore',
                                    'N2SyntheticResetScope.swift'),'utf8');
assert(rootUI.includes('N2DemoResetView(onDeleted:'));
assert(resetView.includes('N2SyntheticTrialIOSVault.shared.eraseEntireDemo('));
assert(resetView.includes('N2SyntheticResetScope.confirmation'));
assert(resetView.includes('evaluatePolicy('));
assert(!resetView.includes('N2ProtectedClinicalIOSVault.shared'));
assert(scope.includes('"DANPER-N2-SYNTHETIC-VAULT"'));
assert(scope.includes('"DANPER-N2-CLINICAL-VAULT"'));
assert(resetActor.includes('SecItemDelete(query() as CFDictionary)'));
assert(resetActor.includes('N2SyntheticResetScope.canErase('));
assert(!resetActor.includes('removeAllPendingNotificationRequests('));
const reminder=fs.readFileSync(path.join(app,'N2DraftReminder.swift'),'utf8');
assert(reminder.includes('mode.rawValue'));
assert(reminder.includes('if mode == .demo'));
console.log('PASS: '+views.length+' views route via immutable workspace; '+calls.length+
 ' clinical/demo vault methods, separate authenticated clinical gate, safe DEMO reset path and reminders.');
