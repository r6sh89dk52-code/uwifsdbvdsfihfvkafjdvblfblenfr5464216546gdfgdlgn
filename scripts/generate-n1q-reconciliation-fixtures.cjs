'use strict';
/**
 * N1q: real TypeScript reconcilation and 10-sheet OOXML produce ONLY synthetic
 * receipts/recount/formula reference JSON under GitHub runner temp.
 * The resulting XLSX is inspected in RAM and never published or persisted.
 */
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {load,parse,all,value}=require('./ambulatory-test-helpers.cjs');
const {buildAmbulatoryRows}=load('src/ambulatoryRows.ts');
const {reconcileAmbulatoryReport,validateReconciliationEvents}=load('src/ambulatoryReconciliation.ts');
const {exportAmbulatoryWorkbook}=load('src/ambulatoryExcel.ts');
const {readAmbulatoryArchive}=load('src/ambulatoryArchive.ts');
const official=require('../src/products.json');
const template=require('../src/ambulatoryTemplate.json');
const folder=process.env.DANPER_N1_FIXTURE_DIR;
assert(folder&&path.isAbsolute(folder),'N1q requires an absolute synthetic fixture directory');
const sourceBytes=fs.readFileSync(path.join(folder,'n1e-clinical-stock.json'));
const source=JSON.parse(sourceBytes.toString('utf8'));
const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
const periodStart='2026-10-09',periodEnd='2026-11-08',subdivision='LA VENTUROSA';
const selected=source.attentions.filter(v=>v.status==='saved'&&v.worker.site===subdivision);
assert.deepEqual(selected.map(v=>v.id),['fundo-unit','fundo-reuse']);
const plan=buildAmbulatoryRows(selected,
 {lots:source.stockLots,movements:source.stockMovements},periodStart,periodEnd,{subdivision});
