const assert=require('node:assert/strict');
const {load,visit}=require('./ambulatory-test-helpers.cjs');
const products=require('../src/products.json');
const catalog=load('src/kardexCatalog.ts').kardexCatalog;
const {finalizeVisitAndPlanStock:run}=load('src/automaticClinicalDispensing.ts');
const {buildAmbulatoryRows}=load('src/ambulatoryRows.ts');
const date=Date.parse('2026-10-15T14:00:00Z');
const p=products.find(x=>x.code==='16000182'),box=products.find(x=>x.code==='16000013');
const needle=products.find(x=>x.code==='16000064');
assert(p&&box&&needle);
const item=(id,product=p,quantity=1)=>({id,code:product.code,name:product.name,unit:product.unit,quantity,procedure:'TRATAMIENTO ORAL'});
const a=(id,items)=>({...visit(id,items),date:'2026-10-15',status:'saved',worker:{...visit().worker,site:'LA VENTUROSA'}});
const empty={lots:[],movements:[]};
const one=a('one',[item('i')]);
const noStock=run(empty,one,date);
assert.equal(noStock.pending,1);assert.equal(noStock.deducted,0);
assert.equal(noStock.ledger.movements.length,0);
assert.equal(noStock.ledger.lots.length,0);
const original=JSON.stringify(one);
const c=catalog.find(x=>x.id==='E-22');
function lot(id,extra=0,q=8,code='E-22'){
 const cn=catalog.find(x=>x.id===code);
 return{id,code,name:cn.name,catalogUnit:'UND',lot:id,expires:extra===0?'2027-01-01':'2027-12-01',container:'unidad',unitsPerContainer:1,sealedContainers:0,looseUnits:q,openedRemaining:0,updatedAt:date-10000};
}
assert(c);
const stock={lots:[lot('jan',0,2),lot('dec',1,7)],movements:[]};
const first=run(stock,one,date);
assert.equal(first.deducted,1);assert.equal(first.pending,0);
assert.equal(first.ledger.lots[0].looseUnits,1,'FEFO chooses earliest expiry');
assert.equal(first.ledger.movements.length,1);
assert.equal(first.ledger.movements[0].excelQuantity,1);
assert.equal(first.ledger.movements[0].dispenseRef.attentionId,'one');
const historic=run(stock,{...one,date:'2026-10-14'},date);
assert.equal(historic.pending,1,'historical clinical use must not consume current stock');
assert.equal(historic.ledger.movements.length,0);
assert.equal(JSON.stringify(stock.lots),JSON.stringify([lot('jan',0,2),lot('dec',1,7)]),'pure planner cannot mutate input');
assert.equal(JSON.stringify(one),original);
const again=run(first.ledger,one,date+200);
assert.equal(again.deducted,0);assert.equal(again.pending,0);
assert.equal(again.results[0].outcome,'already-linked');
assert.equal(again.ledger.movements.length,1);
assert.throws(()=>run(first.ledger,a('one',[item('i',p,2)]),date+300),/cambiar un medicamento/);
const multiple=run(stock,a('two',[item('a'),item('b',p,2)]),date);
assert.equal(multiple.deducted,2,'both clinical items finished without a second module');
assert.equal(multiple.pending,0);
assert.equal(multiple.ledger.movements.length,3,'two lots for second item');
assert.equal(multiple.ledger.lots[0].looseUnits,0,'FEFO depleted earliest lot first');
assert.equal(multiple.ledger.lots[1].looseUnits,6);
const parts=multiple.ledger.movements.filter(m=>m.dispenseRef?.itemId==='b');
assert.deepEqual(parts.map(m=>m.quantity),[1,1]);
assert.deepEqual(parts.map(m=>m.dispenseRef?.partIndex),[1,2]);
assert.ok(parts.every(m=>m.dispenseRef?.partCount===2));
const exportedParts=buildAmbulatoryRows([a('two',[item('a'),item('b',p,2)])],multiple.ledger,
 '2026-10-09','2026-11-08',{perVisitSubdivision:true});
assert.equal(exportedParts.lines.length,2,'one CONSUMOS line per clinical item');
assert.equal(exportedParts.blockers.length,0);
assert.deepEqual(exportedParts.lines.map(l=>l.cells[17]),[1,2],'R is sum of audited lot parts');
assert.equal(exportedParts.linkedDeliveries,2,'physical parts do not double-count clinical items');
const savedAgain=run(multiple.ledger,a('two',[item('a'),item('b',p,2)]),date+300);
assert.equal(savedAgain.deducted,0);
assert.equal(savedAgain.ledger.movements.length,3,'retry never duplicates either FEFO part');
const {validateStockLedger}=load('src/kardexMovements.ts');
assert.throws(()=>validateStockLedger({lots:multiple.ledger.lots,
 movements:multiple.ledger.movements.filter(m=>m.dispenseRef?.partIndex!==2)}),
 /incompleta/,'a truncated physical split must never be considered a valid persisted ledger');
