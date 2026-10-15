const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const ts=require('typescript');
const {zipSync,unzipSync,strToU8,strFromU8}=require('fflate');
const {DOMParser}=require('@xmldom/xmldom');
function js(path,requireModule,globals={}){
 const code=ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const m={exports:{}};
 vm.runInNewContext(code,{module:m,exports:m.exports,require:requireModule,...globals},{filename:path});
 return m.exports;
}
const workers=js('src/workerRules.ts',name=>{throw Error(name)});
const NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const REL='http://schemas.openxmlformats.org/officeDocument/2006/relationships';
function cell(address,value){return '<x:c r="'+address+'" t="inlineStr"><x:is><x:t>'+value+'</x:t></x:is></x:c>'}
function makeWorkbook(entries,withBom){
 const header=['DNI','NOMBRES','EDAD MANUAL','SEXO','UBIGEO','AREA','CARGO'];
 const rows=[header,...entries].map((cols,index)=>'<x:row r="'+(index+1)+'">'+cols.map((value,k)=>cell(String.fromCharCode(65+k)+(index+1),String(value))).join('')+'</x:row>').join('');
 const wb='<?xml version="1.0" encoding="utf-8"?><x:workbook xmlns:x="'+NS+'" xmlns:r="'+REL+'"><x:sheets><x:sheet name="PERSONAL" sheetId="1" r:id="rId1"/></x:sheets></x:workbook>';
 const rel='<?xml version="1.0" encoding="utf-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="/xl/worksheets/sheet1.xml"/></Relationships>';
 const sheet='<?xml version="1.0" encoding="utf-8"?><x:worksheet xmlns:x="'+NS+'"><x:sheetData>'+rows+'</x:sheetData></x:worksheet>';
 const zip=zipSync({'xl/workbook.xml':strToU8(wb),'xl/_rels/workbook.xml.rels':strToU8((withBom?'\uFEFF':'')+rel),'xl/worksheets/sheet1.xml':strToU8(sheet)}, {level:6});
 return {name:'PERSONAL_FICTICIOS.xlsx',size:zip.length,arrayBuffer:async()=>zip.buffer.slice(zip.byteOffset,zip.byteOffset+zip.byteLength)};
}
const window={JSZip:{async loadAsync(bytes){
 const zip=unzipSync(bytes);const files={};for(const key of Object.keys(zip))files[key]={_data:{uncompressedSize:zip[key].length}};
 return{files,file(name){if(!zip[name])return null;return {async(format){assert.equal(format,'string');return strFromU8(zip[name])}}}};
}}};
class IosDOMParser extends DOMParser{
 parseFromString(src,type){
  // Safari-like BOM as a leading code point in a JavaScript string.
  if(src.startsWith('\uFEFF<?xml'))return super.parseFromString('<parsererror>leading BOM before XML declaration</parsererror>',type);
  return super.parseFromString(src,type);
 }
}
const workbook=js('src/workbookPersonal.ts',name=>{if(name==='./workerRules')return workers;throw Error(name)}, {window,DOMParser:IosDOMParser,Uint8Array,Array,Error,Number,String,Promise});
(async()=>{
 const persons=[['00001234','PERSONA FICTICIA UNO','28','F','','FUNDO','AUXILIAR'],['00005678','PERSONA FICTICIA DOS','31','M','','PACKING','OPERARIO'],['00005678','PERSONA FICTICIA DOS','','M','','PACKING','OPERARIO']];
 const first=await workbook.readPersonal(makeWorkbook(persons,true));
 assert.equal(first.stats.valid,2);
 assert.equal(first.stats.duplicates,1);
 assert.equal(first.workers[0].dni,'00001234');
 const importAgain=workers.reconcileWorkers(first.workers,first.workers);
 assert.equal(importAgain.stats.added,0);
 assert.equal(importAgain.stats.merged,2);
 assert.equal(importAgain.workers.length,2);
 const change=await workbook.readPersonal(makeWorkbook([['00001234','PERSONA FICTICIA UNO','29','M','','FUNDO','ENFERMERIA'],['00009999','PERSONA FICTICIA NUEVA','24','F','','CAMPAMENTO','OPERARIO']],true));
 const merged=workers.reconcileWorkers(first.workers,change.workers);
 assert.equal(merged.stats.added,1);
 assert.equal(merged.stats.merged,1);
 assert.equal(merged.stats.sexConflicts,1);
 assert.equal(merged.workers.find(x=>x.dni==='00001234').sex,'F','contradictory sex never overwrites');
 assert.equal(merged.workers.find(x=>x.dni==='00001234').labor,'ENFERMERIA','non-conflicting labor updated');
 const repeated=workers.reconcileWorkers(merged.workers,change.workers);
 assert.equal(repeated.stats.added,0);
 assert.equal(repeated.workers.length,3);
 assert.equal(repeated.stats.sexConflicts,1,'contradictory incoming sex stays under review');
 const older=workers.reconcileWorkers(merged.workers,[{...merged.workers[0],name:'PERSONA DIFERENTE',source:'imported'}]);
 assert.equal(older.stats.nameConflicts,1);
 assert.equal(older.workers.find(x=>x.dni==='00001234').name,'PERSONA FICTICIA UNO');
 const noBom=await workbook.readPersonal(makeWorkbook(persons,false));
 assert.equal(noBom.stats.valid,2);
 const manual={...first.workers[0],area:'CORREGIDO POR USUARIO',source:'manual'};
 const preserve=workers.reconcileWorkers([manual],change.workers);
 assert.equal(preserve.workers.find(x=>x.dni==='00001234').area,'CORREGIDO POR USUARIO');
 assert.equal(preserve.stats.manualPreserved,1);
 console.log('PASS: BOM XML in iPhone, synthetic PERSONAL Excel, repeating Excel, mixed old/new DNI, duplicate-free merge, manual priority and sex/name conflicts.');
})().catch(e=>{console.error(e);process.exitCode=1});
