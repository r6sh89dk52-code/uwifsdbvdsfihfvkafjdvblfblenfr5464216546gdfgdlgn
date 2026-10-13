const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {zipSync,unzipSync,strToU8,strFromU8}=require('fflate');
const {load,parse,all,value,visit,options,M}=require('./ambulatory-test-helpers.cjs');
const {exportAmbulatoryWorkbook:exportBook}=load('src/ambulatoryExcel.ts');
const {readAmbulatoryArchive}=load('src/ambulatoryArchive.ts');
const {buildAmbulatoryRows:build}=load('src/ambulatoryRows.ts');
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
function integrity(bytes,rows){
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
 assert.equal(value(cell(doc(parts,'xl/worksheets/sheet4.xml'),'D3')),'');
 assert.equal(value(cell(doc(parts,'xl/worksheets/sheet4.xml'),'M3')),'STOCK INICIAL, INGRESOS Y CONTEO PENDIENTES');
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
 const {postConfirmedAttentionDelivery}=load('src/attentionKardex.ts');const p=products.find(p=>p.code==='16000182'),a=visit('a',[{...p,id:'i',quantity:1,procedure:'TRATAMIENTO ORAL'}]),b=visit('b',[{...p,id:'j',quantity:1,procedure:'TRATAMIENTO ORAL'}]);const at=Date.parse('2026-10-13T13:25:00Z');
 let ledger={lots:[{id:'lot',code:p.code,name:p.name,catalogUnit:p.unit,lot:'FICTICIO',expires:'2027-12-30',container:'frasco',unitsPerContainer:100,sealedContainers:2,looseUnits:0,openedRemaining:0,updatedAt:at-1000}],movements:[]};
 for(const[v,itemId,open,stamp]of [[a,'i',true,at],[b,'j',false,at+1000]])ledger=postConfirmedAttentionDelivery(ledger,v,{itemId,lotId:'lot',physicalQuantity:10,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:open,timestamp:stamp});
 const demo=exportBook(fixture,build([a,b],ledger,'2026-10-13','2026-10-13',options)),parts=integrity(demo,2),d=doc(parts,'xl/worksheets/sheet5.xml');assert.equal(value(cell(d,'R2')),'1');assert.equal(value(cell(d,'R3')),'0');
 if(process.env.AMBULATORY_DEMO_OUTPUT)fs.writeFileSync(process.env.AMBULATORY_DEMO_OUTPUT,demo);
});
// Private-input audit is optional locally and never needed by CI or bundled in IPA.
if(process.env.AMBULATORY_PRIVATE_SOURCE)test('actual original source',()=>{const raw=new Uint8Array(fs.readFileSync(process.env.AMBULATORY_PRIVATE_SOURCE));integrity(exportBook(raw,one),1);});
console.log(`PASS: ${passed} workbook/OOXML/privacy/ZIP scenarios; all 10 sheets and 19 tables inspected.`);
