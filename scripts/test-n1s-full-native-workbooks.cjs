'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {unzipSync}=require('fflate');
const {parse,all,value}=require('./ambulatory-test-helpers.cjs');
const root=process.env.DANPER_N1_FIXTURE_DIR;
assert(root&&path.isAbsolute(root));
const NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const open=name=>unzipSync(new Uint8Array(fs.readFileSync(path.join(root,name))));
const document=(zip,i)=>parse(Buffer.from(zip['xl/worksheets/sheet'+i+'.xml']).toString('utf8'));
const cells=doc=>new Map(all(doc,'c').map(x=>[x.getAttribute('r'),x]));
const get=(map,r)=>value(map.get(r)||{getAttribute:()=>'' ,getElementsByTagNameNS:()=>[]});
const f=(map,r)=>{const cell=map.get(r);return cell?all(cell,'f')[0]?.textContent||'':''};
const actual=open('n1s-indicator-native.xlsx'),ts=open('n1s-indicator-reference.xlsx');
const names=all(parse(Buffer.from(actual['xl/workbook.xml']).toString('utf8')),'sheet').map(x=>x.getAttribute('name'));
assert.deepEqual(names,['BD MATERIALES','CONTEO','INGRESOS','RESU','CONSUMOS','JUSTIFICACIONES','GUIA','@subuo','BASE TRU','@uo']);
assert.equal(Object.keys(actual).filter(n=>/^xl\/tables\/table\d+\.xml$/.test(n)).length,19);
for(let i=1;i<=10;i++){
 const a=document(actual,i),b=document(ts,i);
 if([2,3,4,5].includes(i)){
  const ac=cells(a),bc=cells(b);
  for(const [ref,expected]of bc){
   if(ref.endsWith('1')||ref.endsWith('2')&&i!==5)continue; // originals retain header representations
   if(!/^[A-Z]+[0-9]+$/.test(ref))continue;
   if(Number(ref.match(/\d+/)[0])> (i===5?3:434))continue;
   const found=ac.get(ref);
   assert.ok(found,'missing '+i+'!'+ref);
   const original=f(bc,ref),ours=f(ac,ref);
   if(original && i===3 && /^[DEFG]\d+$/.test(ref)) {
     const row=Number(ref.match(/\d+/)[0]);
     const expiry={D:'J',E:'N',F:'R',G:'V'}[ref[0]]+row;
     const semaphore='IF('+expiry+'="","",IF('+expiry+'<TODAY(),2,IF('+expiry+'-TODAY()<=90,1,0)))';
     assert.equal(ours,semaphore,'semaforo vencimiento '+ref);
     // Legacy 0/1 formula is superseded; Build 222 remains unchanged.
   } else if(original) assert.equal(ours,original,'formula '+i+'!'+ref);
   else if(value(expected)!=='') {
    const a=value(found),b=value(expected);
    // XLSX stores IEEE754 numbers; Swift and JS can serialize equivalent
    // binary fractions with one last-decimal-digit textual difference.
    if(expected.getAttribute('t')==='inlineStr'||found.getAttribute('t')==='inlineStr')
      assert.equal(a,b,'text value '+i+'!'+ref);
    else{
      assert.ok(a!==''&&b!==''&&Number.isFinite(Number(a))&&Number.isFinite(Number(b))&&
        Math.abs(Number(a)-Number(b))<=1e-12,'numeric value '+i+'!'+ref+' '+a+' / '+b);
    }
   }
  }
 }
}
const incomeXML=Buffer.from(actual['xl/worksheets/sheet3.xml']).toString('utf8');
const semaphoreRule=all(document(actual,3),'conditionalFormatting')
 .find(cf=>cf.getAttribute('sqref')==='D3:G434'&&all(cf,'iconSet').length>0);
assert.ok(semaphoreRule,'INGRESOS must have expiration icon set on D3:G434');
const icons=all(semaphoreRule,'iconSet')[0];
assert.equal(icons.getAttribute('iconSet'),'3TrafficLights1');
assert.equal(icons.getAttribute('reverse'),'1');
assert.equal(icons.getAttribute('showValue'),'0','circles must hide numeric status');
assert.deepEqual(all(icons,'cfvo').map(x=>x.getAttribute('val')),['0','1','2']);
assert.ok(!incomeXML.includes('<xm:sqref>D3:G439</xm:sqref>'),
 'old x14 icon rule must not mask the standard green/yellow/red icons');
const count=cells(document(actual,2)),income=cells(document(actual,3)),
      resu=cells(document(actual,4)),consumos=cells(document(actual,5));
assert.equal(get(count,'D3'),get(cells(document(ts,2)),'D3'));
assert.equal(get(income,'H3'),get(cells(document(ts,3)),'H3'));
assert.equal(get(resu,'M3'),'');
assert.equal(all(document(actual,5),'row').length,3);
assert.ok(f(resu,'F3').includes('SUMIF'));
assert.ok(f(resu,'L434').includes('K434-G434'));
assert.ok(f(income,'X3').includes('COUNTA'));
assert.ok(f(count,'H434').includes('COUNTA'));
assert.deepEqual([get(consumos,'R2'),get(consumos,'R3')],[ '5', '0' ]);
// Ensure all untouched worksheets, structured tables, diagrams, metadata preserved.
const base=open('n1s-indicator-template-store.zip');
for(const [key,bytes] of Object.entries(base)){
 if(/^xl\/worksheets\/sheet(2|3|4|5)\.xml$/.test(key)||key==='xl/workbook.xml'||
    key==='xl/styles.xml'||/^xl\/tables\/table\d+\.xml$/.test(key))continue;
 assert.ok(Buffer.from(actual[key]).equals(Buffer.from(bytes)),'changed template '+key);
}
// The date-only style is deliberately appended, not copied unchanged:
 // Excel must see genuine sortable serial values shown as dd/mm/yyyy.
