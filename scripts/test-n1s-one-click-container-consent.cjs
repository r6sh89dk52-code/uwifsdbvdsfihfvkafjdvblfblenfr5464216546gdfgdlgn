'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
const {load,visit}=require('./ambulatory-test-helpers.cjs');
const products=require('../src/products.json');
const catalog=load('src/kardexCatalog.ts').kardexCatalog;
const {finalizeVisitAndPlanStock:finish}=load('src/automaticClinicalDispensing.ts');
const {buildAmbulatoryRows}=load('src/ambulatoryRows.ts');
const p=products.find(x=>x.code==='16000013');
const physical=catalog.find(x=>x.id==='E-57');
assert(p&&physical);
const at=Date.parse('2026-10-15T14:00:00Z');
const initial={lots:[{
 id:'sealed-100',code:physical.id,name:physical.name,catalogUnit:'CJA',
 lot:'SYNTHETIC100',expires:'2027-12-31',container:'caja',
 unitsPerContainer:100,sealedContainers:2,looseUnits:0,
 openedRemaining:0,updatedAt:at-86400000
}],movements:[]};
const line=(id,confirm=false)=>({
 id,code:p.code,name:p.name,unit:p.unit,quantity:1,procedure:'CURACION DE HERIDA',
 physicalUse:{lotId:'sealed-100',quantity:1,confirmNewContainer:confirm}
});
const attention=(number,confirmed)=>({
 ...visit('N1S-'+number,[line('ITEM-'+number,confirmed)]),
 date:'2026-10-15',status:'saved',
 worker:{...visit().worker,site:'LA VENTUROSA',dni:'00000001'},
 time:'10:00'
});
const config={requireOpeningApproval:true};
const first=attention(1,false);
const denied=finish(initial,first,at,config);
assert.equal(denied.pending,1);
assert.equal(denied.deducted,0);
assert.equal(denied.ledger.movements.length,0);
assert.equal(denied.ledger.lots[0].sealedContainers,2);
assert.match(denied.results[0].reason,/autorizar/);
let ledger=initial;
const visits=[];
let openingCount=0;
for(let i=1;i<=100;i++){
 const visitRecord=attention(i,i===1);
 const outcome=finish(ledger,visitRecord,at+i*1000,config);
 assert.equal(outcome.pending,0,'physical 1 mL confirmed, reuse must not need new opening '+i);
 assert.equal(outcome.deducted,1);
 const movement=outcome.ledger.movements.at(-1);
 assert.equal(movement.quantity,1);
 assert.equal(movement.excelQuantity,i===1?1:0,
  'new package R=1 only once, later 99 clinical uses R=0');
 if(movement.excelQuantity)openingCount++;
 ledger=outcome.ledger;
 visits.push(visitRecord);
}
assert.equal(ledger.lots[0].sealedContainers,1);
assert.equal(ledger.lots[0].openedRemaining,0);
assert.equal(openingCount,1);
const needs=finish(ledger,attention(101,false),at+101000,config);
assert.equal(needs.pending,1,'next box must prompt again');
assert.equal(needs.ledger.movements.length,100);
assert.equal(needs.ledger.lots[0].sealedContainers,1);
const reopened=finish(ledger,attention(101,true),at+101000,config);
assert.equal(reopened.deducted,1);
assert.equal(reopened.ledger.movements.at(-1).excelQuantity,1);
assert.equal(reopened.ledger.lots[0].sealedContainers,0);
assert.equal(reopened.ledger.lots[0].openedRemaining,99);
const report=buildAmbulatoryRows([visits[0],visits[1],visits[99],attention(101,true)],
 reopened.ledger,'2026-10-09','2026-11-08',{perVisitSubdivision:true});
assert.equal(report.blockers.length,0);
assert.deepEqual(report.lines.map(l=>l.cells[17]),[1,0,1,0], 'Excel orders by same-day time and visit ID, not input list; source matches [1,0,1,0]');
const old=finish(reopened.ledger,attention(101,true),at+102000,config);
assert.equal(old.deducted,0,'cannot duplicate clinical link');
assert.equal(old.results[0].outcome,'already-linked');
// Quantity governs uses: 100 mL at 2 mL/use allows 50 uses,
// and still requires opening approval; no per-patient inference permitted.
const without=finish(initial,{
 ...attention('2ml-no',false),
 items:[{...line('2ml',false),physicalUse:{lotId:'sealed-100',quantity:2,
 confirmNewContainer:false}}]},at,config);
assert.equal(without.pending,1);
assert.equal(without.ledger.movements.length,0);
const main=fs.readFileSync('src/main.tsx','utf8');
const ui=fs.readFileSync('src/ClinicalStockChoice.tsx','utf8');
assert.match(main,/requireOpeningApproval:true/);
assert.match(ui,/confirmNewContainer/);
assert.match(ui,/Recordar esta cantidad interna para futuras atenciones/);
assert.match(ui,/Autorizo abrir un nuevo frasco o caja/);
assert.match(ui,/un frasco de 100 mL permite 100 usos/i);
console.log('PASS N1s clinical: saved once, 100 verified 1 mL uses => R=[1,0...0], 101st opening blocked until explicit approval, FEFO stock immutable on refusal and idempotent retry.');
