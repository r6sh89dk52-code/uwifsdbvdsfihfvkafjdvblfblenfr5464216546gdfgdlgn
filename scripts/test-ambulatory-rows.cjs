const assert=require('node:assert/strict');
const {load,visit,options}=require('./ambulatory-test-helpers.cjs');
const rows=load('src/ambulatoryRows.ts'),movement=load('src/kardexMovements.ts'),delivery=load('src/attentionKardex.ts');
const products=require('../src/products.json');
const p=products.find(p=>p.code==='16000182');
const boxed=products.find(p=>p.code==='16000013');
const item={id:'i',...p,quantity:1,procedure:'TRATAMIENTO ORAL'};
const at=Date.parse('2026-10-13T13:25:00Z');
function state(pack=false,code=p.code){return{lots:[{id:'lot',code,name:p.name,catalogUnit:pack?'FCO':'UND',lot:'FICTICIO',expires:'2027-12-30',container:pack?'frasco':'unidad',unitsPerContainer:pack?100:1,sealedContainers:10,looseUnits:0,openedRemaining:0,updatedAt:at-1000}],movements:[]};}
function deliver(s,a,pack=false){return delivery.postConfirmedAttentionDelivery(s,a,{itemId:a.items[0].id,lotId:'lot',physicalQuantity:pack?10:1,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:pack&&s.lots[0].openedRemaining===0,timestamp:at+s.movements.length});}
let passed=0;
function test(name,run){run();passed++;}
const build=(v,l={lots:[],movements:[]},start='2026-10-13',end='2026-10-13',opts=options)=>rows.buildAmbulatoryRows(v,l,start,end,opts);
test('zero',()=>assert.equal(build([]).lines.length,0));
test('saved only',()=>assert.equal(build([{...visit(),status:'draft'}]).lines.length,0));
test('columns and standalone',()=>{const a=build([visit()]).lines[0];assert.equal(a.cells.length,30);assert.equal(a.cells[0],'LA VENTUROSA');assert.equal(a.cells[1],'PRODUCCION AGRICOLA PALTO');assert.equal(a.cells[7],'00000001');assert.equal(a.cells[19],'OBSERVACION');assert.equal(a.cells[17],'');});
test('dates',()=>{assert.equal(rows.excelDate('2026-10-13'),46308);assert.equal(rows.validExportDate('2026-02-30'),false);assert.equal(rows.validExportDate('2024-02-29'),true);assert.throws(()=>build([visit()],undefined,'2026-02-30'),/Intervalo/);assert.throws(()=>build([{...visit(),date:'z'}]),/fecha/);});
test('hours',()=>{assert.throws(()=>build([{...visit(),time:'24:00'}]),/Hora/);assert.throws(()=>build([{...visit(),permissionTime:'08:99'}]),/Hora/);});
test('duplicate attentions',()=>assert.throws(()=>build([visit(),visit()]),/duplicada/));
test('duplicate items',()=>assert.throws(()=>build([visit('a',[item,item])]),/duplicado/));
test('invalid codes',()=>{for(const code of ['o1000243','o2001232','o2002298','o2002299','O2001117','160999999'])assert.throws(()=>build([visit('a',[{...item,code}])]),/excluido|verificados/);});
test('name and unit mismatch',()=>{assert.throws(()=>build([visit('a',[{...item,name:'OTRO'}])]),/verificados/);assert.throws(()=>build([visit('a',[{...item,unit:'FCO'}])]),/verificados/);});
test('absent delivery',()=>{const a=build([visit('a',[item])]);assert.ok(a.blockers.length);assert.equal(a.lines[0].cells[17],'');});
test('confirmed unit',()=>{const a=visit('a',[item]),s=deliver(state(),a);const before=JSON.stringify([a,s]);const r=build([a],s);assert.equal(r.lines[0].cells[17],1);assert.equal(r.blockers.length,0);assert.equal(JSON.stringify([a,s]),before);assert.deepEqual(r,build([a],s));});
test('pack 1 then 0',()=>{
 const needle={id:'i',...boxed,quantity:1,procedure:'CURACION'};
 const a=visit('a',[needle]),b=visit('b',[{...needle,id:'j'}]);
 let physical={lots:[{id:'lot',code:boxed.code,name:boxed.name,catalogUnit:'UND',lot:'FICTICIO',expires:'2027-12-30',container:'caja',unitsPerContainer:100,sealedContainers:2,looseUnits:0,openedRemaining:0,updatedAt:at-1000}],movements:[]};
 for(const [v,open,time] of [[a,true,at],[b,false,at+1000]]){
 physical=delivery.postConfirmedAttentionDelivery(physical,v,{itemId:v.items[0].id,lotId:'lot',physicalQuantity:1,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:open,timestamp:time});
 }
 const r=build([b,a],physical);
 assert.deepEqual(r.lines.map(x=>x.cells[17]),[1,0]);
 assert.equal(r.linkedDeliveries,2);
});
test('same worker first and second paracetamol doses never become zero',()=>{
 const a=visit('dose-a',[item]),b=visit('dose-b',[{...item,id:'j',quantity:2}]);
 let stock=state();
 stock=delivery.postConfirmedAttentionDelivery(stock,a,{itemId:'i',lotId:'lot',physicalQuantity:1,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:false,timestamp:at});
 stock=delivery.postConfirmedAttentionDelivery(stock,b,{itemId:'j',lotId:'lot',physicalQuantity:2,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:false,timestamp:at+1000});
 const r=build([a,b],stock);
 assert.deepEqual(r.lines.map(x=>x.cells[17]),[1,2]);
 assert.deepEqual(r.lines.map(x=>x.cells[18]),['PRIMERA','SEGUNDA']);
});
test('individual paracetamol rejects bottle accounting and mismatched physical doses',()=>{
 const a=visit('individual',[item]);
 assert.throws(()=>deliver(state(true),a,true),/Unidad física incompatible/);
 assert.throws(()=>delivery.postConfirmedAttentionDelivery(state(),a,{itemId:'i',lotId:'lot',physicalQuantity:2,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:false,timestamp:at}),/Cantidad física individual diferente/);
});
test('R tampering',()=>{const a=visit('a',[item]),s=deliver(state(),a);s.movements[0].excelQuantity=9;assert.throws(()=>build([a],s),/Cantidad R/);});
test('stale clinical delivery',()=>{const a=visit('a',[item]),s=deliver(state(),a);assert.throws(()=>build([visit('a',[{...item,quantity:2}])],s),/modificada/);});
test('wrong movement kind',()=>{const a=visit('a',[item]),s=deliver(state(),a);s.movements[0].kind='adjustment';assert.throws(()=>build([a],s),/inválido/);});
test('duplicate deliveries',()=>{const a=visit('a',[item]),s=deliver(state(),a);s.movements.push({...s.movements[0]});assert.throws(()=>build([a],s),/duplicado/);});
test('unreviewed nursing code is blocked',()=>{const a=visit('a',[item]),s=deliver(state(false,'E-23'),a);assert.ok(build([a],s).blockers.some(x=>x.includes('correspondencia aprobada')));});
test('reviewed mapping',()=>{const a=visit('a',[item]),s=deliver(state(false,'E-22'),a),catalog=load('src/kardexCatalog.ts');const mappings=[{id:'map',kind:'verify',clinicalCode:p.code,clinicalName:p.name,kardexCode:'E-22',kardexName:catalog.kardexCatalog.find(p=>p.id==='E-22').name,reason:'Equivalencia ficticia confirmada',at:at-100}];assert.equal(build([a],s,undefined,undefined,{...options,mappings}).blockers.length,0);});
test('incidents block',()=>{const a=visit('a',[item]),s=deliver(state(),a);const m=s.movements[0];const incidents=[{id:'inc',movementId:m.id,attentionId:'a',itemId:'i',kind:'returned',quantity:1,reason:'Devolución ficticia para prueba',at:at+10,stockRestored:false}];assert.ok(build([a],s,undefined,undefined,{...options,incidents}).blockers.some(x=>x.includes('devolución')));});
test('6 visits do not clamp frequency',()=>{const r=build(Array.from({length:6},(_,i)=>({...visit(String(i)),time:'0'+(i+1)+':00'})));assert.deepEqual(r.lines.map(x=>x.cells[18]),['PRIMERA','SEGUNDA','TERCERA','CUARTA','QUINTA','REVISAR']);assert.ok(r.warnings.some(w=>w.includes('cinco')));});
test('period cutoffs',()=>{assert.equal(build([{...visit(),date:'2026-10-12'}]).lines.length,0);assert.equal(build([{...visit(),date:'2026-10-14'}]).lines.length,0);});
test('multiple items',()=>{const a=visit('a',[item,{...item,id:'two'}]);let s=deliver(state(),a);s=delivery.postConfirmedAttentionDelivery(s,a,{itemId:'two',lotId:'lot',physicalQuantity:1,confirmIdentity:true,confirmUnits:true,confirmDelivery:true,openNewContainer:false,timestamp:at+1});const r=build([a],s);assert.equal(r.lines.length,2);assert.deepEqual(r.lines.map(x=>x.cells[18]),['PRIMERA','PRIMERA']);});
test('invalid identifiers and quantity',()=>{assert.throws(()=>build([{...visit(),worker:{...visit().worker,dni:'123'}}]),/incompletos/);assert.throws(()=>build([visit('a',[{...item,quantity:0}])]),/Cantidad/);});
test('missing age stays blank',()=>assert.equal(build([{...visit(),worker:{...visit().worker,age:''}}]).lines[0].cells[9],''));
test('control chars and Excel length',()=>{assert.throws(()=>build([{...visit(),diagnosis:'a\x01'}]),/Texto/);assert.throws(()=>build([{...visit(),diagnosis:'a'.repeat(32768)}]),/Texto/);});
test('3000 visits',()=>assert.equal(build(Array.from({length:3000},(_,i)=>visit('v'+i))).lines.length,3000));
test('10001 limit',()=>assert.throws(()=>build(Array.from({length:10001},(_,i)=>visit('v'+i))),/10 000/));
test('unknown subdivision',()=>assert.throws(()=>build([visit()],undefined,undefined,undefined,{subdivision:'NO EXISTE'}),/Subdivisión/));
test('missing subdivision',()=>assert.ok(build([visit()],undefined,undefined,undefined,{}).blockers.length));
assert.ok(movement.validateStockLedger);
console.log(`PASS: ${passed} ambulatory row scenarios, audited R=1/0, mappings, incidents, read-only and 3000 rows.`);
module.exports={build,visit,options,item,state,deliver};
