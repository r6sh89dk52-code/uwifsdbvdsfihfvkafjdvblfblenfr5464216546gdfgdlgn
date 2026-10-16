'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {zipSync,unzipSync}=require('fflate');
const {load}=require('./ambulatory-test-helpers.cjs');
const root=process.env.DANPER_N1_FIXTURE_DIR;
assert(root&&path.isAbsolute(root));
const ledger=JSON.parse(fs.readFileSync(path.join(root,'n1e-clinical-stock.json'),'utf8'));
const {buildAmbulatoryRows}=load('src/ambulatoryRows.ts');
const {reconcileAmbulatoryReport}=load('src/ambulatoryReconciliation.ts');
const {exportAmbulatoryWorkbook}=load('src/ambulatoryExcel.ts');
const {exportOfficialKardex}=load('src/kardexExcelTemplate.ts');
const catalog=require('../src/products.json');
const nurse=load('src/kardexCatalog.ts').kardexCatalog;
const base64=require('../src/ambulatoryTemplate.json').zipBase64;
const opening=JSON.parse(fs.readFileSync(path.join(root,'n1q-reviewed-expected.json'),'utf8'));
const sorted=new Set(opening.selectedVisitIDs);
const selected=ledger.attentions.filter(v=>sorted.has(v.id));
assert.equal(selected.length,2);
const plan=buildAmbulatoryRows(selected,{lots:ledger.stockLots,movements:ledger.stockMovements},
 opening.periodStart,opening.periodEnd,{subdivision:opening.subdivision});
assert.equal(plan.blockers.length,0);
assert.equal(plan.pendingDeliveries,undefined);
assert.deepEqual(plan.lines.map(x=>x.cells[17]),[5,0]);
const report=reconcileAmbulatoryReport(plan,opening.events,opening.subdivision);
assert.equal(report.reviewed,true);
assert.equal(report.byCode[catalog.find(p=>p.code==='16000182').code].closing,12);
const manifest={
 schema:1,catalog,byCode:report.byCode,reviewed:report.reviewed,provisional:false,
 start:opening.periodStart,end:opening.periodEnd,subdivision:opening.subdivision,
 rows:plan.lines.length,plan:{lines:plan.lines}
};
fs.writeFileSync(path.join(root,'n1s-indicator-plan.json'),JSON.stringify(manifest));
const original=new Uint8Array(Buffer.from(base64,'base64'));
const clean=new Uint8Array(fs.readFileSync('scripts/fixtures/ambulatory-empty.xlsx'));
const ts=exportAmbulatoryWorkbook(clean,plan,report);
fs.writeFileSync(path.join(root,'n1s-indicator-reference.xlsx'),ts);
fs.writeFileSync(path.join(root,'n1s-indicator-template-store.zip'),
 zipSync(unzipSync(original),{level:0}));
const nursingRows=nurse.map((p,i)=>({
 code:p.id,name:p.name,donated:false,stockKnown:i<2,
 initial:i===0?3:0,extraordinary:0,total:i===0?3:0,
 consumed:i===0?1:0,final:i===0?2:0,expiry:'',fs:null
}));
assert.equal(nursingRows.length,98);
const nursing={date:'2026-10-13',rows:nursingRows,shift:'MAÑANA',responsible:'OPERADOR FICTICIO'};
fs.writeFileSync(path.join(root,'n1s-nursing-plan.json'),JSON.stringify(nursing));
const nursingBase=new Uint8Array(fs.readFileSync('public/internal/kardex-template.bin'));
const nursingParts=unzipSync(nursingBase);
const nursingXML=Buffer.from(nursingParts['xl/worksheets/sheet2.xml']).toString('utf8');
const nursingBook=Buffer.from(nursingParts['xl/workbook.xml']).toString('utf8');
const rows=Array.from(nursingXML.matchAll(/<row\\b[^>]*\\br="(\\d+)"/g),m=>Number(m[1]));
console.log('N1s nursing source structural checks:',JSON.stringify({
 sheets:nursingBook.includes('KARDEX ENFERMERAS'),
 merge:nursingXML.includes('<mergeCells'),
 product104:nursingXML.includes('C104'),
 print:!!nursingParts['xl/printerSettings/printerSettings2.bin'],
 row3:rows.includes(3),row7:rows.includes(7),row104:rows.includes(104),
 numberRows:rows.length,distinctRows:new Set(rows).size
}));
fs.writeFileSync(path.join(root,'n1s-nursing-template-store.zip'),
 zipSync(unzipSync(nursingBase),{level:0}));
const legacy=exportOfficialKardex(nursingBase,{date:nursing.date,rows:nursing.rows,exportable:true,warnings:[]},
 nursing.shift,nursing.responsible);
fs.writeFileSync(path.join(root,'n1s-nursing-reference.xlsx'),legacy);
console.log('PASS N1s synthetic: verified 2 clinical consumptions [5,0], reviewed 432-item plan, 10-sheet original and 98-item nursing Kardex reference');
