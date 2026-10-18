'use strict';
/** Extract only organizational names/codes from the embedded official source.
 * Never copies employee rows or patient records into the native test bundle. */
const {unzipSync}=require('fflate');
const assert=require('node:assert/strict');
const base64=require('../src/ambulatoryTemplate.json').zipBase64;
const workbook=unzipSync(new Uint8Array(Buffer.from(base64,'base64')));

function read(filename) {
 const raw=workbook[filename];
 assert(raw,'Missing official sheet: '+filename);
 return Buffer.from(raw).toString('utf8');
}
function decode(s) {
 return (s||'').replace(/&(#(?:x[0-9a-fA-F]+|\d+)|amp|quot|apos|lt|gt);/g,(_,entity)=>{
  if(entity.startsWith('#')) {
   const n=entity[1].toLowerCase()==='x'?
    parseInt(entity.slice(2),16):parseInt(entity.slice(1),10);
   return String.fromCodePoint(n);
  }
  return {amp:'&',quot:'"',apos:"'",lt:'<',gt:'>'}[entity]||'';
 });
}
function attr(raw,key) {
 const match=new RegExp('(?:^|\\s)'+key+'="([^"]*)"').exec(raw);
 return match ? decode(match[1]) : '';
}
function inline(raw) {
 return Array.from(raw.matchAll(/<t(?:\s[^>]*)?>([\s\S]*?)<\/t>/g),
        m=>decode(m[1])).join('');
}
const shared=Array.from(read('xl/sharedStrings.xml')
   .matchAll(/<si(?:\s[^>]*)?>([\s\S]*?)<\/si>/g),
   m=>inline(m[1]));
function rows(filename) {
 return Array.from(read(filename).matchAll(/<row\b[^>]*>([\s\S]*?)<\/row>/g),m=>{
  const result={};
  for(const cell of m[1].matchAll(/<c\b([^>]*?)(?:\/>|>([\s\S]*?)<\/c>)/g)) {
   const col=/^[A-Z]+/.exec(attr(cell[1],'r'))?.[0];
   if(!col)continue;
   const type=attr(cell[1],'t');
   const contents=cell[2]||'';
   const v=/<v(?:\s[^>]*)?>([\s\S]*?)<\/v>/.exec(contents)?.[1]||'';
   result[col]=type==='s'?(shared[Number(v)]||''):
     type==='inlineStr'?inline(contents):decode(v);
  }
  return result;
 });
}
const sub=rows('xl/worksheets/sheet8.xml');
const org=rows('xl/worksheets/sheet10.xml');
const sites=[{id:'LA VENTUROSA',code:'A071'},
             {id:'PLVENTUROSA',code:'I031'}];
const normalize=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'')
  .trim().replace(/\s+/g,' ').toUpperCase();
const result=[];
for(const site of sites) {
 const related=sub.filter(r=>r.A===site.id&&r.B===site.code);
 assert(related.length===1 && /^\d{4}$/.test(related[0].C||''),
        'Unverified subdivision in official XLSX: '+site.id);
 const society=related[0].C, seen=new Set();
 for(const row of org.filter(r=>r.A===society&&r.C&&/^\d{8}$/.test(r.E||''))) {
  const name=row.C.trim(),key=normalize(name);
  assert(!seen.has(key),'Duplicate official area '+name);
  seen.add(key);
  result.push({site:site.id,area:name,code:row.E});
 }
 assert(seen.size>0,'No official areas for site '+site.id);
}
assert(result.every(a=>/^\d{8}$/.test(a.code)));
module.exports={result};
if(require.main===module)console.log(JSON.stringify({count:result.length,perSite:sites.map(s=>({site:s.id,count:result.filter(a=>a.site===s.id).length}))}));
