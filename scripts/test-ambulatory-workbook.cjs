const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {zipSync,unzipSync,strToU8,strFromU8}=require('fflate');
const {load,parse,all,value,visit,options,M}=require('./ambulatory-test-helpers.cjs');
const {exportAmbulatoryWorkbook:exportBook}=load('src/ambulatoryExcel.ts');
const {readAmbulatoryArchive}=load('src/ambulatoryArchive.ts');
const {buildAmbulatoryRows:build}=load('src/ambulatoryRows.ts');
const {reconcileAmbulatoryReport:reconcile}=load('src/ambulatoryReconciliation.ts');
const template=require('../src/ambulatoryTemplate.json'),products=require('../src/products.json');
const fixture=new Uint8Array(fs.readFileSync('scripts/fixtures/ambulatory-empty.xlsx'));
const plan=vs=>build(vs,{lots:[],movements:[]},'2026-10-13','2026-10-13',options);
const empty=plan([]),one=plan([visit()]);
const unpack=bytes=>readAmbulatoryArchive(bytes);
const doc=(parts,name)=>parse(strFromU8(parts[name]));
const cell=(d,ref)=>all(d,'c').find(c=>c.getAttribute('r')===ref);
const patch=(name,fn,base=fixture)=>{const parts=unzipSync(base);parts[name]=strToU8(fn(strFromU8(parts[name])));return zipSync(parts);};
let passed=0;
function test(name,run){try{run();passed++;}catch(e){console.error('FAIL:',name);throw e}}
function integrity(bytes,rows,reconciled=false){
 const parts=unpack(bytes);
 for(const[name,data]of Object.entries(parts)){
  assert.ok(name.endsWith('.xml')||name.endsWith('.rels'));
  const d=parse(strFromU8(data));assert.ok(d.documentElement);
  assert.ok(!/externalLinks|sharedStrings|calcChain|pivot|comments|vml|customXml|docProps|printerSettings/i.test(name));
  assert.ok(!/\[1\]|#REF!|_xlfn/.test(strFromU8(data)),name);
  if(name.endsWith('.rels'))for(const r of Array.from(d.getElementsByTagName('Relationship'))){
   assert.notEqual(r.getAttribute('TargetMode'),'External');
   const source=name==='_rels/.rels'?'':name.replace('/_rels/','/').replace(/\.rels$/,'');
   const target=r.getAttribute('Target');
   const resolved=target.startsWith('/')?target.slice(1):path.posix.normalize(path.posix.join(path.posix.dirname(source),target));
   assert.ok(parts[resolved],'missing relationship target '+resolved);
  }
 }
 const book=doc(parts,'xl/workbook.xml');assert.deepEqual(all(book,'sheet').map(s=>s.getAttribute('name')),template.sheets);
 assert.equal(all(book,'calcPr')[0].getAttribute('fullCalcOnLoad'),'1');
 const catalog=doc(parts,'xl/worksheets/sheet1.xml');const catRows=all(catalog,'row').slice(1);
 assert.equal(catRows.length,432);
 assert.deepEqual(catRows.map(r=>all(r,'c').map(value)),products.map(p=>[p.code,p.name,p.unit]));
 const consumos=doc(parts,'xl/worksheets/sheet5.xml');
 assert.equal(all(consumos,'row').length,Math.max(2,rows+1));
 assert.deepEqual(all(all(consumos,'row')[0],'c').map(value),template.headers);
 const tables=Object.keys(parts).filter(n=>/^xl\/tables\/table\d+\.xml$/.test(n));assert.equal(tables.length,19);
 const t=tables.map(n=>doc(parts,n)).find(d=>d.documentElement.getAttribute('displayName')==='TB_CONSUMOS');
 assert.equal(t.documentElement.getAttribute('ref'),'A1:AD'+Math.max(2,rows+1));
 const columns=all(t,'tableColumn');assert.equal(columns.length,30);
 assert.deepEqual(columns.map(c=>c.getAttribute('name')),template.tableHeaders);
 assert.equal(all(t,'calculatedColumnFormula').length,2,'only verified organization formulas');
 for(const col of [8,9,10,16,28])assert.equal(all(columns[col],'calculatedColumnFormula').length,0,'must not overwrite current plan data');
 for(const sheet of [2,3,4])assert.equal(all(doc(parts,`xl/worksheets/sheet${sheet}.xml`),'row').length,434);
 const summary=doc(parts,'xl/worksheets/sheet4.xml');
 assert.equal(value(cell(summary,'M2')),'COMENTARIO','original manual column title survives');
 for(let row=3;row<=434;row++){
  assert.equal(value(cell(summary,'M'+row)),'','manual comment must be empty for all 432 materials at row '+row);
  assert.equal(value(cell(summary,'K'+row)),'','monthly projection remains an editable blank');
  for(const col of ['E','F','G','H','I','J','L'])
   assert.equal(all(cell(summary,col+row),'f').length,1,'formula missing in RESU!'+col+row);
 }
 if(!reconciled){
  assert.equal(value(cell(doc(parts,'xl/worksheets/sheet4.xml'),'D3')),'');
  assert.equal(value(cell(doc(parts,'xl/worksheets/sheet4.xml'),'M3')),'','manual COMENTARIO field must be blank');
 }
 const gui=doc(parts,'xl/worksheets/sheet7.xml');for(const c of all(gui,'c'))if(/^[TU][2-9]\d*$|^[TU]1\d+$/.test(c.getAttribute('r')))assert.equal(value(c),'');
 return parts;
}
test('0 visits 10 sheets 432 materials 19 tables',()=>integrity(exportBook(fixture,empty),0));
test('1 visit snapshot identifiers',()=>{const parts=integrity(exportBook(fixture,one),1),d=doc(parts,'xl/worksheets/sheet5.xml');assert.equal(value(cell(d,'H2')),'00000001');assert.equal(cell(d,'H2').getAttribute('t'),'inlineStr');assert.equal(value(cell(d,'F2')),'46308');assert.ok(Number(value(cell(d,'G2')))>0);assert.equal(value(cell(d,'AD2')),'DX FICTICIO');});
test('3 visits',()=>integrity(exportBook(fixture,plan([visit('a'),visit('b'),visit('c')])),3));
test('3000 visits expanded formatting/validations/tables',()=>{const started=performance.now();const parts=integrity(exportBook(fixture,plan(Array.from({length:3000},(_,i)=>visit('v'+i)))),3000);const d=doc(parts,'xl/worksheets/sheet5.xml');assert.equal(all(d,'dimension')[0].getAttribute('ref'),'A1:AD3001');assert.ok(all(d,'dataValidation').every(e=>e.getAttribute('sqref').includes('3001')));assert.equal(cell(d,'F3001').getAttribute('s'),cell(d,'F2').getAttribute('s'));assert.ok(all(d,'conditionalFormatting').some(e=>e.getAttribute('sqref').includes('3001')));console.log('3000-row export/integrity elapsed ms:',Math.round(performance.now()-started));});
test('literal formula injection',()=>{const p=plan([{...visit(),diagnosis:'=HYPERLINK("https://example.invalid","demo")'}]);const parts=unpack(exportBook(fixture,p)),c=cell(doc(parts,'xl/worksheets/sheet5.xml'),'AD2');assert.equal(c.getAttribute('t'),'inlineStr');assert.equal(all(c,'f').length,0);});
test('export read-only deterministic content',()=>{const before=JSON.stringify(one);assert.deepEqual(unzipSync(exportBook(fixture,one)),unzipSync(exportBook(fixture,one)));assert.equal(JSON.stringify(one),before);});
test('block missing delivery',()=>{const p=products[0],v=visit('a',[{...p,id:'i',quantity:1,procedure:'OBSERVACION'}]);assert.throws(()=>exportBook(fixture,plan([v])),/pendientes/);});
test('wrong headers',()=>assert.throws(()=>exportBook(patch('xl/worksheets/sheet5.xml',s=>s.replace('DSUBDIVISION','OTRA')),empty),/encabezados/));
test('wrong sheet order/15 sheets',()=>assert.throws(()=>exportBook(patch('xl/workbook.xml',s=>s.replace('name="CONTEO"','name="EXTRA"')),empty),/DIEZ/));
test('wrong catalog',()=>assert.throws(()=>exportBook(patch('xl/worksheets/sheet1.xml',s=>s.replace(products[0].name,'OTRO PRODUCTO')),empty),/materiales oficiales/));
test('unknown numeric material',()=>assert.throws(()=>exportBook(patch('xl/worksheets/sheet1.xml',s=>s.replace(products[0].code,'99999999')),empty),/materiales oficiales/));
test('duplicate catalog',()=>assert.throws(()=>exportBook(patch('xl/worksheets/sheet1.xml',s=>s.replace(products[0].code,products[1].code)),empty),/432/));
test('malformed XML',()=>assert.throws(()=>exportBook(patch('xl/worksheets/sheet6.xml',()=>'<worksheet><broken>'),empty)));
test('DTD/entity rejection',()=>assert.throws(()=>exportBook(patch('xl/worksheets/sheet6.xml',s=>'<!DOCTYPE worksheet [<!ENTITY x "EXFIL">]>'+s),empty),/entidades/));
test('corrupt zip CRC',()=>{const bad=new Uint8Array(fixture);const view=new DataView(bad.buffer);let end=bad.length-22;const offset=view.getUint32(end+16,true);view.setUint32(offset+16,123,true);assert.throws(()=>exportBook(bad,empty),/CRC|corruptos/);});
test('zip bomb declared size',()=>{const bad=new Uint8Array(fixture);const view=new DataView(bad.buffer),offset=view.getUint32(bad.length-6,true);view.setUint32(offset+24,900_000_000,true);assert.throws(()=>exportBook(bad,empty),/ZIP/);});
test('zip bomb actual expansion',()=>{const parts=unzipSync(fixture);parts['big.xml']=strToU8('x'.repeat(2_000_000));assert.throws(()=>exportBook(zipSync(parts),empty),/ZIP/);});
test('path traversal',()=>{const parts=unzipSync(fixture);parts['../leak.xml']=strToU8('<x/>');assert.throws(()=>exportBook(zipSync(parts),empty),/ZIP/);});
test('oversized and nonzip',()=>{assert.throws(()=>exportBook(new Uint8Array(20_000_001),empty),/20 MB/);assert.throws(()=>exportBook(strToU8('not an xlsx'),empty),/ZIP/);});
test('no input XML content reaches output (10 sheets, caches and properties)',()=>{
 const marker='HISTORICO_FICTICIO_PRIVADO_987654321';const parts=unzipSync(fixture);
 for(let i=1;i<=10;i++){
  const name=`xl/worksheets/sheet${i}.xml`;
  parts[name]=strToU8(strFromU8(parts[name]).replace('</sheetData>',`<row r="9999"><c r="ZZ9999" t="inlineStr"><is><t>${marker}</t></is></c></row></sheetData>`));
 }
 for(const name of ['docProps/core.xml','docProps/custom.xml','xl/comments1.xml','xl/pivotCache/pivotCacheDefinition1.xml','xl/pivotCache/pivotCacheRecords1.xml','customXml/item1.xml','xl/externalLinks/externalLink1.xml'])parts[name]=strToU8(`<private>${marker}</private>`);
 parts['xl/styles.xml']=strToU8(strFromU8(parts['xl/styles.xml']).replace('</styleSheet>',`<extLst><ext>${marker}</ext></extLst></styleSheet>`));
 const output=integrity(exportBook(zipSync(parts),one),1);
 for(const b of Object.values(output))assert.ok(!strFromU8(b).includes(marker));
});
test('table mismatch rejects',()=>assert.throws(()=>exportBook(patch('xl/tables/table3.xml',s=>s.replace('TB_CONSUMOS','UNKNOWN')),empty),/tablas/));
test('plan tampering',()=>{assert.throws(()=>exportBook(fixture,{...one,lines:[one.lines[0],one.lines[0]]}),/duplicadas/);assert.throws(()=>exportBook(fixture,{...one,start:'2026-02-30'}),/Plan/);});
test('verified material R=1 and R=0 in workbook',()=>{
 const {postConfirmedAttentionDelivery}=load('src/attentionKardex.ts');const p=products.find(p=>p.code==='16000013'),a=visit('a',[{...p,id:'i',quantity:1,procedure:'TRATAMIENTO ORAL'}]),b=visit('b',[{...p,id:'j',quantity:1,procedure:'TRATAMIENTO ORAL'}]);const at=Date.parse('2026-10-13T13:25:00Z');
 let ledger={lots:[{id:'lot',code:p.code,name:p.name,catalogUnit:p.unit,lot:'FICTICIO',expires:'2027-12-30',container:'caja',unitsPerContainer:100,sealedContainers:2,looseUnits:0,openedRemaining:0,updatedAt:at-1000}],movements:[]};
 for(const[v,itemId,open,stamp]of [[a,'i',true,at],[b,'j',false,at+1000]])ledger=postConfirmedAttentionDelivery(ledger,v,{itemId,lotId:'lot',physicalQuantity:10,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:open,timestamp:stamp});
 const demo=exportBook(fixture,build([a,b],ledger,'2026-10-13','2026-10-13',options)),parts=integrity(demo,2),d=doc(parts,'xl/worksheets/sheet5.xml');assert.equal(value(cell(d,'R2')),'1');assert.equal(value(cell(d,'R3')),'0');
 if(process.env.AMBULATORY_DEMO_OUTPUT)fs.writeFileSync(process.env.AMBULATORY_DEMO_OUTPUT,demo);
});
test('same worker paracetamol across two visits: R equals actual units',()=>{
 const {postConfirmedAttentionDelivery}=load('src/attentionKardex.ts');
 const p=products.find(p=>p.code==='16000182');
 const a=visit('para-a',[{...p,id:'one',quantity:1,procedure:'TRATAMIENTO ORAL'}]);
 const b=visit('para-b',[{...p,id:'two',quantity:2,procedure:'TRATAMIENTO ORAL'}]);
 const at=Date.parse('2026-10-13T13:25:00Z');
 let ledger={lots:[{id:'lot',code:p.code,name:p.name,catalogUnit:'UND',lot:'DEMO',expires:'2027-12-30',container:'unidad',unitsPerContainer:1,sealedContainers:10,looseUnits:0,openedRemaining:0,updatedAt:at-1000}],movements:[]};
 ledger=postConfirmedAttentionDelivery(ledger,a,{itemId:'one',lotId:'lot',physicalQuantity:1,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:false,timestamp:at});
 ledger=postConfirmedAttentionDelivery(ledger,b,{itemId:'two',lotId:'lot',physicalQuantity:2,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:false,timestamp:at+1000});
 const plan=build([a,b],ledger,'2026-10-13','2026-10-13',options);
 const parts=integrity(exportBook(fixture,plan),2),d=doc(parts,'xl/worksheets/sheet5.xml');
 assert.equal(value(cell(d,'R2')),'1');
 assert.equal(value(cell(d,'R3')),'2');
 assert.equal(value(cell(d,'S3')),'SEGUNDA');
});
test('audited CONTEO INGRESOS RESU preserve original sheet and zero vs blank',()=>{
 const at=Date.parse('2026-10-20T15:00:00Z'),p=products[0],q=products[1],start='2026-10-13',end='2026-10-19';
 let n=0;const event=(kind,code,quantity,extra={})=>({
  id:'v016-'+(++n),kind,subdivision:options.subdivision,code,date:kind==='count'?end:start,
  at:at+n*1000,quantity,reason:'Registro ficticio verificado por responsable',
  document:kind==='receipt'?'ING-001':'',expires:'',periodEnd:kind==='review'?end:'',voidOf:'',...extra
 });
 const events=[
  event('opening',p.code,10),
  event('receipt',p.code,5,{expires:'2027-12-30'}),
  event('count',p.code,13),
  event('opening',q.code,0),
  event('count',q.code,0),
  event('review','',0)
 ];
 const report=plan([visit('example')]);
 report.start=start;report.end=end;
 const material=reconcile(report,events,options.subdivision);
 assert.equal(material.byCode[p.code].closing,15);
 assert.equal(material.byCode[p.code].difference,2);
 assert.equal(material.byCode[q.code].opening,0);
 assert.equal(material.byCode[q.code].closing,0);
 const result=integrity(exportBook(fixture,report,material),1,true);
 const count=doc(result,'xl/worksheets/sheet2.xml'),
  income=doc(result,'xl/worksheets/sheet3.xml'),
  summary=doc(result,'xl/worksheets/sheet4.xml');
 assert.equal(value(cell(count,'D3')),'13');
 assert.equal(value(cell(count,'D4')),'0');
 assert.equal(value(cell(count,'D5')),'','unrecorded counts remain blank');
 assert.equal(value(cell(income,'H3')),'5');
 assert.equal(value(cell(income,'I3')),'46308');
 assert.equal(value(cell(income,'K3')),'ING-001');
 assert.ok(all(cell(income,'X3'),'f')[0].textContent.includes('COUNTA'));
 assert.ok(all(cell(income,'X4'),'f')[0].textContent.includes(',0,SUM('),'explicitly reviewed empty income is numeric zero after Excel recalculation');
 assert.equal(value(cell(summary,'D3')),'10');
 assert.equal(value(cell(summary,'D4')),'0');
 assert.equal(value(cell(summary,'D5')),'');
 assert.equal(value(cell(summary,'M3')),'','reconciliation warnings cannot overwrite manual comment');
 assert.equal(value(cell(summary,'M4')),'','manual comment stays free even when reconciled');
 assert.ok(all(cell(summary,'J3'),'f')[0].textContent.includes('FALTANTE'),'J discrepancy status remains formula-driven');
 assert.ok(all(cell(summary,'L3'),'f')[0].textContent.includes('K3-G3'),'L request remains K projection minus G final stock');
 assert.ok(all(cell(summary,'F3'),'f')[0].textContent.includes('SUMIF'));
});
// Private-input audit is optional locally and never needed by CI or bundled in IPA.
if(process.env.AMBULATORY_PRIVATE_SOURCE)test('actual original source',()=>{const raw=new Uint8Array(fs.readFileSync(process.env.AMBULATORY_PRIVATE_SOURCE));integrity(exportBook(raw,one),1);});
console.log(`PASS: ${passed} workbook/OOXML/privacy/ZIP scenarios; all 10 sheets and 19 tables inspected.`);
