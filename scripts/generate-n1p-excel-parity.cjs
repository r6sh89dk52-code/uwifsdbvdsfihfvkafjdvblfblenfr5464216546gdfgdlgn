'use strict';
/**
 * N1p: all expected 30-column rows and workbook structure come from the
 * actual build222 TypeScript engine. Synthetic fixtures ONLY, never uploads.
 */
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const crypto=require('node:crypto');
const {load,visit,all,parse,value}=require('./ambulatory-test-helpers.cjs');
const {buildAmbulatoryRows}=load('src/ambulatoryRows.ts');
const {exportAmbulatoryWorkbook}=load('src/ambulatoryExcel.ts');
const {readAmbulatoryArchive}=load('src/ambulatoryArchive.ts');
const template=require('../src/ambulatoryTemplate.json');
const products=require('../src/products.json');
const root=process.env.DANPER_N1_FIXTURE_DIR;
if(!root||!path.isAbsolute(root))throw Error('Synthetic absolute fixture dir required');
const source=JSON.parse(fs.readFileSync(path.join(root,'n1e-clinical-stock.json'),'utf8'));
const sha=data=>crypto.createHash('sha256').update(data).digest('hex');
const output=(name,data)=>fs.writeFileSync(path.join(root,name),JSON.stringify(data));
const workbookTemplate=new Uint8Array(fs.readFileSync('scripts/fixtures/ambulatory-empty.xlsx'));
const start='2026-10-09',end='2026-11-08';

function manifest(snapshot,id) {
 const plain=Buffer.from(JSON.stringify(snapshot));
 const plan=buildAmbulatoryRows(snapshot.attentions,
     {lots:snapshot.stockLots,movements:snapshot.stockMovements},
     start,end,{perVisitSubdivision:true,allowPendingDeliveries:true});
 assert.equal(plan.blockers.length,0,'Unexpected TypeScript clinical blocker: '+plan.blockers.join(' | '));
 assert.equal(plan.provisional,true);
 assert.ok(plan.lines.every(r=>r.cells.length===30));
 const book=exportAmbulatoryWorkbook(workbookTemplate,plan);
 const entries=readAmbulatoryArchive(book);
 const doc=(name)=>parse(Buffer.from(entries[name]).toString('utf8'));
 const sheetNames=all(doc('xl/workbook.xml'),'sheet').map(e=>e.getAttribute('name'));
 assert.deepEqual(sheetNames,template.sheets);
 const tableNames=Object.keys(entries).filter(n=>/^xl\/tables\/table\d+\.xml$/.test(n));
 assert.equal(tableNames.length,19);
 const materials=all(doc('xl/worksheets/sheet1.xml'),'row').length-1;
 assert.equal(materials,432);
 const consumos=doc('xl/worksheets/sheet5.xml');
 const consumedRows=all(consumos,'row').length;
 assert.equal(consumedRows,Math.max(2,plan.lines.length+1));
 const first=all(consumos,'row')[0],headers=all(first,'c').map(value);
 assert.deepEqual(headers,template.headers);
 const lines=plan.lines.map(v=>({id:v.id,cells:v.cells}));
 const result={
  schema:1,id,start,end,sourceSHA256:sha(plain),
  template:{sheets:sheetNames,materials,tables:tableNames.length,columns:headers.length,
    outputWorkbookSHA256:sha(book),consumosRows:consumedRows},
  plan:{visits:plan.visits,linkedDeliveries:plan.linkedDeliveries,
    pendingDeliveries:plan.pendingDeliveries,provisional:plan.provisional,
    unverifiedLineIds:plan.unverifiedLineIds,lines}
 };
 output('n1p-'+id+'-source.json',snapshot);
 output('n1p-'+id+'-expected.json',result);
 return result;
}
const original=manifest(source,'stock');
assert.deepEqual(original.plan.lines.map(r=>r.cells[17]),[5,1,0,12,1000]);
assert.equal(original.plan.pendingDeliveries,1);
assert.equal(original.plan.linkedDeliveries,4);
// A second independently exercised frequency/2-items/blank-row scenario.
const v0=visit('first',[
 {id:'one',...products.find(p=>p.code==='16000182'),quantity:2,procedure:'TRATAMIENTO ORAL'},
 {id:'two',...products.find(p=>p.code==='16000013'),quantity:1,procedure:'CURACION DE HERIDA'}
]);
v0.worker={...v0.worker,name:'IDENTIDAD SINTETICA ALFA',site:'LA VENTUROSA'};
v0.date='2026-10-14';
const allVisits=[v0];
for(let i=1;i<6;i++){
 const v={...structuredClone(v0),id:'visit-'+i,time:String(8+i).padStart(2,'0')+':25',
   items:[],standaloneProcedures:['OBSERVACION']};
 allVisits.push(v);
}
allVisits.push({...structuredClone(v0),id:'outside',date:'2026-10-08',items:[]});
allVisits.push({...structuredClone(v0),id:'incomplete-draft',status:'draft',items:[]});
const second=manifest({
 workers:[structuredClone(v0.worker)],attentions:allVisits,
 allergies:{},notifications:false,stockLots:[],stockMovements:[],
 catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]
},'frequency');
assert.equal(second.plan.visits,6);
assert.equal(second.plan.lines.length,7);
assert.deepEqual(second.plan.lines.map(x=>x.cells[18]),
 ['PRIMERA','PRIMERA','SEGUNDA','TERCERA','CUARTA','QUINTA','REVISAR']);
assert.deepEqual(second.plan.lines.map(x=>x.cells[17]),[2,1,'','','','','']);
assert.equal(second.plan.pendingDeliveries,2);
assert.deepEqual(second.plan.lines.slice(0,2).map(x=>x.cells[20]),['-','INSUMOS']);
console.log('PASS N1p: TypeScript official 10 sheets, 432 materials, 19 tables, 30 columns; synthetic stock R [5,1,0,12,1000], frequencies and pending verified.');
