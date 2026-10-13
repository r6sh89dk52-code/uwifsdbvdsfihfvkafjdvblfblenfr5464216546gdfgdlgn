/** CI gate: fail closed until the reviewed, sanitized nursing source is bundled. */
const fs=require('node:fs'),assert=require('node:assert/strict');
const {unzipSync,strFromU8}=require('fflate');
const {DOMParser}=require('@xmldom/xmldom');
const path='public/internal/kardex-template.bin';
assert.ok(fs.existsSync(path),'PENDIENTE v0.16.3: integrar plantilla binaria sanitizada, no fusionar el PR.');
const source=fs.readFileSync(path);
assert.ok(source.length>8000&&source.length<50000,'Tamaño inesperado del Kardex');
const archive=unzipSync(source),ns='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const xml=name=>new DOMParser().parseFromString(strFromU8(archive[name]),'application/xml');
const workbook=xml('xl/workbook.xml');
const sheets=Array.from(workbook.getElementsByTagNameNS(ns,'sheet')).map(n=>n.getAttribute('name'));
assert.deepEqual(sheets,['KARDEX ENFERMERAS'],'No pueden viajar hojas donadas ni adicionales');
assert.ok(!archive['xl/worksheets/sheet1.xml'],'La plantilla debe excluir donados');
const regular=xml('xl/worksheets/sheet2.xml');
const cells=Array.from(regular.getElementsByTagNameNS(ns,'c'));
const byId=new Map(cells.map(c=>[c.getAttribute('r'),c]));
const all=Array.from({length:98},(_,i)=>'C'+(i+7));
assert.ok(all.every(ref=>byId.has(ref)),'Faltan productos del Kardex');
for(let r=7;r<=104;r++)for(const col of ['D','E','F','G','H','I','J']){
 const c=byId.get(col+r);
 assert.ok(!c||c.getElementsByTagNameNS(ns,'v').length===0,'Saldo histórico no depurado en '+col+r);
}
const allText=Object.values(archive).filter(x=>x.length<100000).map(x=>strFromU8(x)).join('\n');
assert.ok(!/donado|Hoja1|externalLink/i.test(strFromU8(archive['xl/workbook.xml'])));
const setup=regular.getElementsByTagNameNS(ns,'pageSetup')[0];
assert.ok(setup,'Se perdió configuración de impresión');
assert.equal(setup.getAttribute('orientation'),'portrait');
assert.equal(setup.getAttribute('paperSize'),'9');
assert.equal(setup.getAttribute('scale'),'90');
const crypto=require('node:crypto');
const hash=crypto.createHash('sha256').update(source).digest('hex');
assert.equal(hash,'cbad5eaead78da3f3a74a65b2f6297f87f4162f0f571cfff50ce854b1693b5b8');
console.log('PASS: plantilla interna 98 filas, solo Enfermería, sin saldos históricos, A4 90%, SHA256.');
