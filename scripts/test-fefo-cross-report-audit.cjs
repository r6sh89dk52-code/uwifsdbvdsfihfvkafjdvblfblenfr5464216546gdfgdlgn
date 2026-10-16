/**
 * Cross-check the real packaged nurse Kardex against the real embedded
 * ten-sheet Indicator, using only SYNTHETIC inventory and workers.
 * No clinical data from the operator, iPhone, or production sources.
 */
const assert=require('node:assert/strict'),fs=require('node:fs');
const {load,visit,parse,all,value}=require('./ambulatory-test-helpers.cjs');
const {unzipSync,strFromU8}=require('fflate');
const products=require('../src/products.json');
const embeddedIndicator=require('../src/ambulatoryTemplate.json');
const cat=load('src/kardexCatalog.ts').kardexCatalog;
const stock=load('src/automaticClinicalDispensing.ts');
const ledgerRules=load('src/kardexMovements.ts');
const {buildDailyReport,buildKardexRangeReport}=load('src/dailyKardex.ts');
const {buildAmbulatoryRows}=load('src/ambulatoryRows.ts');
const {sharedMonthlyReconciliation}=load('src/sharedInventoryReports.ts');
const {exportAmbulatoryWorkbook}=load('src/ambulatoryExcel.ts');
const {exportOfficialKardex}=load('src/kardexExcelTemplate.ts');

const unit=products.find(x=>x.code==='16000182'),pack=products.find(x=>x.code==='16000013');
const unitK=cat.find(x=>x.id==='E-22'),packK=cat.find(x=>x.id==='E-57');
assert(unit&&pack&&unitK&&packK);
const t=Date.parse('2026-10-14T16:00:00Z'); // October 14 in Lima
const earlier=Date.parse('2026-10-09T13:00:00Z');
function lot(id,k,expiration,opts={}){
 return{id,code:k.id,name:k.name,catalogUnit:opts.unit||'UND',
  lot:id,expires:expiration,container:opts.container||'unidad',
  unitsPerContainer:opts.capacity||1,sealedContainers:opts.sealed||0,
  looseUnits:opts.loose||0,openedRemaining:opts.opened||0,updatedAt:earlier};
}
const original={lots:[
 lot('early-unit',unitK,'2026-10-18',{loose:2}),
 lot('later-unit',unitK,'2027-03-01',{loose:8}),
 // Official unit is UND even when physically kept in unopened cartons.
 lot('tablet-carton',unitK,'2028-01-01',{container:'caja',capacity:20,sealed:1,unit:'UND'}),
 // FCO/CJA are officially counted as opened packages (1/0).
 lot('early-open-box',packK,'2026-10-18',{container:'caja',capacity:100,opened:1,unit:'CJA'}),
 lot('later-sealed-box',packK,'2027-03-01',{container:'caja',capacity:100,sealed:1,unit:'CJA'})
 ],movements:[]};
const clone=JSON.stringify(original);
function line(id,p,qty,physicalUse){
 return{id,code:p.code,name:p.name,unit:p.unit,quantity:qty,procedure:'TRATAMIENTO ORAL',
  ...(physicalUse?{physicalUse}:{})};
}
function attention(id,site,dni,items){
 return{...visit(id,items),date:'2026-10-14',status:'saved',worker:{...visit().worker,site,dni}};
}
const visits=[
 attention('fundo-unit','LA VENTUROSA','00000001',[line('unit-5',unit,5)]),
 attention('planta-open','PLVENTUROSA','00000002',[line('box-2',pack,2,{lotId:'early-open-box',quantity:2})]),
 attention('fundo-reuse','LA VENTUROSA','00000003',[line('box-1',pack,1,{lotId:'later-sealed-box',quantity:1})]),
 attention('planta-tablet-carton','PLVENTUROSA','00000004',[line('unit-carton',unit,12)])
];
// Real attentions have distinct clock times; Excel always sorts chronologically.
visits.forEach((v,i)=>{v.time=['08:25','09:15','10:10','11:45'][i]});
let state=original;const outcomes=[];
for(let i=0;i<visits.length;i++){
 const result=stock.finalizeVisitAndPlanStock(state,visits[i],t+i*2000);
 outcomes.push(result);state=result.ledger;
}
assert(outcomes.every(r=>r.deducted===1&&r.pending===0),'every synthetic visit must be auto-recorded');
ledgerRules.validateStockLedger(state);
assert.equal(state.movements.filter(m=>m.kind==='use').length,7,'2 UND FEFO + 2 CJA split + 1 CJA repeat + 2 carton UND FEFO');
const lines=state.movements.reduce((r,m)=>{
 const k=m.dispenseRef?.itemId||'';
 (r[k]??=[]).push(m);return r;
},{});
assert.deepEqual(lines['unit-5'].map(m=>m.quantity),[2,3]);
assert.deepEqual(lines['box-2'].map(m=>m.excelQuantity),[0,1]);
assert.deepEqual(lines['box-1'].map(m=>m.excelQuantity),[0]);
assert.deepEqual(lines['unit-carton'].map(m=>m.quantity),[5,7]);
assert.deepEqual(lines['unit-carton'].map(m=>m.excelQuantity),[5,7]);
assert.equal(state.lots.find(l=>l.id==='early-unit').looseUnits,0);
assert.equal(state.lots.find(l=>l.id==='later-unit').looseUnits,0);
assert.equal(state.lots.find(l=>l.id==='tablet-carton').openedRemaining,13);
assert.equal(state.lots.find(l=>l.id==='early-open-box').openedRemaining,0);
assert.equal(state.lots.find(l=>l.id==='later-sealed-box').openedRemaining,98);
assert.equal(JSON.stringify(original),clone,'the test must not mutate initial stock');

