const assert=require('node:assert/strict'),fs=require('node:fs');
const {load,visit,parse,all,value}=require('./ambulatory-test-helpers.cjs');
const {unzipSync,strFromU8}=require('fflate');
const products=require('../src/products.json');
const {postConfirmedAttentionDelivery}=load('src/attentionKardex.ts');
const {buildAmbulatoryRows}=load('src/ambulatoryRows.ts');
const {sharedMonthlyReconciliation}=load('src/sharedInventoryReports.ts');
const {exportAmbulatoryWorkbook}=load('src/ambulatoryExcel.ts');
const catalog=load('src/kardexCatalog.ts').kardexCatalog;
const code='16000182',product=products.find(p=>p.code===code);
assert(product,'test catalog material missing');
const nursing=catalog.find(p=>p.id==='E-22');
assert(nursing,'approved nursing lot code missing');
const first={...visit('fundo'),date:'2026-10-01',
 worker:{...visit().worker,site:'LA VENTUROSA',dni:'00000001'},
 items:[{id:'f-medicine',...product,quantity:1,procedure:'TRATAMIENTO ORAL'}]};
const second={...visit('planta'),date:'2026-10-01',
 worker:{...visit().worker,site:'PLVENTUROSA',dni:'00000002'},
 items:[{id:'p-medicine',...product,quantity:2,procedure:'TRATAMIENTO ORAL'}]};
const timestamp=Date.parse('2026-10-01T16:00:00Z');
let ledger={lots:[{id:'one-physical-lot',code:'E-22',name:nursing.name,catalogUnit:'UND',lot:'TEST-COMPARTIDO',
 expires:'2028-12-30',container:'unidad',unitsPerContainer:1,sealedContainers:0,looseUnits:12,
 openedRemaining:0,updatedAt:Date.parse('2026-09-09T13:00:00Z')}],movements:[]};
function dispense(v,time,qty){return postConfirmedAttentionDelivery(ledger,v,{itemId:v.items[0].id,
 lotId:'one-physical-lot',physicalQuantity:qty,confirmIdentity:true,confirmUnits:true,
 confirmDelivery:true,openNewContainer:false,timestamp:time})}
ledger=dispense(first,timestamp,1);
assert.equal(ledger.lots[0].looseUnits,11);
ledger=dispense(second,timestamp+1000,2);
assert.equal(ledger.lots[0].looseUnits,9,'both worksites consume the same lot');
assert.equal(ledger.lots.length,1,'never duplicate lots by site');
assert.equal(ledger.movements.length,2,'exactly one movement per confirmed item');
assert.throws(()=>postConfirmedAttentionDelivery(ledger,first,{
 itemId:'f-medicine',lotId:'one-physical-lot',physicalQuantity:1,confirmIdentity:true,
 confirmUnits:true,confirmDelivery:true,openNewContainer:false,timestamp:timestamp+2000
}),/ya tiene una entrega/,'idempotent delivery across sites');
const start='2026-09-09',end='2026-10-08';
const plan=buildAmbulatoryRows([first,second],ledger,start,end,{perVisitSubdivision:true});
assert.equal(plan.visits,2);
assert.equal(plan.blockers.length,0);
assert.deepEqual(plan.lines.map(r=>r.cells[0]),['LA VENTUROSA','PLVENTUROSA']);
assert.deepEqual(plan.lines.map(r=>r.cells[17]),[1,2]);
assert.deepEqual(plan.lines.map(r=>r.cells[18]),['PRIMERA','PRIMERA']);
const material=sharedMonthlyReconciliation(ledger,plan);
assert.equal(material.byCode[code].opening,12);
assert.equal(material.byCode[code].closing,9);
assert.equal(material.byCode[code].consumed,3);
const original=new Uint8Array(fs.readFileSync('scripts/fixtures/ambulatory-empty.xlsx'));
const archive=unzipSync(exportAmbulatoryWorkbook(original,plan,material));
const book=parse(strFromU8(archive['xl/workbook.xml']));
assert.equal(all(book,'sheet').length,10,'one complete official ten-sheet workbook');
const consumos=parse(strFromU8(archive['xl/worksheets/sheet5.xml']));
const cell=ref=>all(consumos,'c').find(x=>x.getAttribute('r')===ref);
assert.equal(value(cell('A2')),'LA VENTUROSA');
assert.equal(value(cell('A3')),'PLVENTUROSA');
assert.equal(value(cell('R2')),'1');
assert.equal(value(cell('R3')),'2');
assert(all(cell('C2'),'f').length&&all(cell('D3'),'f').length,'official organization formulas preserved on both rows');
const emptySite={...first,id:'unknown-site',worker:{...first.worker,site:''},items:[]};
const blocked=buildAmbulatoryRows([emptySite],ledger,start,end,{perVisitSubdivision:true});
assert(blocked.blockers.some(x=>/sin sede oficial/.test(x)),'unknown site never assigned a guessed code');
assert.throws(()=>exportAmbulatoryWorkbook(original,blocked,material),/pendientes/);
const ui=fs.readFileSync('src/AmbulatoryExportPanel.tsx','utf8');
for(const required of ['buildAmbulatoryRows(attentions,ledger,start,end,{perVisitSubdivision:true',
 'sharedMonthlyReconciliation(ledger,result.data)','findOfficialArea(a.worker.site','Kardex único',
 'DANPER_Indicador_Ambulatorio_']){
 assert(ui.includes(required),'missing consolidated UI: '+required);
}
for(const forbidden of ['siteVisits','setSubdivision','Reporte individual de sede','Sede o fundo del reporte','otherSiteVisits']){
 assert(!ui.includes(forbidden),'obsolete per-site report UI: '+forbidden);
}
const workflow=fs.readFileSync('.github/workflows/ios-ipa.yml','utf8');
assert(/on:\s*\n  workflow_dispatch:\s*\n/.test(workflow),'macOS is manual-only');
assert(!/^  push:|^  pull_request:/m.test(workflow),'no automatic macOS runs');
console.log('PASS: one shared stock (12→11→9), 2 sites, 2 linked deductions, one 10-sheet report, official A/C/D formulas, and manual-only macOS.');