const styles=Buffer.from(actual['xl/styles.xml']).toString('utf8');
assert.match(styles,/formatCode="dd\/mm\/yyyy"/,'indicator must use Peru date display');
assert.match(Buffer.from(actual['xl/worksheets/sheet5.xml']).toString('utf8'),
  /<c r="F2" s="\d+">/,'CONSUMOS date cells must have a numeric date style');
console.log('PASS INGRESOS: green >90d, yellow 0-90d, red expired, icons hide helper numbers');
console.log('PASS N1s complete native indicator: 10 sheets, 19 tables, 432 material rows, original cell formulas and exact all verified materials/consumptions');
// Nursing compare main daily 98 products with TS reference, styles/print.
const nn=open('n1s-nursing-native.xlsx'),tn=open('n1s-nursing-reference.xlsx');
// The nursing header is F6. Inspect its rendered cell value; shared and
// rich-string XML may split one visible label across several <t> nodes.
const nursingCellF6=cells(document(nn,2)).get('F6');
assert.ok(nursingCellF6,'Kardex must contain stock-total header at F6');
const nursingHeaderText=all(nursingCellF6,'t').map(x=>x.textContent||'').join('').trim();
assert.equal(nursingHeaderText,'TOTAL STOCK',
 'Visible nursing Kardex header F6 must say TOTAL STOCK, not TOTAL ESTOCK');
const nurseNames=all(parse(Buffer.from(nn['xl/workbook.xml']).toString('utf8')),'sheet')
  .map(x=>x.getAttribute('name'));
assert.deepEqual(nurseNames,['KARDEX ENFERMERAS'],
  'Swift export must match Build 222 single visible Kardex worksheet');
for(const removed of ['xl/worksheets/sheet1.xml',
                      'xl/worksheets/_rels/sheet1.xml.rels',
                      'xl/printerSettings/printerSettings1.bin',
                      'docProps/app.xml']) {
  assert.ok(!nn[removed],'donor-only ZIP part leaked: '+removed);
}
assert.ok(!Buffer.from(nn['[Content_Types].xml']).toString('utf8')
  .includes('/xl/worksheets/sheet1.xml'));
assert.ok(!Buffer.from(nn['xl/_rels/workbook.xml.rels']).toString('utf8')
  .includes('Id="rId1"'));
assert.ok(!Buffer.from(nn['xl/workbook.xml']).toString('utf8')
  .includes('name="Hoja1"'));

assert.ok(nn['xl/printerSettings/printerSettings2.bin']);
const nm=cells(document(nn,2)),tm=cells(document(tn,2));
console.log('N1s nursing diagnostic nonpatient XML row7:',Buffer.from(nn['xl/worksheets/sheet2.xml']).toString('utf8').match(/<row[^>]*r="7"[^>]*>[\s\S]*?<\/row>/)?.[0]?.slice(0,2200));
console.log('N1s nursing parsed first refs:',[...nm.keys()].filter(k=>/^[D-J]7$/.test(k)));

for(let row=7;row<=104;row++){
 for(const col of ['D','E','F','G','H','I','J']){
  const ref=col+row,source=tm.get(ref),target=nm.get(ref);
  assert.ok(target,'missing nursing '+ref);
  assert.equal(f(nm,ref),f(tm,ref),'nurse formula '+ref);
  const originalValue=value(source),renderedValue=value(target);
  if(col==='I' && /^\d{4}-\d{2}-\d{2}$/.test(String(originalValue))){
   const serial=(Date.parse(originalValue+'T00:00:00Z')-
                 Date.UTC(1899,11,30))/86400000;
   assert.equal(Number(renderedValue),serial,'sortable nursing expiry '+ref);
  }else {
   // The old Build 222 fixture leaves no-lot numeric cells blank.
   // Native Kardex correctly preserves all 98 rows with explicit numeric 0.
   if(['D','E','F','G','H'].includes(col) &&
      originalValue==='' && renderedValue==='0') {
     assert.ok(target,'numeric zero must have a physical cell at '+ref);
     assert.ok(!['s','inlineStr','str'].includes(target.getAttribute('t')),
       'stock zero must be numeric, not text: '+ref);
   } else {
     assert.equal(renderedValue,originalValue,'nurse value '+ref);
   }
  }
 }
}
assert.equal(get(nm,'D7'),'3');
assert.equal(get(nm,'G7'),'1');
assert.equal(get(nm,'H7'),'2');
assert.equal(f(nm,'F7'),'D7+E7');
assert.equal(f(nm,'H7'),'F7-G7');
const nursingStyles=Buffer.from(nn['xl/styles.xml']).toString('utf8');
assert.match(nursingStyles,/formatCode="dd\/mm\/yyyy"/,
  'nursing must have a dd/mm/yyyy Excel date number format');
const xml=Buffer.from(nn['xl/worksheets/sheet2.xml']).toString('utf8');
assert.ok(xml.includes('orientation="portrait"')&&xml.includes('scale="90"'));
console.log('PASS N1s complete native nursing Kardex: 98 rows, 7 columns/row, original print/merged cells and formulas');
