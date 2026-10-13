const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const ts=require('typescript');
function loadTs(file,dependencies={}){
 const src=fs.readFileSync(file,'utf8');
 const compiled=ts.transpileModule(src,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},reportDiagnostics:true});
 assert.equal(compiled.diagnostics.filter(x=>x.category===ts.DiagnosticCategory.Error).length,0,'Syntax error in '+file);
 const exports={};
 vm.runInNewContext(compiled.outputText,{exports,require(name){if(dependencies[name])return dependencies[name];throw Error('Unexpected dependency '+name)},Date,Number,Math,Set,JSON,Error,Array}, {filename:file});
 return exports;
}
const inventory=loadTs('src/inventoryRules.ts');
const rules=loadTs('src/kardexMovements.ts',{'./inventoryRules':inventory});
function sample(id='lot-1',code='E-87',expiration='2030-12-31'){
 return inventory.validateStockLot({
  id,code,name:'ALCOHOL 120 ML',catalogUnit:'mL',lot:'FAKE-001',expires:expiration,container:'frasco',
  unitsPerContainer:120,sealedContainers:2,looseUnits:0,openedRemaining:0,updatedAt:Date.now()
 });
}
const time=Date.parse('2026-10-13T15:00:00Z');
const start={lots:[sample()],movements:[]};
function cmd(id,kind,changes={}){return {id,kind,lotId:'lot-1',at:time+Number(id.replace(/\D/g,''))*60000||time,description:'Movimiento ficticio',...changes}}
assert.equal(rules.suggestFEFOLot([sample('old','E-87','2027-01-01'),sample('new','E-87','2027-07-01')],'E-87',time).id,'old','FEFO earliest');
assert.equal(rules.suggestFEFOLot([sample('expired','E-87','2020-01-01'),sample('valid','E-87','2027-07-01')],'E-87',time).id,'valid','FEFO skips expired');
assert.throws(()=>rules.postStockMovement(start,cmd('m1','use',{quantity:15})),/Confirma la apertura/,'must confirm opening');
let x=rules.postStockMovement(start,cmd('m1','use',{quantity:15,allowOpen:true}));
assert.equal(x.lots[0].sealedContainers,1);
assert.equal(x.lots[0].openedRemaining,105);
assert.equal(inventory.countPhysicalUnits(x.lots[0]),225);
assert.equal(x.movements[0].excelQuantity,1,'Excel R first opening = 1');
assert.equal(x.movements[0].openedNewContainer,true);
assert.equal(x.movements[0].physicalChange,-15);
assert.equal(rules.postStockMovement(x,cmd('m1','use',{quantity:15,allowOpen:true})).movements.length,1,'idempotent repeat');
assert.throws(()=>rules.postStockMovement(x,cmd('m1','use',{quantity:7,allowOpen:true})),/reutilizado/,'conflicting duplicate');
x=rules.postStockMovement(x,cmd('m2','use',{quantity:5}));
assert.equal(x.lots[0].openedRemaining,100);
assert.equal(x.movements[1].excelQuantity,0,'Later use of open bottle = 0');
assert.equal(inventory.countPhysicalUnits(x.lots[0]),220);
assert.throws(()=>rules.postStockMovement(x,cmd('m3','use',{quantity:101,allowOpen:true})),/envase abierto no alcanza/,'do not cross an opening in one movement');
x=rules.postStockMovement(x,cmd('m3','use',{quantity:100}));
assert.equal(x.lots[0].openedRemaining,0);
assert.equal(x.lots[0].sealedContainers,1);
assert.equal(x.movements[2].excelQuantity,0);
x=rules.postStockMovement(x,cmd('m4','use',{quantity:12,allowOpen:true}));
assert.equal(x.lots[0].openedRemaining,108);
assert.equal(x.lots[0].sealedContainers,0);
assert.equal(x.movements[3].excelQuantity,1,'Opening second container = 1');
assert.throws(()=>rules.postStockMovement(x,cmd('m5','use',{quantity:109})),/no alcanza/,'stock cannot go negative');
x=rules.postStockMovement(x,cmd('m5','extraordinary',{sealedAdded:2,looseAdded:10}));
assert.equal(x.lots[0].sealedContainers,2);
assert.equal(x.lots[0].looseUnits,10);
assert.equal(x.movements[4].physicalChange,250);
assert.equal(x.movements[4].excelQuantity,0);
x=rules.postStockMovement(x,cmd('m6','adjustment',{newSealed:1,newLoose:9,newOpened:107}));
assert.equal(x.movements[5].kind,'adjustment');
assert.equal(x.movements[5].physicalChange,-122);
assert.equal(x.lots[0].looseUnits,9);
assert.equal(rules.validateStockMovements(x.movements).length,6);
assert.throws(()=>rules.validateStockMovements([...x.movements,x.movements[5]]),/duplicado/);
assert.throws(()=>rules.postStockMovement(x,cmd('m7','extraordinary',{sealedAdded:0,looseAdded:0})),/al menos/);
assert.throws(()=>rules.postStockMovement(x,cmd('m8','adjustment',{newSealed:1,newLoose:9,newOpened:107})),/No existen diferencias/);
assert.throws(()=>rules.postStockMovement({lots:[sample('lot-1','E-87','2020-01-01')],movements:[]},cmd('m9','use',{quantity:1,allowOpen:true})),/vencido/);
const unit={...sample(),container:'unidad',unitsPerContainer:1,catalogUnit:'UND',sealedContainers:3};
const units=rules.postStockMovement({lots:[unit],movements:[]},cmd('m10','use',{quantity:2}));
assert.equal(units.lots[0].sealedContainers,1);
assert.equal(units.movements[0].excelQuantity,2,'Unit-counted 2 physical units = 2 Excel units');
console.log('PASS: 0/1 apertura, envases múltiples, uso sucesivo, ingresos, ajustes, FEFO, vencimiento, auditoría e idempotencia');
