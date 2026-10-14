// Stage A UI guardrail: visual-only redesign over the user-tested iOS v0.20.7.
// Runs in the existing CI logic suite, requires no DOM/browser and no clinical data.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const main=fs.readFileSync('src/main.tsx','utf8');
const css=fs.readFileSync('src/visualRefresh.css','utf8');
const base=fs.readFileSync('src/style.css','utf8');
const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));
const lock=JSON.parse(fs.readFileSync('package-lock.json','utf8'));
const iosBuild=fs.readFileSync('scripts/build-ios-ipa.sh','utf8');
const iosVerifier=fs.readFileSync('scripts/verify-ios-ipa.mjs','utf8');
assert.equal(pkg.version,'0.20.8','the visual prototype must have its own version');
assert.equal(lock.version,pkg.version,'npm lock version');
assert.equal(lock.packages[''].version,pkg.version,'npm root version');
assert(main.includes("import './style.css';import './visualRefresh.css';"),'new theme loads after old rules');
assert(main.includes("import appMetadata from '../package.json'"),'runtime version is sourced from package');
assert(main.includes('DANPER v{appMetadata.version}'),'settings cannot display an outdated static version');
assert(main.includes('className="appTabBar"'),'bottom navigation remains present');
assert(main.includes('role="navigation" aria-label="Acceso rápido a secciones de la atención"'),'accessible section shortcuts');
for(const id of ['attention-worker','attention-clinical','attention-treatment','attention-result']){
  assert(main.includes('id="'+id+'"'),'missing target '+id);
  assert(main.includes("jumpToSection('"+id+"')"),'missing shortcut '+id);
}
assert(main.includes('function jumpToResult(){jumpToSection('),'existing result shortcut preserved');
assert(main.includes('<details className="warning demoNotice">'),'testing caveat remains available');
assert(main.includes('PROTOTIPO DE PRUEBA: utilizar solo datos ficticios'),'safety wording preserved');
for(const label of ['Inicio','Registrar','Historial','Ajustes']){
  assert(main.includes('>'+label+'</button>'),'bottom tab removed '+label);
}
for(const selector of ['.brand','.appTabBar','.registerSteps','.demoNotice','.panel','.kardexSectionGrid']){
  assert(css.includes(selector),'missing redesigned element '+selector);
}
assert(css.includes('safe-area-inset-top'),'iPhone status bar safe area preserved');
assert(css.includes('safe-area-inset-bottom'),'iPhone home indicator safe area preserved');
assert(css.includes('prefers-reduced-motion:reduce'),'iOS Reduce Motion preference preserved');
assert(base.includes('.registerDock'),'original save dock not removed');
assert(main.includes('function save()'),'clinical save function remains');
assert(main.includes('function patch('),'draft update function remains');
assert(iosBuild.includes('CFBundleVersion 208'),'new iPhone build must be 208');
assert(iosVerifier.includes("packed.CFBundleVersion,'208'"),'IPA verifier must require build 208');
console.log('PASS: Stage A visual shell, accessible anchors, reduced motion, iOS safe areas, build 208 and preserved clinical action hooks.');