assert.throws(()=>validateStockLedger({lots:multiple.ledger.lots,
 movements:[...multiple.ledger.movements,{...multiple.ledger.movements[2],id:multiple.ledger.movements[2].id+':dup'}]}),
 /inválido|duplicado/,'duplicate FEFO parts cannot be restored');
const insufficient=run({lots:[lot('little',0,2),lot('next',1,1)],movements:[]},
 a('shortage',[item('amount-five',p,5)]),date);
assert.equal(insufficient.pending,1,'total across all lots must be sufficient');
assert.equal(insufficient.ledger.movements.length,0,'no partial stock debits allowed');
const mixedExpiry=run({lots:[{...lot('expired',0,9),expires:'2026-10-14'},
 {...lot('valid',1,9),expires:'2026-10-15'}],movements:[]},
 a('on-expiry',[item('today',p,2)]),Date.parse('2026-10-16T01:52:00Z'));
assert.equal(mixedExpiry.deducted,1,'today in Peru still eligible despite UTC next day');
assert.equal(mixedExpiry.ledger.movements[0].lotId,'valid');
assert.equal(mixedExpiry.ledger.lots[0].looseUnits,9,'already expired lot never debited');
const {peruStockDate}=load('src/inventoryRules.ts');
assert.equal(peruStockDate(Date.parse('2026-10-16T01:52:00Z')),'2026-10-15');


const depleted=run({lots:[lot('jan',0,1)],movements:[]},a('too-much',[item('i',p,100)]),date);
assert.equal(depleted.pending,1);
assert.equal(depleted.ledger.lots[0].looseUnits,1);
assert.equal(depleted.ledger.movements.length,0,'no negative stock');
const sealed={...lot('sealed',0,0),container:'caja',catalogUnit:'UND',unitsPerContainer:20,sealedContainers:2};
const open=run({lots:[sealed],movements:[]},a('first-open',[item('open-item',p,2)]),date);
assert.equal(open.deducted,1,'first unit dispense auto-opens a known sealed unit box');
assert.equal(open.ledger.lots[0].sealedContainers,1);
assert.equal(open.ledger.lots[0].openedRemaining,18);
assert.equal(open.ledger.movements[0].excelQuantity,2,'UND accounting stays 2, not 1 package');
const reuse=run(open.ledger,a('second-open',[item('reuse-item',p,2)]),date+2000);
assert.equal(reuse.deducted,1);
assert.equal(reuse.ledger.lots[0].openedRemaining,16);
assert.equal(reuse.ledger.movements[1].excelQuantity,2);
const boxed=run({lots:[lot('box',0,2,'E-57')],movements:[]},a('boxed',[item('needle',box)]),date);
assert.equal(boxed.pending,1,'a CJA must never be assumed to mean one needle without physical inner quantity');
const ambiguousProduct=products.find(x=>x.code==='16024400');
assert(ambiguousProduct);
const ambiguous=run({lots:[lot('x',0,20,'E-62'),lot('y',1,20,'E-63')],movements:[]},a('amb',[item('amb',ambiguousProduct)]),date);
assert.equal(ambiguous.pending,1,'never choose between E-62/E-63');
// Physical evidence for CJA/FCO is captured within the clinical item, not in Kardex.
const needleBoxLot={...lot('needle-pack',0,0,'E-57'),container:'caja',catalogUnit:'CJA',
 unitsPerContainer:100,sealedContainers:1,looseUnits:0,openedRemaining:0};
const boxLine={...item('needle',box),physicalUse:{lotId:'needle-pack',quantity:1}};
const unverifiedPack={...needleBoxLot,unitsPerContainer:1};
const unknownInner=run({lots:[unverifiedPack],movements:[]},a('unknown-inner',[boxLine]),date);
assert.equal(unknownInner.pending,1,'no fake 1 mL / unit when package capacity is unverified');
assert.equal(unknownInner.ledger.movements.length,0);
const firstBox=run({lots:[needleBoxLot],movements:[]},a('first-needle',[boxLine]),date);
assert.equal(firstBox.deducted,1,'in-form package details must be posted automatically');
assert.equal(firstBox.ledger.movements[0].quantity,1,'one physical needle used');
assert.equal(firstBox.ledger.movements[0].excelQuantity,1,'R=1 for first opening of a box');
assert.equal(firstBox.ledger.lots[0].openedRemaining,99);
const nextBox=run(firstBox.ledger,a('second-needle',[{...boxLine,id:'needle-next'}]),date+1000);
assert.equal(nextBox.deducted,1);
assert.equal(nextBox.ledger.movements[1].excelQuantity,0,'R=0 when using already-open box');
assert.equal(nextBox.ledger.lots[0].openedRemaining,98);
const openLot={...needleBoxLot,id:'opened-lot',lot:'opened-lot',expires:'2026-11-01',
 sealedContainers:0,openedRemaining:1};