assert.deepEqual(plan.blockers,[]);assert.equal(plan.provisional,undefined);
assert.equal(plan.linkedDeliveries,2);assert.deepEqual(plan.lines.map(x=>x.cells[17]),[5,0]);
const byCode=Object.fromEntries(official.map((p,i)=>[p.code,i+3]));
const codeUnit='16000182',codeBox='16000013',codeZero=official[0].code,codeMissing=official[1].code;
assert([codeUnit,codeBox,codeZero,codeMissing].every(code=>byCode[code]!==undefined));
let seq=0;
function make(kind,code='',quantity=0,options={}){
 const id='N1Q-EV-'+(++seq);
 return {id,kind,subdivision,code,
  date:kind==='count'?periodEnd:periodStart,at:Date.parse('2026-11-09T14:00:00Z')+seq*1000,
  quantity,reason:'Verificacion enteramente sintetica',document:'',expires:'',
  periodEnd:kind==='review'?periodEnd:'',voidOf:'',...options};
}
const events=[
 make('opening',codeUnit,10),
 make('opening',codeBox,2),
 make('opening',codeZero,0),
 make('receipt',codeUnit,3,{date:'2026-10-12',document:'N1Q-REC-001',expires:'2027-12-30'}),
 make('receipt',codeUnit,4,{date:'2026-10-16',document:'N1Q-REC-002'}),
 make('receipt',codeBox,2,{date:'2026-10-17',document:'N1Q-REC-003'}),
 make('count',codeUnit,12),
 make('count',codeBox,3),
 make('count',codeZero,0)
];
const reviewed=[...events,make('review','',0)];
const voided=[...reviewed,make('void','',0,{voidOf:reviewed.at(-1).id})];
const templateBytes=new Uint8Array(fs.readFileSync('scripts/fixtures/ambulatory-empty.xlsx'));
const samples=[3,byCode[codeUnit],byCode[codeBox],434];
const formulas={conteo:['H'],ingresos:['D','E','F','G','X'],resu:['E','F','G','H','I','J','L']};
const interesting=[codeUnit,codeBox,codeZero,codeMissing];
function fixture(mode,log){
 const validated=validateReconciliationEvents(log);
 const material=reconcileAmbulatoryReport(plan,validated,subdivision);
 const xlsx=exportAmbulatoryWorkbook(templateBytes,plan,material);
 const entries=readAmbulatoryArchive(xlsx);
 const doc=(i)=>parse(Buffer.from(entries['xl/worksheets/sheet'+i+'.xml']).toString('utf8'));
 const workbook=parse(Buffer.from(entries['xl/workbook.xml']).toString('utf8'));
 assert.deepEqual(all(workbook,'sheet').map(x=>x.getAttribute('name')),template.sheets);
 const recalculation=all(workbook,'calcPr')[0];
 assert.equal(recalculation.getAttribute('fullCalcOnLoad'),'1');
 assert.equal(recalculation.getAttribute('forceFullCalc'),'1');
 const worksheets={conteo:doc(2),ingresos:doc(3),resu:doc(4)};
 const indexed=Object.fromEntries(Object.entries(worksheets).map(([name,d])=>[
    name,new Map(all(d,'c').map(x=>[x.getAttribute('r'),x]))
 ]));
 const cell=(sheet,address)=>indexed[sheet].get(address);
 const contents=(sheet,address)=>{const x=cell(sheet,address);return x?value(x):''};
 const f=(sheet,address)=>{const c=cell(sheet,address);return c?all(c,'f')[0]?.textContent||'':''};
 const formulaSamples=samples.map(row=>{
  const selected={row};
  for(const [name,columns]of Object.entries(formulas))
   selected[name]=Object.fromEntries(columns.map(col=>[col,f(name,col+row)]));
  return selected;
 });
 for(let row=3;row<=434;row++){
  for(const [name,columns] of Object.entries(formulas))
   for(const col of columns){
    if(name==='ingresos'&&col==='X'&&!material.reviewed)
      assert.equal(f(name,col+row),'','Unreviewed receipts must keep total X blank');
    else assert.ok(f(name,col+row),'missing formula '+name+'!'+col+row);
   }
 }
 const physicalCells=interesting.map(code=>{
  const row=byCode[code];
  const count=contents('conteo','D'+row),opening=contents('resu','D'+row);
  const income=Object.fromEntries(['H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X']
         .map(c=>[c,contents('ingresos',c+row)]));
  assert.equal(contents('resu','M'+row),'');
  assert.equal(f('resu','F'+row),'SUMIF(TB_CONSUMOS[CÓDIGO],A'+row+',TB_CONSUMOS[CANTIDAD])');
  return {code,row,count,opening,income,comment:contents('resu','M'+row)};
 });
 const output={
  schema:1,mode,sourceSHA256:sha(sourceBytes),
  periodStart,periodEnd,subdivision,selectedVisitIDs:selected.map(x=>x.id),
  catalog:official,events:validated,workbook:{
    sha256:sha(xlsx),sheets:template.sheets,materials:official.length,tables:
    Object.keys(entries).filter(n=>/^xl\/tables\/table\d+\.xml$/.test(n)).length,
    formulaRows:432,fullCalcOnLoad:true,forceFullCalc:true,
    formulaSamples,physicalCells
  },summary:{
    openingConfirmed:material.openingConfirmed,countConfirmed:material.countConfirmed,
    receiptsConfirmed:material.receiptsConfirmed,reviewed:material.reviewed,
    warnings:material.warnings
  },byCode:material.byCode
 };
 assert.equal(output.workbook.tables,19);
 assert.equal(output.workbook.materials,432);
 fs.writeFileSync(path.join(folder,'n1q-'+mode+'-expected.json'),JSON.stringify(output));
 return output;
}
const a=fixture('reviewed',reviewed);
assert.equal(a.summary.reviewed,true);
assert.deepEqual([a.summary.openingConfirmed,a.summary.countConfirmed,a.summary.receiptsConfirmed],[3,3,3]);
assert.deepEqual([a.byCode[codeUnit].opening,a.byCode[codeUnit].receipts,
 a.byCode[codeUnit].consumed,a.byCode[codeUnit].closing,a.byCode[codeUnit].count,
 a.byCode[codeUnit].difference],[10,7,5,12,12,0]);
assert.deepEqual([a.byCode[codeBox].opening,a.byCode[codeBox].consumed,
 a.byCode[codeBox].closing,a.byCode[codeBox].count,a.byCode[codeBox].difference],[2,0,4,3,1]);
assert.equal(a.byCode[codeZero].opening,0);
assert.equal(a.byCode[codeZero].closing,0);
assert.equal(a.byCode[codeMissing].opening,undefined);
assert.equal(a.byCode[codeMissing].receipts,0);
const b=fixture('unreviewed',events);
assert.equal(b.summary.reviewed,false);
assert.equal(b.byCode[codeUnit].receipts,undefined);
assert.equal(b.byCode[codeUnit].closing,undefined);
assert.equal(b.byCode[codeUnit].count,12);
const c=fixture('voided',voided);
assert.equal(c.summary.reviewed,false);
assert.equal(c.byCode[codeUnit].receipts,undefined);
assert.equal(c.summary.receiptsConfirmed,3);
console.log('PASS N1q: 3 synthetic modes, 432 verified official formula rows, 10 sheets, 19 tables; no real data or emitted XLSX.');
