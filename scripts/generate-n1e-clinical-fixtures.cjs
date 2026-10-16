'use strict';
/** N1e source-of-truth fixture: real TypeScript FEFO and Kardex code,
 * workers and visits invented here ONLY; no iPhone files are loaded. */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {load,visit} = require('./ambulatory-test-helpers.cjs');
const products = require('../src/products.json');
const cat = load('src/kardexCatalog.ts').kardexCatalog;
const {finalizeVisitAndPlanStock} = load('src/automaticClinicalDispensing.ts');
const {validateStockLedger} = load('src/kardexMovements.ts');
const {buildAmbulatoryRows} = load('src/ambulatoryRows.ts');
const unit = products.find(p=>p.code==='16000182');
const pack = products.find(p=>p.code==='16000013');
const u = cat.find(x=>x.id==='E-22'), b = cat.find(x=>x.id==='E-57');
assert(unit&&pack&&u&&b);
const at=Date.parse('2026-10-14T16:00:00Z');
const earlier=Date.parse('2026-10-09T13:00:00Z');
const lot=(id,p,expires,opts={})=>({
 id,code:p.id,name:p.name,catalogUnit:opts.unit||'UND',
 lot:id,expires,container:opts.container||'unidad',
 unitsPerContainer:opts.capacity||1,sealedContainers:opts.sealed||0,
 looseUnits:opts.loose||0,openedRemaining:opts.opened||0,updatedAt:earlier
});
let ledger={lots:[
 lot('early-unit',u,'2026-10-18',{loose:2}),
 lot('later-unit',u,'2027-03-01',{loose:8}),
 lot('tablet-carton',u,'2028-01-01',{container:'caja',capacity:20,sealed:1,unit:'UND'}),
 lot('early-open-box',b,'2026-10-18',{container:'caja',capacity:100,opened:1,unit:'CJA'}),
 lot('later-sealed-box',b,'2027-03-01',{container:'caja',capacity:100,sealed:1,unit:'CJA'})
],movements:[]};
const line=(id,p,q,physicalUse)=>({id,code:p.code,name:p.name,
 unit:p.unit,quantity:q,procedure:'OBSERVACION',...(physicalUse?{physicalUse}:{})});
const make=(id,dni,items,site='LA VENTUROSA')=>({
 ...visit(id,items),date:'2026-10-14',status:'saved',
 worker:{...visit().worker,dni,site}
});
const attentions=[
 make('fundo-unit','00000001',[line('unit-5',unit,5)]),
 make('planta-open','00000002',[line('box-2',pack,2,{lotId:'early-open-box',quantity:2})],'PLVENTUROSA'),
 make('fundo-reuse','00000003',[line('box-1',pack,1,{lotId:'later-sealed-box',quantity:1})]),
 make('planta-tablet-carton','00000004',[line('unit-carton',unit,12)],'PLVENTUROSA')
];
attentions.forEach((v,i)=>v.time=['08:25','09:15','10:10','11:45'][i]);
for(let i=0;i<attentions.length;i++){
 const o=finalizeVisitAndPlanStock(ledger,attentions[i],at+i*2000);
 assert.equal(o.deducted,1,JSON.stringify(o.results));
 ledger=o.ledger;
}
const report=buildAmbulatoryRows(attentions,ledger,'2026-10-09','2026-11-08',{perVisitSubdivision:true});
assert.equal(report.blockers.length,0);
assert.deepEqual(report.lines.map(x=>x.cells[17]),[5,1,0,12]);
validateStockLedger(ledger);
const pending = make('pending-stock','00000005',[line('pending-item',unit,1000)]);
const outcome=finalizeVisitAndPlanStock(ledger,pending,at+20000);
assert.equal(outcome.pending,1);
assert.equal(outcome.ledger.movements.length,ledger.movements.length);
const allVisits=[...attentions,pending];
const snapshot={
 attentions:allVisits,
 workers:allVisits.map(a=>({...a.worker})),
 allergies:{},notifications:false,
 stockLots:ledger.lots,stockMovements:ledger.movements,
 catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]
};
const dir=process.env.DANPER_N1_FIXTURE_DIR;
if(!dir||!path.isAbsolute(dir))throw Error('Absolute DANPER_N1_FIXTURE_DIR required');
fs.mkdirSync(dir,{recursive:true});
const save=(name,thing)=>fs.writeFileSync(path.join(dir,name),JSON.stringify(thing));
save('n1e-clinical-stock.json',snapshot);
const expected={sha256:crypto.createHash('sha256').update(
 fs.readFileSync(path.join(dir,'n1e-clinical-stock.json'))).digest('hex'),
 rows:[5,1,0,12,null],attentions:5,workers:5,movements:ledger.movements.length,
 linked:4,pending:1,splitDeliveries:3};
save('n1e-clinical-expected.json',expected);
const modify=(name,fn)=>{const cloned=structuredClone(snapshot);fn(cloned);save(name,cloned)};
modify('n1e-truncated.json',v=>{v.stockMovements=v.stockMovements.filter(m=>m.dispenseRef?.itemId!=='unit-5'||m.dispenseRef.partIndex!==2)});
modify('n1e-double-worker.json',v=>{v.workers[1].dni=v.workers[0].dni});
modify('n1e-wrong-R.json',v=>{v.stockMovements.find(m=>m.dispenseRef?.itemId==='box-1').excelQuantity=1});
modify('n1e-missing-stock.json',v=>{v.stockLots.find(x=>x.id==='tablet-carton').openedRemaining=2});
modify('n1e-clinical-tamper.json',v=>{v.attentions[0].items[0].quantity=7});
modify('n1e-dup-movement.json',v=>{v.stockMovements.push(structuredClone(v.stockMovements[0]))});
modify('n1e-bad-link.json',v=>{v.stockMovements[0].dispenseRef.attentionId='nonexistent'});
console.log('PASS N1e: real TypeScript FEFO/Kardex, 5 fictional attentions (4 linked, 1 pending), 1/0 R and tamper fixtures. Movements:',ledger.movements.length);