const indicator=buildAmbulatoryRows(visits,state,'2026-10-09','2026-11-08',{perVisitSubdivision:true});
assert.deepEqual(indicator.blockers,[]);
assert.equal(indicator.visits,4);
assert.equal(indicator.linkedDeliveries,4,'split movement groups count once per clinical item');
assert.equal(indicator.lines.length,4,'one line per item, never per FEFO lot');
assert.deepEqual(indicator.lines.map(x=>x.cells[17]),[5,1,0,12],
 'CONSUMOS R: individual units vs packaging 1/0');
assert.deepEqual(indicator.lines.map(x=>x.cells[0]),['LA VENTUROSA','PLVENTUROSA','LA VENTUROSA','PLVENTUROSA']);
const nurse=buildDailyReport(state,'2026-10-14');
const nurseRange=buildKardexRangeReport(state,'2026-10-14','2026-10-14');
const byCode=c=>nurse.rows.find(r=>r.code===c);
const units=byCode('E-22'),boxes=byCode('E-57');
assert.equal(units.stockKnown,true);
assert.equal(units.initial,30,'10 loose units plus 20 tablets in a sealed carton');
assert.equal(units.consumed,17,'5 UND plus 12 UND from carton');
assert.equal(units.final,13);
assert.equal(boxes.initial,1,'only sealed packages contribute to CJA starting stock');
assert.equal(boxes.consumed,1,'R 0+1+0 despite three physical withdrawals');
assert.equal(boxes.final,0);
assert.equal(nurse.exportable,true,nurse.warnings.join('; '));
assert.equal(nurseRange.exportable,true,nurseRange.warnings.join('; '));
assert.deepEqual(nurseRange.rows.filter(r=>r.code==='E-22'||r.code==='E-57').map(r=>r.consumed),[17,1]);

const officialIndicator=unzipSync(exportAmbulatoryWorkbook(
 new Uint8Array(Buffer.from(embeddedIndicator.zipBase64,'base64')),
 indicator,sharedMonthlyReconciliation(state,indicator)));
const book=parse(strFromU8(officialIndicator['xl/workbook.xml']));
assert.deepEqual(all(book,'sheet').map(x=>x.getAttribute('name')),embeddedIndicator.sheets,
 'the delivered app must embed the exact original ten-sheet template');
const consumeXml=parse(strFromU8(officialIndicator['xl/worksheets/sheet5.xml']));
const icell=ref=>all(consumeXml,'c').find(c=>c.getAttribute('r')===ref);
for(let i=0;i<4;i++){
 assert.equal(Number(value(icell('R'+(i+2)))),[5,1,0,12][i]);
 assert.equal(value(icell('P'+(i+2))),[unit.code,pack.code,pack.code,unit.code][i]);
}
const resu=parse(strFromU8(officialIndicator['xl/worksheets/sheet4.xml']));
const rc=ref=>all(resu,'c').find(c=>c.getAttribute('r')===ref);
for(const p of [unit,pack]){
 const i=products.findIndex(x=>x.code===p.code)+3;
 assert.equal(value(rc('M'+i)),'','manual comment stays editable/blank');
 assert.equal(all(rc('F'+i),'f').length,1,'RESU formulas survive');
}
const nurseBytes=new Uint8Array(fs.readFileSync('public/internal/kardex-template.bin'));
const nurseOutput=unzipSync(exportOfficialKardex(nurseBytes,nurse,'MAÑANA','PERSONA FICTICIA'));
const nurseBook=parse(strFromU8(nurseOutput['xl/workbook.xml']));
assert.deepEqual(all(nurseBook,'sheet').map(x=>x.getAttribute('name')),['KARDEX ENFERMERAS']);
const nurseXml=parse(strFromU8(nurseOutput['xl/worksheets/sheet2.xml']));
const kcell=ref=>all(nurseXml,'c').find(c=>c.getAttribute('r')===ref);
const index=id=>cat.findIndex(c=>c.id===id)+7;
assert.equal(Number(value(kcell('G'+index('E-22')))),17);
assert.equal(Number(value(kcell('G'+index('E-57')))),1);
assert.equal(Number(value(kcell('D'+index('E-22')))),30);
assert.equal(Number(value(kcell('H'+index('E-22')))),13);
for(const id of ['E-22','E-57']){
 const i=index(id);
 assert.equal(all(kcell('F'+i),'f')[0]?.textContent,'D'+i+'+E'+i);
 assert.equal(all(kcell('H'+i),'f')[0]?.textContent,'F'+i+'-G'+i);
}
assert.equal(indicator.lines.filter(x=>x.cells[15]===unit.code).reduce((n,x)=>n+x.cells[17],0),units.consumed);
assert.equal(indicator.lines.filter(x=>x.cells[15]===pack.code).reduce((n,x)=>n+x.cells[17],0),boxes.consumed);

