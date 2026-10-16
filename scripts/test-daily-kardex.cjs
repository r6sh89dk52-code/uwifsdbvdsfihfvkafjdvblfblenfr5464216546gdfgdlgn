const assert=require('node:assert/strict'),fs=require('fs'),vm=require('vm'),ts=require('typescript');
function load(path,deps={}){
 const compiled=ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},reportDiagnostics:true});
 assert.equal(compiled.diagnostics.filter(x=>x.category===ts.DiagnosticCategory.Error).length,0,'transpilation '+path);
 const exports={};vm.runInNewContext(compiled.outputText,{exports,require(name){if(name in deps)return deps[name];throw Error(name)},Date,Intl,Math,Number,Set,Map,JSON,Error,Array}, {filename:path});return exports;
}
const catalog=load('src/kardexCatalog.ts'),inventory=load('src/inventoryRules.ts'),ledgerRules=load('src/kardexMovements.ts',{'./inventoryRules':inventory});
const daily=load('src/dailyKardex.ts',{'./kardexCatalog':catalog,'./kardexMovements':ledgerRules,'./inventoryRules':inventory});
const at=Date.parse('2026-10-14T04:40:00Z'); // Oct 13, 23:40 in Peru
// Synthetic package scenario: official unit FCO, not UND; otherwise 120 units must be counted individually.
const base={id:'lot-A',code:'E-1',name:catalog.kardexCatalog[0].name,catalogUnit:'FCO',lot:'FICTICIO',expires:'2027-12-30',container:'frasco',unitsPerContainer:120,sealedContainers:2,looseUnits:0,openedRemaining:0,updatedAt:at-90000};
let state={lots:[inventory.validateStockLot(base)],movements:[]};
const move=(id,kind,atTime,more)=>({id,kind,lotId:'lot-A',description:'Demostración del reporte',at:atTime,...more});
state=ledgerRules.postStockMovement(state,move('opening','use',at,{quantity:10,allowOpen:true}));
state=ledgerRules.postStockMovement(state,move('continued','use',at+1000,{quantity:5}));
const day=daily.buildDailyReport(state,'2026-10-13');
const row=day.rows.find(x=>x.code==='E-1');
assert.equal(day.rows.length,98);
assert.equal(day.rows.every(x=>!x.donated),true);
assert.equal(day.rows.filter(x=>!x.donated).length,98);
assert.equal(row.initial,2,'D initial 2 closed containers');
assert.equal(row.extraordinary,0);
assert.equal(row.total,2);
assert.equal(row.consumed,1,'G opened only once');
assert.equal(row.final,1,'H remaining sealed');
assert.equal(day.exportable,true,day.warnings.join(';'));
const counted=daily.buildDailyReport(state,'2026-10-13',{'E-1':2}).rows[0];
assert.equal(counted.fs,1,'F/S physical count minus report balance');
const next=daily.buildDailyReport(state,'2026-10-14').rows[0];
assert.equal(next.initial,1);
assert.equal(next.consumed,0);
const missing=daily.buildDailyReport({lots:[],movements:[]},'2026-10-13');
assert.equal(missing.rows.length,98);
assert.equal(missing.rows.every(x=>x.stockKnown===false),true,'missing stock must not be exported as zero');
assert.throws(()=>daily.buildDailyReport(state,'fecha equivocada'),/inválida/);
console.log('PASS: 98 official products (donors excluded), A4 reporting formula values, Peru day boundaries, pack openings 1/0, F/S only when counted, donation alert');
