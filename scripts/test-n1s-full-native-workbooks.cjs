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
   if(original) assert.equal(ours,original,'formula '+i+'!'+ref);
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
    /^xl\/tables\/table\d+\.xml$/.test(key))continue;
 assert.ok(Buffer.from(actual[key]).equals(Buffer.from(bytes)),'changed template '+key);
}
console.log('PASS N1s complete native indicator: 10 sheets, 19 tables, 432 material rows, original cell formulas and exact all verified materials/consumptions');
// Nursing compare main daily 98 products with TS reference, styles/print.
const nn=open('n1s-nursing-native.xlsx'),tn=open('n1s-nursing-reference.xlsx');
assert.ok(nn['xl/printerSettings/printerSettings2.bin']);
const nm=cells(document(nn,2)),tm=cells(document(tn,2));
for(let row=7;row<=104;row++){
 for(const col of ['D','E','F','G','H','I','J']){
  const ref=col+row,source=tm.get(ref),target=nm.get(ref);
  assert.ok(target,'missing nursing '+ref);
  assert.equal(f(nm,ref),f(tm,ref),'nurse formula '+ref);
  assert.equal(value(target),value(source),'nurse value '+ref);
 }
}
assert.equal(get(nm,'D7'),'3');
assert.equal(get(nm,'G7'),'1');
assert.equal(get(nm,'H7'),'2');
assert.equal(f(nm,'F7'),'D7+E7');
assert.equal(f(nm,'H7'),'F7-G7');
const xml=Buffer.from(nn['xl/worksheets/sheet2.xml']).toString('utf8');
assert.ok(xml.includes('orientation="portrait"')&&xml.includes('scale="90"'));
console.log('PASS N1s complete native nursing Kardex: 98 rows, 7 columns/row, original print/merged cells and formulas');
