const assert=require('node:assert/strict');const fs=require('fs');const vm=require('node:vm');const ts=require('typescript');
function compile(path,imports={}){
 const code=fs.readFileSync(path,'utf8');
 const result=ts.transpileModule(code,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.React},reportDiagnostics:true});
 assert.equal(result.diagnostics.filter(x=>x.category===ts.DiagnosticCategory.Error).length,0,'Syntax '+path);
 const exports={};vm.runInNewContext(result.outputText,{exports,require:(name)=>{if(imports[name])return imports[name];throw Error(name)},Date,Number,Set,Math,JSON,Error});
 return exports;
}
const catalog=compile('src/kardexCatalog.ts');
const rules=compile('src/inventoryRules.ts');
assert.equal(catalog.kardexCatalog.length,98,'98 general only from source workbook');
assert.equal(catalog.kardexCatalog.filter(p=>!p.donated).length,98);
assert.equal(catalog.kardexCatalog.filter(p=>p.donated).length,0);
assert.equal(catalog.kardexCatalog[0].name,'AERO-OM GRAGEAS');
assert.equal(catalog.kardexCatalog[97].name,'REPELENTE');
assert.equal(catalog.legacyDonatedCatalog.length,6,'historical donor names kept only for legacy read compatibility');
const l={id:'demo-1',code:'E-87',name:'ALCOHOL 120 ML',catalogUnit:'mL',lot:'FICTICIO-2026',expires:'2027-01-31',container:'frasco',unitsPerContainer:120,sealedContainers:2,looseUnits:0,openedRemaining:60,updatedAt:Date.now()};
const saved=rules.validateStockLot(l);
assert.equal(saved.updatedAt,l.updatedAt,'Date.now() must be valid, not treated as stock');
assert.equal(rules.validateStockLot({...l,updatedAt:0}).updatedAt,0,'Unix epoch valid');
assert.throws(()=>rules.validateStockLot({...l,updatedAt:-1}),/Fecha de modificación/);
assert.throws(()=>rules.validateStockLot({...l,updatedAt:12.5}),/Fecha de modificación/);
assert.throws(()=>rules.validateStockLot({...l,updatedAt:Number.POSITIVE_INFINITY}),/Fecha de modificación/);
assert.throws(()=>rules.validateStockLot({...l,updatedAt:Number.MAX_SAFE_INTEGER+1}),/Fecha de modificación/);

assert.equal(rules.countPhysicalUnits(saved),300);
assert.equal(rules.countPhysicalUnits({...saved,sealedContainers:0,openedRemaining:0}),0);
assert.equal(rules.countPhysicalUnits({...saved,sealedContainers:1,looseUnits:2.5,openedRemaining:60}),182.5);
assert.throws(()=>rules.validateStockLot({...l,unitsPerContainer:0}),/capacidad/);
assert.throws(()=>rules.validateStockLot({...l,openedRemaining:121}),/contenido abierto/);
assert.throws(()=>rules.validateStockLot({...l,sealedContainers:1.5}),/envases cerrados/);
assert.throws(()=>rules.validateStockLot({...l,expires:'ayer'}),/vencimiento/);
assert.throws(()=>rules.validateStockLot({...l,looseUnits:-5}),/unidades sueltas/);
assert.throws(()=>rules.validateStockLots([l,{...l}]),/duplicado/);
assert.equal(rules.inventoryTotals([l]).products,1);
assert.equal(rules.inventoryTotals([l]).lots,1);
assert.equal(rules.inventoryTotals([l]).opened,1);
console.log('PASS: 98 productos Kardex exclusivamente; stock físico sin doble conteo; lotes, capacidades y vencimiento');
