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
 assert(source.includes('DanperFloatingTabs(selection:$tab)'));
 assert(source.includes('.safeAreaInset(edge:.bottom,spacing:0)'));
 assert(source.includes('.toolbar(.hidden,for:.tabBar)'));
 assert(source.includes('N2NativeClinicalFormView(initialWorkerDNI:'));
 assert(source.includes('DanperStatisticsView()'));
 assert(source.includes('dashboardCounters('));
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
console.log('PASS: premium four-tab navigation, safe floating capsule, optimized real counters, bundle version, secure automatic authentication and honest statistics placeholders.');
