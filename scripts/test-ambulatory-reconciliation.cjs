const assert=require('node:assert/strict');
const {load,visit,options}=require('./ambulatory-test-helpers.cjs');
const rules=load('src/ambulatoryReconciliation.ts');
const rows=load('src/ambulatoryRows.ts');
const products=require('../src/products.json');
const p=products[0],start='2026-10-13',end='2026-10-19',sub='LA VENTUROSA',base=Date.parse('2026-10-20T14:00:00Z');
const book=rows.buildAmbulatoryRows([visit('no-medication')],{lots:[],movements:[]},start,end,options);
const consumed={...book,lines:[{id:'used',cells:Array.from({length:30},(_,i)=>i===15?p.code:i===17?2:'')}]};
let seq=0;
function ev(kind,patch={}){
 seq++;
 return{id:'e'+seq,kind,subdivision:sub,code:(kind==='opening'||kind==='receipt'||kind==='count')?p.code:'',
 date:kind==='count'?end:start,at:base+seq*1000,
 quantity:kind==='opening'?10:kind==='receipt'?5:kind==='count'?13:0,
 reason:'Recuento ficticio supervisado',document:kind==='receipt'?'DOC-'+seq:'',expires:'',periodEnd:kind==='review'?end:'',voidOf:'',...patch};
}
function add(arr,e){return rules.appendReconciliationEvent(arr,e)}
const opening=ev('opening'),receipt=ev('receipt'),count=ev('count'),review=ev('review');
let events=[opening,receipt,count];
let report=rules.reconcileAmbulatoryReport(consumed,events,sub);
assert.equal(report.byCode[p.code].opening,10);
assert.equal(report.byCode[p.code].count,13);
assert.equal(report.byCode[p.code].receipts,undefined,'no zero for unreviewed receipts');
assert.equal(report.byCode[p.code].closing,undefined,'no invented closing before review');
assert.equal(report.reviewed,false);
events=add(events,review);
report=rules.reconcileAmbulatoryReport(consumed,events,sub);
assert.equal(report.byCode[p.code].opening,10);
assert.equal(report.byCode[p.code].receipts,5);
assert.equal(report.byCode[p.code].consumed,2);
assert.equal(report.byCode[p.code].closing,13);
assert.equal(report.byCode[p.code].count,13);
assert.equal(report.byCode[p.code].difference,0);
assert.equal(report.byCode[products[1].code].opening,undefined,'unknown is blank, not zero');
assert.equal(report.byCode[products[1].code].receipts,0,'reviewed and no receipt is exactly zero');
assert.equal(report.openingConfirmed,1);
assert.equal(report.countConfirmed,1);
assert.equal(report.receiptsConfirmed,1);
assert.throws(()=>add(events,ev('receipt',{document:'LATE-RECEIPT'})),/cierre/);
assert.throws(()=>add(events,ev('opening',{quantity:2})),/repetido/);
assert.throws(()=>add(events,ev('review')),/repetido/);
assert.throws(()=>add(events,ev('receipt',{code:'o2001232'})),/oficiales numéricos/);
assert.throws(()=>add(events,ev('receipt',{quantity:0})),/positiva/);
assert.throws(()=>add(events,ev('count',{quantity:-1})),/rango/);
assert.throws(()=>add(events,ev('receipt',{expires:'2026-02-31'})),/Vencimiento/);
assert.throws(()=>add(events,ev('receipt',{document:'x'})),/Documento/);
const removedReview=add(events,ev('void',{code:'',quantity:0,date:end,voidOf:review.id}));
assert.equal(rules.reconcileAmbulatoryReport(consumed,removedReview,sub).reviewed,false);
const late=add(removedReview,ev('receipt',{date:end,document:'INGRESO-ADICIONAL'}));
assert.equal(rules.reconcileAmbulatoryReport(consumed,late,sub).receiptsConfirmed,2);
assert.throws(()=>add(late,ev('void',{code:'',voidOf:review.id})),/anular/);
assert.throws(()=>add(late,ev('void',{code:'',voidOf:'unknown'})),/anular/);
const zeroOpening=add([],ev('opening',{quantity:0}));
assert.equal(rules.reconcileAmbulatoryReport(book,zeroOpening,sub).byCode[p.code].opening,0);
assert.throws(()=>rules.reconcileAmbulatoryReport(consumed,add(zeroOpening,ev('review')),sub),/negativo/);
let many=[];
for(let i=0;i<5;i++)many=add(many,ev('receipt',{date:start,document:'RECIBO-'+i}));
assert.throws(()=>rules.reconcileAmbulatoryReport(book,many,sub),/cuatro ingresos/);
assert.equal(rules.validateReconciliationEvents([]).length,0);
console.log('PASS: 0 vs missing, verified opening/count, four-receipt cap, closure, dated receipts, cancellation, negative balances, code and document validation.');
