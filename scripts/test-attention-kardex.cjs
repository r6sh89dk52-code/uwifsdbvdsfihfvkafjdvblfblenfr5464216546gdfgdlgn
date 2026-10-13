const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');
function load(file,deps={}){
 const src=fs.readFileSync(file,'utf8');
 const c=ts.transpileModule(src,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},reportDiagnostics:true});
 assert.equal(c.diagnostics.filter(x=>x.category===ts.DiagnosticCategory.Error).length,0,'transpile '+file);
 const exports={};vm.runInNewContext(c.outputText,{exports,require(name){if(Object.prototype.hasOwnProperty.call(deps,name))return deps[name];throw Error(name)},Date,Math,Number,Set,Map,JSON,Error,Array},{filename:file});return exports;
}
const inv=load('src/inventoryRules.ts');
const ledgerRules=load('src/kardexMovements.ts',{'./inventoryRules':inv});
const delivery=load('src/attentionKardex.ts',{'./inventoryRules':inv,'./kardexMovements':ledgerRules});
const at=Date.parse('2026-10-13T18:00:00Z');
const makeLot=(id,expires='2027-10-13')=>inv.validateStockLot({
 id,code:'E-87',name:'ALCOHOL 120 ML',catalogUnit:'mL',lot:id,expires,container:'frasco',
 unitsPerContainer:120,sealedContainers:2,looseUnits:0,openedRemaining:0,updatedAt:at
});
const attention={id:'enc-1',status:'saved',items:[{id:'med-1',code:'16000025',name:'ALCOHOL MEDICO 96° X 120 ML',quantity:1,unit:'FCO'}]};
const confirm={itemId:'med-1',lotId:'lot-1',physicalQuantity:10,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:true,timestamp:at};
const seed={lots:[makeLot('lot-1'),makeLot('lot-2','2026-01-01')],movements:[]};
assert.equal(delivery.availableLots(seed.lots,'E-87',at).length,1);
assert.throws(()=>delivery.postConfirmedAttentionDelivery(seed,{...attention,status:'draft'},confirm),/guardada/);
assert.throws(()=>delivery.postConfirmedAttentionDelivery(seed,attention,{...confirm,confirmIdentity:false}),/Confirma/);
assert.throws(()=>delivery.postConfirmedAttentionDelivery(seed,attention,{...confirm,lotId:'lot-2'}),/vencido/);
assert.throws(()=>delivery.postConfirmedAttentionDelivery(seed,attention,{...confirm,physicalQuantity:150}),/capacidad/);
const first=delivery.postConfirmedAttentionDelivery(seed,attention,confirm);
assert.equal(first.lots[0].openedRemaining,110);
assert.equal(first.movements[0].excelQuantity,1);
assert.equal(first.movements[0].dispenseRef.attentionId,'enc-1');
assert.equal(first.movements[0].dispenseRef.itemId,'med-1');
assert.equal(first.movements[0].dispenseRef.clinicalCode,'16000025');
assert.equal(delivery.alreadyDispensed(first,'enc-1','med-1'),true);
assert.throws(()=>delivery.postConfirmedAttentionDelivery(first,attention,confirm),/ya tiene una entrega/);
const newAtt={id:'enc-2',status:'saved',items:[{...attention.items[0],id:'med-2'}]};
const second=delivery.postConfirmedAttentionDelivery(first,newAtt,{...confirm,itemId:'med-2',physicalQuantity:5,openNewContainer:false,timestamp:at+1000});
assert.equal(second.lots[0].openedRemaining,105);
assert.equal(second.movements[1].excelQuantity,0);
assert.equal(ledgerRules.validateStockLedger(second).movements.length,2);
console.log('PASS: entrega por atención y lote, confirmación explícita, R 1/0, duplicados bloqueados, FEFO y auditoría');
