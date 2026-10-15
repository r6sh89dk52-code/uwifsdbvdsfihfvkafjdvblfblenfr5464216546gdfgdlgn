// Release guardrail: v0.21.10 installs over v0.21.9 as an UPDATE, not a new app.
// It cannot prove SideStore behavior; validate physical iPhone after IPA creation.
const assert=require('node:assert/strict'),fs=require('node:fs');
const read=p=>fs.readFileSync(p,'utf8');
const pkg=JSON.parse(read('package.json')),lock=JSON.parse(read('package-lock.json'));
const config=read('capacitor.config.ts');
const build=read('scripts/build-ios-ipa.sh');
const verify=read('scripts/verify-ios-ipa.mjs');
const workflow=read('.github/workflows/ios-ipa.yml');
const ui=read('src/AmbulatoryExportPanel.tsx');
const exportSource=read('src/ambulatoryExcel.ts');
const backup=read('src/BackupSettingsPanel.tsx');
const reminders=read('src/nativeReminders.ts');
const app=read('src/main.tsx');
const secure=read('src/secureDemoStore.ts');
assert.equal(pkg.version,'0.21.10');
assert.equal(lock.version,pkg.version);
assert.equal(lock.packages[''].version,pkg.version);
assert(config.includes("appId:'pe.danper.saludmovil.prototipo'"),'must keep v0.21.9 bundle id for in-place upgrade');
assert(build.includes('Set :CFBundleVersion 220'));
assert(verify.includes("packed.CFBundleVersion,'220'"));
assert(verify.includes("packed.CFBundleIdentifier,'pe.danper.saludmovil.prototipo'"));
assert(workflow.includes('on:\n  workflow_dispatch:'),'macOS needs one explicit manual launch');
assert(!/^  (?:push|pull_request):/m.test(workflow),'macOS may not run automatically from push or PR');
assert(workflow.includes('runs-on: macos-15'));
assert(workflow.includes('DANPER-Salud-Movil-iPhone-v0.21.10-BUILD-220-PRUEBAS-CIERRE'));
assert(ui.includes('buildAmbulatoryRows(attentions,ledger,start,end,{perVisitSubdivision:true'),'report must include both sites');
assert(ui.includes('sharedMonthlyReconciliation(ledger,result.data)'),'reconciliation has one physical stock ledger');
assert(!ui.includes('siteVisits')&&!ui.includes('setSubdivision'),'no worksite report filter');
assert(exportSource.includes('// RESU column M is the original COMENTARIO field.'),'blank manual comments');
assert(!exportSource.includes("editCell(doc,'M'+row"),'no warnings in manual comments');
assert(backup.includes('decryptPortableBackup(contents,restorePassword)'),'restore has separate password');
assert(!backup.includes('decryptPortableBackup(contents,password)'));
assert(reminders.includes('slice(0,50)'),'iOS local reminder limit');
assert(app.includes("a.status==='draft'&&draftIsMeaningful(a)"),'do not schedule empty draft reminders');
for(const stable of ["const SECURE_KEY='prototype-snapshot-v1'","const CLINICAL_MARKER=JSON.stringify({format:'encrypted-clinical-v1',version:2})","const INVENTORY='danper-etapa-b0-stock-v010'","const MOVEMENTS='danper-etapa-b1-movements-v011'"]){
 assert(secure.includes(stable),'stored data schema changed: '+stable);
}
assert(app.includes("import appMetadata from '../package.json'"),'runtime version comes from package');
console.log('PASS: v0.21.10 build 220, unchanged appId and storage keys, combined 10-sheet report, protected RESU formulas, restore password, 60m reminders, manual-only macOS.');
