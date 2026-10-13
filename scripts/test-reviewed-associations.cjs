const assert=require('node:assert/strict');
const {load}=require('./ambulatory-test-helpers.cjs');
const clinical=require('../src/products.json');
const catalog=load('src/kardexCatalog.ts');
const reviewed=load('src/reviewedKardexAssociations.ts');
const reconciliation=load('src/reconciliationRules.ts');
const at=Date.parse('2026-10-13T18:00:00Z');
assert.equal(catalog.kardexCatalog.length,98);
assert.equal(catalog.kardexCatalog.filter(p=>p.donated).length,0);
assert.equal(reviewed.reviewedAssociations.length,86);
assert.equal(new Set(reviewed.reviewedAssociations.map(p=>p.kardexCode)).size,86);
assert.equal(new Set(reviewed.reviewedAssociations.map(p=>p.clinicalCode)).size,85);
assert.ok(reviewed.isReviewedAssociation('16024400','E-62'));
assert.ok(reviewed.isReviewedAssociation('16024400','E-63'));
assert.equal(reviewed.reviewedAssociationsFor('16024400').length,2);
assert.equal(reviewed.reviewedAssociationsFor('16024694').length,0);
assert.equal(reviewed.isReviewedAssociation('16024694','E-68'),false);
assert.equal(reviewed.reviewedAssociations.some(p=>p.kardexCode==='E-68'||p.kardexCode.startsWith('D-')),false);
for(const m of reviewed.reviewedAssociations){
 assert.ok(catalog.kardexCatalog.some(p=>p.id===m.kardexCode&&p.name===m.kardexName));
 assert.ok(clinical.some(p=>p.code===m.clinicalCode&&p.name===m.clinicalName&&p.unit===m.clinicalUnit));
}
const matching=reviewed.reviewedAssociationsFor('16024400')[0];
const stock={lots:['E-62','E-63','E-68'].map(k=>{
 const p=catalog.kardexCatalog.find(x=>x.id===k);
 return {id:'lot-'+k,code:p.id,name:p.name,catalogUnit:'UND',lot:'DEMO-'+k,expires:'2027-12-30',
   container:'unidad',unitsPerContainer:1,sealedContainers:3,looseUnits:0,openedRemaining:0,updatedAt:at-1000};
 }),movements:[]};
const visit=(id,itemId,code='16024400')=>{
 const p=clinical.find(p=>p.code===code);
 return {id,status:'saved',items:[{id:itemId,code:p.code,name:p.name,unit:p.unit,quantity:1}]};
};
const confirmation=(itemId,kardexCode,timestamp)=>({
 itemId,lotId:'lot-'+kardexCode,physicalQuantity:1,
 confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:false,timestamp
});
const first=reconciliation.postDeliveryWithMapping(stock,visit('a','i'),confirmation('i','E-62',at),[]);
assert.equal(first.lots.find(x=>x.code==='E-62').sealedContainers,2);
assert.equal(first.lots.find(x=>x.code==='E-63').sealedContainers,3);
const second=reconciliation.postDeliveryWithMapping(first,visit('b','j'),confirmation('j','E-63',at+1000),[]);
assert.equal(second.lots.find(x=>x.code==='E-62').sealedContainers,2);
assert.equal(second.lots.find(x=>x.code==='E-63').sealedContainers,2);
assert.equal(second.movements.length,2);
assert.equal(second.movements[0].excelQuantity,1);
assert.equal(second.movements[1].excelQuantity,1);
const noNylon=visit('n','k','16024694');
assert.throws(()=>reconciliation.postDeliveryWithMapping(stock,noNylon,confirmation('k','E-68',at),[]),/no tiene una correspondencia aprobada/);
assert.throws(()=>reconciliation.postDeliveryWithMapping(stock,visit('c','k'),confirmation('k','E-68',at),[]),/no corresponde/);
const wrongName=visit('c','k');wrongName.items[0].name='PRODUCTO DISTINTO';
assert.throws(()=>reconciliation.postDeliveryWithMapping(stock,wrongName,confirmation('k','E-62',at),[]),/no corresponde/);
const legacy=[{id:'legacy',kind:'verify',clinicalCode:'16024694',clinicalName:noNylon.items[0].name,
 kardexCode:'E-68',kardexName:catalog.kardexCatalog.find(x=>x.id==='E-68').name,reason:'Referencia histórica',at:at-100}];
assert.throws(()=>reconciliation.postDeliveryWithMapping(stock,noNylon,confirmation('k','E-68',at),legacy),/no tiene una correspondencia aprobada/);
assert.throws(()=>reconciliation.postDeliveryWithMapping(first,visit('a','i'),confirmation('i','E-62',at),[]),/ya tiene una entrega/);
console.log('PASS: 86/98 reviewed, 85 numeric codes, E-62/E-63 independent physical deductions, excluded nylon/donated, legacy mapping cannot bypass.');
