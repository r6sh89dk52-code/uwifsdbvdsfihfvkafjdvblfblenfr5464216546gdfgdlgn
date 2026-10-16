'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
const {unzipSync}=require('fflate');
const {parse,all,value}=require('./ambulatory-test-helpers.cjs');
const official=require('../src/ambulatoryTemplate.json');
const dir=process.env.DANPER_N1_FIXTURE_DIR;
assert(dir&&path.isAbsolute(dir));
const original=unzipSync(new Uint8Array(fs.readFileSync(path.join(dir,'n1r-sanitized-template-store.zip'))));
const doc=(parts,name)=>parse(Buffer.from(parts[name]).toString('utf8'));
const ref=(n,i)=>{let s='';for(let j=i+1;j;j=Math.floor((j-1)/26))s=String.fromCharCode(65+(j-1)%26)+s;return s+n;};
for(const id of ['stock','frequency']){
 const expected=JSON.parse(fs.readFileSync(path.join(dir,'n1p-'+id+'-expected.json'),'utf8')).plan.lines;
 const parts=unzipSync(new Uint8Array(fs.readFileSync(path.join(dir,'n1r-'+id+'-native.xlsx'))));
 assert.deepEqual(all(doc(parts,'xl/workbook.xml'),'sheet').map(s=>s.getAttribute('name')),official.sheets);
 assert.equal(Object.keys(parts).filter(x=>/^xl\/tables\/table\d+\.xml$/.test(x)).length,19);
 const different=Object.entries(original).filter(([name,content])=>{
  assert.ok(parts[name],'missing '+name);
  return !Buffer.from(content).equals(Buffer.from(parts[name]));
 }).map(([name])=>name);
 assert.equal(different.length,2);
 assert.ok(different.includes('xl/worksheets/sheet5.xml'));
 const tableName=different.find(n=>/^xl\/tables\/table\d+\.xml$/.test(n));
 assert.ok(tableName);
 const last=Math.max(2,expected.length+1);
 assert.equal(doc(parts,tableName).documentElement.getAttribute('ref'),'A1:AD'+last);
 const sheet=doc(parts,'xl/worksheets/sheet5.xml');
 assert.equal(all(sheet,'dimension')[0].getAttribute('ref'),'A1:AD'+last);
 assert.equal(all(sheet,'row').length,last);
 assert.deepEqual(all(all(sheet,'row')[0],'c').map(value),official.headers);
 const cells=new Map(all(sheet,'c').map(c=>[c.getAttribute('r'),c]));
 for(let row=0;row<expected.length;row++){
  const given=expected[row].cells;
  for(let column=0;column<30;column++){
   const key=ref(row+2,column),actual=cells.get(key);
   assert.ok(actual,'Missing '+key);
   if(column===2||column===3){
    assert.ok(all(actual,'f')[0].textContent.includes('VLOOKUP'));
    continue;
   }
   const got=value(actual),want=given[column];
   if(typeof want==='number')assert.ok(Math.abs(Number(got)-want)<1e-9,'Mismatch '+key+' '+got+' / '+want);
   else {
    assert.equal(got,want,'Mismatch '+key);
    if(want!==''&&[7,15,27].includes(column))assert.equal(actual.getAttribute('t'),'inlineStr');
    if(want.startsWith('=')||want.startsWith('+'))assert.equal(all(actual,'f').length,0);
   }
  }
 }
 assert.equal(all(doc(parts,'xl/worksheets/sheet1.xml'),'row').length,433);
 console.log('PASS N1r Swift XLSX '+id+': '+expected.length+' rows, typed A–AD, 10 sheets, 19 tables, 432 materials, other parts unchanged.');
}
