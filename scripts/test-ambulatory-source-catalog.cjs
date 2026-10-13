// Regression guard: the operational clinic material catalog is exactly the 432
// numeric-code rows from BD MATERIALES in the user's TEN-sheet source XLSX.
// FNV1a hashes are generated from the source sheet with code sorting, ASCII
// newline separators, trimmed names/units. Never add user-created letter codes.
const fs=require('node:fs');
const assert=require('node:assert/strict');
const products=JSON.parse(fs.readFileSync('src/products.json','utf8'));
assert.equal(products.length,432,'BD MATERIALES requires exactly 432 official numeric-code rows');
const codes=new Set();
for(const row of products){
 assert.match(row.code,/^[0-9]+$/,'non-numeric/manual material code '+row.code);
 assert.ok(!codes.has(row.code),'duplicate material code '+row.code);
 assert.equal(typeof row.name,'string');
 assert.ok(row.name.trim().length>0,'missing material name '+row.code);
 assert.equal(typeof row.unit,'string');
 assert.ok(row.unit.trim().length>0,'missing unit '+row.code);
 codes.add(row.code);
}
function fnv(value){
 let hash=2166136261;
 for(const char of value){hash=Math.imul(hash^char.charCodeAt(0),16777619)>>>0}
 return (hash>>>0).toString(16).padStart(8,'0');
}
const sorted=[...products].sort((a,b)=>a.code.localeCompare(b.code));
assert.equal(fnv(sorted.map(p=>p.code).join('\n')),'f6d63606','official codes differ from the ten-sheet source');
assert.equal(fnv(sorted.map(p=>p.code+'|'+p.name.trim()+'|'+p.unit.trim()).join('\n')),'d6cdf096','names/units differ from source');
console.log('PASS: official ten-sheet BD MATERIALES 432 numeric codes, names and units; 5 alphanumeric user codes excluded.');