// Provisional fallbacks must not damage the already verified physical rows.
const absent=attention('no-physical-stock','LA VENTUROSA','00000005',[line('unverified',unit,40)]);
absent.time='12:30';
const pendingPlan=stock.finalizeVisitAndPlanStock(state,absent,t+8000);
assert.equal(pendingPlan.pending,1,'no stock remaining for unverified extra units');
const provisional=buildAmbulatoryRows([...visits,absent],pendingPlan.ledger,'2026-10-09','2026-11-08',
 {perVisitSubdivision:true,allowPendingDeliveries:true});
assert.equal(provisional.lines.length,5);
assert.deepEqual(provisional.lines.map(x=>x.cells[17]),[5,1,0,12,40]);
assert.deepEqual(provisional.unverifiedLineIds,[provisional.lines[4].id]);
assert.equal(provisional.pendingDeliveries,1);
assert.equal(JSON.stringify(state),JSON.stringify(pendingPlan.ledger),'pending output does not fabricate movements');

// Fractional physical use (e.g., 0.5 mL) must not be confused with the
// integer official package opening count. This is a real FCO/CJA edge case.
const fractionalLots={lots:[
 lot('frac-open',packK,'2026-10-18',{container:'caja',capacity:100,opened:0.25,unit:'CJA'}),
 lot('frac-sealed',packK,'2027-03-01',{container:'caja',capacity:100,sealed:1,unit:'CJA'})
],movements:[]};
const fractionalVisit=attention('fractional-case','LA VENTUROSA','00000006',
 [line('fractional-box',pack,1,{lotId:'frac-open',quantity:0.5})]);
const fractionalOut=stock.finalizeVisitAndPlanStock(fractionalLots,fractionalVisit,t+14000);
assert.equal(fractionalOut.deducted,1);
assert.deepEqual(fractionalOut.ledger.movements.map(m=>m.quantity),[0.25,0.25]);
assert.deepEqual(fractionalOut.ledger.movements.map(m=>m.excelQuantity),[0,1]);
const fractionalIndicator=buildAmbulatoryRows([fractionalVisit],fractionalOut.ledger,
 '2026-10-09','2026-11-08',{perVisitSubdivision:true});
assert.equal(fractionalIndicator.lines.length,1);
assert.ok(fractionalOut.ledger.movements.every(m=>m.dispenseRef?.physicalTotal===0.5),
 'split metadata must carry original fractional physical quantity');
const tamperedTotal={...fractionalOut.ledger,movements:fractionalOut.ledger.movements.map((m,i)=>
 i===0?{...m,dispenseRef:{...m.dispenseRef,physicalTotal:0.75}}:m)};
assert.throws(()=>ledgerRules.validateStockLedger(tamperedTotal),/Inconsistencia|cantidad física/,'split total tampering must be rejected at the storage level');
assert.equal(fractionalIndicator.lines[0].cells[17],1,'one opened box, not 0.5 box');
assert.equal(buildDailyReport(fractionalOut.ledger,'2026-10-14').rows.find(r=>r.code==='E-57').consumed,1);
assert.throws(()=>buildAmbulatoryRows([{...fractionalVisit,items:[
 {...fractionalVisit.items[0],physicalUse:{lotId:'frac-open',quantity:0.75}}
]}],fractionalOut.ledger,'2026-10-09','2026-11-08',{perVisitSubdivision:true}),
/no coinciden/,'tampered physical amount cannot silently export');
console.log('PASS: real 10-sheet Indicator and original 98-product nurse Kardex: FEFO cross-lot, UND-in-box, CJA R 0/1, 2 sites, one clinical row, exact stock and formula consistency.');
