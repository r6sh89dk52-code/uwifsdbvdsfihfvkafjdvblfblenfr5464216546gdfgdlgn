'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=file=>fs.readFileSync(path.join(root,file),'utf8');
const ui=read('native-ios/App/DanperPremiumUI.swift');
const app=read('native-ios/App/DANPERNativeApp.swift');
const core=read('native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift');
for(const file of ['NativeRootView.swift','N2ClinicalWorkspaceView.swift']) {
 const source=read('native-ios/App/'+file);
 const labels=[...source.matchAll(/\.tabItem\s*\{\s*Label\("([^"]+)"/g)].map(m=>m[1]);
 assert.deepEqual(labels,['Inicio','Historial','Borradores','Ajustes'],file+' navigation order');
 assert(source.includes('danperFloatingNavigation(selection:$tab)'));
 assert(source.includes('.toolbar(.hidden,for:.tabBar)'));
 assert(source.includes('DanperAttentionEditor(initialWorkerDNI:'));
 assert(source.includes('DanperStatisticsView()'));
 const counter=file==='N2ClinicalWorkspaceView.swift' ? 'dashboardSnapshot(' : 'dashboardCounters(';
 assert(source.includes(counter),'Home must use direct authenticated counters');
 assert(!source.includes('.shared.readHistory()'),'Home must not rebuild the worker index');
}
for(const marker of ['CFBundleShortVersionString','CFBundleVersion','premium-app-version',
 'Capsule().fill(.ultraThinMaterial)','keyboardWillShowNotification','keyboardWillHideNotification',
 'accessibilityReduceMotion','accessibilityReduceTransparency','premium-tab-',
 'accessibilityAddTraits','Este mes'])assert(ui.includes(marker),marker);
assert(app.includes('attemptAutomaticUnlock()'));
assert(app.includes('evaluatePolicy(.deviceOwnerAuthentication'));
assert(app.includes('Usar código del dispositivo'));
assert(app.includes('cycle==authCycle'));
assert(app.includes('.accessibilityHidden(!authenticated || scenePhase != .active)'));
assert(core.includes('date>=monthStart && date<=today'));
assert(core.includes('date>=weekStart && date<=today'));
const stats=ui.slice(ui.indexOf('struct DanperStatisticsView'),ui.indexOf('struct DanperExportsView'));
assert(stats.includes('Resumen aún no disponible'));
assert(!/1,248|1248|\+12%|352|278/.test(stats),'No mock clinical totals or trends');
assert(!/N2ProtectedClinicalIOSVault|N2SyntheticTrialIOSVault/.test(stats),'Statistics is presentation only');

const presentation=read('native-ios/App/DanperPremiumPresentation.swift');
const form=read('native-ios/App/N2NativeClinicalFormView.swift');
const drafts=read('native-ios/App/N2NativeDraftsDashboard.swift');
for(const marker of ['VStack(spacing:0)', 'content.frame(maxWidth:.infinity,maxHeight:.infinity)',
 'if !keyboard.visible', 'DanperFloatingTabs(selection:$selection)',
 'struct DanperAttentionEditor', 'NavigationStack {',
 'N2NativeClinicalFormView(requestedDraftID:requestedDraftID,initialWorkerDNI:initialWorkerDNI)',
 'premium-close-attention', 'shape.fill(.ultraThinMaterial)', 'accessibilityReduceTransparency',
 'accessibilityReduceMotion'])assert(presentation.includes(marker),marker);
assert(form.includes('if !saved && !keyboard.visible'));
assert(drafts.includes('DanperAttentionEditor(requestedDraftID:route.draftID)'));
assert(!drafts.includes('NavigationLink {N2NativeClinicalFormView'));

assert(presentation.includes('if phase == .background {dismiss()}'),'Every new or resumed editor closes behind the app lock');
console.log('PASS: premium four-tab navigation, safe floating capsule, optimized real counters, bundle version, secure automatic authentication and honest statistics placeholders.');
