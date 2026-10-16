const assert=require('node:assert/strict'),fs=require('node:fs');
const {load,visit}=require('./ambulatory-test-helpers.cjs');
const products=require('../src/products.json');
const catalog=load('src/kardexCatalog.ts').kardexCatalog;
const {finalizeVisitAndPlanStock}=load('src/automaticClinicalDispensing.ts');
const {validateStockLedger}=load('src/kardexMovements.ts');
const {buildAmbulatoryRows}=load('src/ambulatoryRows.ts');
const p=products.find(x=>x.code==='16000182'),n=catalog.find(x=>x.id==='E-22');
assert(p&&n);
const at=Date.parse('2026-10-15T14:00:00Z');
const mk=(id,qty,expiry)=>({id,code:n.id,name:n.name,catalogUnit:'UND',lot:id,expires:expiry,container:'unidad',unitsPerContainer:1,sealedContainers:0,looseUnits:qty,openedRemaining:0,updatedAt:at-86400000});
const v=(id,qty,date='2026-10-15')=>({...visit(id,[{id:id+'-item',code:p.code,name:p.name,unit:p.unit,quantity:qty,procedure:'TRATAMIENTO ORAL'}]),date,status:'saved',worker:{...visit().worker,site:'LA VENTUROSA'}});
const old=v('atencion-antigua',1,'2026-10-14');
const first=v('atencion-auditada',5);
const initial={lots:[mk('primero',2,'2026-10-20'),mk('segundo',10,'2027-04-20')],movements:[]};
const linked=finalizeVisitAndPlanStock(initial,first,at);
assert.equal(linked.deducted,1);
assert.equal(linked.ledger.movements.length,2);
const snapshot={attentions:[old,first],workers:[{dni:'00000001',name:'PERSONA FICTICIA'}],
 allergies:{},notifications:true,stockLots:linked.ledger.lots,stockMovements:linked.ledger.movements,
 catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]};
const before=JSON.stringify(snapshot);
const loadAgain=JSON.parse(before);
assert.deepEqual(loadAgain,snapshot,'legacy-format snapshot retained without migration');
validateStockLedger({lots:loadAgain.stockLots,movements:loadAgain.stockMovements});
const oldReport=buildAmbulatoryRows(loadAgain.attentions,
 {lots:loadAgain.stockLots,movements:loadAgain.stockMovements},
 '2026-10-09','2026-11-08',{perVisitSubdivision:true,allowPendingDeliveries:true});
assert.deepEqual(oldReport.lines.map(x=>x.cells[17]),[1,5],'past recorded clinical use remains visible even though not physically debited');
assert.equal(oldReport.unverifiedLineIds.length,1);
const next=v('atencion-nueva',2);
const posted=finalizeVisitAndPlanStock({lots:loadAgain.stockLots,movements:loadAgain.stockMovements},next,at+60000);
assert.equal(posted.deducted,1);
const upgraded={...loadAgain,attentions:[...loadAgain.attentions,next],
 stockLots:posted.ledger.lots,stockMovements:posted.ledger.movements};
assert.deepEqual(upgraded.attentions.slice(0,2),snapshot.attentions);
assert.deepEqual(upgraded.stockMovements.slice(0,2),snapshot.stockMovements);
assert.deepEqual(upgraded.workers,snapshot.workers);
assert.deepEqual(upgraded.allergies,snapshot.allergies);
assert.equal(upgraded.stockMovements.length,3);
assert.equal(finalizeVisitAndPlanStock(posted.ledger,next,at+65000).deducted,0);
assert.equal(JSON.stringify(snapshot),before,'old state is not mutated');
const pkg=require('../package.json'),lock=require('../package-lock.json');
assert.equal(pkg.version,'0.21.12');
assert.equal(lock.version,pkg.version);
assert.equal(lock.packages[''].version,pkg.version);
const app=fs.readFileSync('capacitor.config.ts','utf8');
assert(app.includes("appId:'pe.danper.saludmovil.prototipo'"));
const store=fs.readFileSync('src/secureDemoStore.ts','utf8');
for(const text of ["const SECURE_KEY='prototype-snapshot-v1'","const CLINICAL_MARKER=JSON.stringify({format:'encrypted-clinical-v1',version:2})",
 "const INVENTORY='danper-etapa-b0-stock-v010'","const MOVEMENTS='danper-etapa-b1-movements-v011'"])
 assert(store.includes(text),'storage migration would be unsafe: '+text);
assert(store.includes('await writeClinicalVault({...safe,workers:[]})'),'native encrypted vault persistence preserved');
const ipa=fs.readFileSync('.github/workflows/ios-ipa.yml','utf8');
assert(ipa.includes('workflow_dispatch:'));
assert(!/^\s+(push|pull_request):/m.test(ipa),'no automatic macOS builds');
console.log('PASS: candidate 221 preserves old attention, stock lot, movements, code identity; new FEFO posting is once-only and old clinical pending remains provisional.');