const sealedNext={...needleBoxLot,id:'sealed-lot',lot:'sealed-lot',expires:'2027-03-01'};
const packagedSplit=run({lots:[openLot,sealedNext],movements:[]},
 a('pack-across-lots',[{...boxLine,id:'pack-item',physicalUse:{lotId:'opened-lot',quantity:2}}]),date);
assert.equal(packagedSplit.deducted,1,'auto FEFO packaged content spans open and sealed lots');
assert.equal(packagedSplit.ledger.movements.length,2);
assert.deepEqual(packagedSplit.ledger.movements.map(m=>m.excelQuantity),[0,1],
 'R reports first opening only, never number of clinical rows');
const packagedExcel=buildAmbulatoryRows([a('pack-across-lots',
 [{...boxLine,id:'pack-item',physicalUse:{lotId:'opened-lot',quantity:2}}])],
 packagedSplit.ledger,'2026-10-09','2026-11-08',{perVisitSubdivision:true});
assert.equal(packagedExcel.lines.length,1);
assert.equal(packagedExcel.lines[0].cells[17],1,'R 0+1 aggregated once');

const absentBox=run({lots:[],movements:[]},a('absent',[boxLine]),date);
assert.equal(absentBox.pending,1,'explicit past stock must never invent a present lot');
assert.equal(absentBox.ledger.movements.length,0);
assert.throws(()=>run({lots:[needleBoxLot],movements:[]},a('invalid-quantity',
 [{...boxLine,physicalUse:{lotId:'needle-pack',quantity:0}}]),date),/cantidad física válida/);
// E-62 and E-63 share an official code, requiring precise selection in the encounter.
const disambiguated=run({lots:[lot('x',0,20,'E-62'),lot('y',1,20,'E-63')],movements:[]},
 a('amb-selected',[{...item('amb',ambiguousProduct),physicalUse:{lotId:'y',quantity:1}}]),date);
assert.equal(disambiguated.deducted,1,'in-visit exact stock row resolves ambiguous official codes');
assert.equal(disambiguated.ledger.movements[0].lotId,'y');
assert.equal(disambiguated.ledger.lots[0].looseUnits,20,'must never subtract from wrong E-62 row');
assert.equal(disambiguated.ledger.lots[1].looseUnits,19);
const missingChoice=run({lots:[lot('x',0,20,'E-62')],movements:[]},
 a('missing-choice',[{...item('amb',ambiguousProduct),physicalUse:{lotId:'absent',quantity:1}}]),date);
assert.equal(missingChoice.pending,1);
assert.equal(missingChoice.ledger.movements.length,0);
const ui=require('node:fs').readFileSync('src/main.tsx','utf8');
assert.match(ui,/<ClinicalStockChoice item=\{i\}/,'in-form physical selection');
assert.match(ui,/stockLots:result.ledger.lots,stockMovements:result.ledger.movements/,
 'visit plus physical movement must be persisted as one encrypted snapshot');
assert.match(ui,/await writeDemoSnapshot\(snapshot\)/,'persistence before marking saved');
assert.match(ui,/const alreadySaved=att.some/, 'older saved attention must not be retroactively debited');
assert.match(ui,/alreadySaved\?\{/, 'on editing an existing visit only clinical state may change, not stock');
assert.match(ui,/m\.dispenseRef\.itemId===i\.id/, 'recognized existing stock links stay immutable');
const exporter=require('node:fs').readFileSync('src/AmbulatoryExportPanel.tsx','utf8');
assert.match(exporter,/onClick=\{\(\)=>void exportBook\(canDraft\)\}/,'single smart export action');
assert.match(exporter,/window.confirm\('EXCEL PROVISIONAL/,'draft export must require the operator\'s acknowledgement');
assert.doesNotMatch(exporter,/onClick=\{\(\)=>void exportBook\(true\)\}/,'no second export button');
const inline=require('node:fs').readFileSync('src/ClinicalStockChoice.tsx','utf8');
assert.match(inline,/Cantidad física utilizada/);
assert.match(inline,/Presentación pendiente de identificar/);
const amp=run({lots:[],movements:[]},a('amp',[item('amp',needle)]),date);
assert.equal(amp.pending,1);
const exportPlan=buildAmbulatoryRows([one],noStock.ledger,'2026-10-09','2026-11-08',{perVisitSubdivision:true,allowPendingDeliveries:true});
assert.equal(exportPlan.provisional,true);
assert.equal(exportPlan.pendingDeliveries,1);
assert.equal(exportPlan.lines[0].cells[17],'','missing stock never invents Excel R');
const exported=buildAmbulatoryRows([one],first.ledger,'2026-10-09','2026-11-08',{perVisitSubdivision:true});
assert.equal(exported.blockers.length,0);
assert.equal(exported.lines[0].cells[17],1);
console.log('PASS: one-click clinical finalization, FEFO auto-deduction, atomic source inputs, pending unknown stock, no negative/double deductions, packaged/ambiguous blocked, Excel R verified or blank.');
