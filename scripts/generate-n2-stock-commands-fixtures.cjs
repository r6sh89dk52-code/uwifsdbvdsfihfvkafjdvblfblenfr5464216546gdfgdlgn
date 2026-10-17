'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const {load}=require('./ambulatory-test-helpers.cjs');
const dir=process.env.DANPER_N1_FIXTURE_DIR;
assert(dir&&path.isAbsolute(dir));
const source=JSON.parse(fs.readFileSync(path.join(dir,'n1e-clinical-stock.json'),'utf8'));
const {postStockMovement,validateStockLedger}=load('src/kardexMovements.ts');
const original={lots:source.stockLots,movements:source.stockMovements};
const at=Date.parse('2026-10-15T16:00:00Z');
const first={
 id:'N2:RECEIPT-001',lotId:'early-unit',kind:'extraordinary',
 at,description:'Ingreso extraordinario documentado',sealedAdded:0,looseAdded:4
};
const intermediate=postStockMovement(original,first);
const laterUnit=intermediate.lots.find(x=>x.id==='later-unit');
const second={
 id:'N2:ADJUST-001',lotId:'later-unit',kind:'adjustment',at:at+1000,
 description:'Conteo físico validado por operador',
 newSealed:laterUnit.sealedContainers,newLoose:laterUnit.looseUnits+2,
 newOpened:laterUnit.openedRemaining
};
const completed=postStockMovement(intermediate,second);
validateStockLedger(completed);
assert.equal(completed.movements.length,original.movements.length+2);
const expected={
 events:[first,second],
 original:{lots:original.lots,movements:original.movements},
 afterFirst:{lots:intermediate.lots,movements:intermediate.movements},
 afterSecond:{lots:completed.lots,movements:completed.movements}
};
fs.writeFileSync(path.join(dir,'n2-stock-parity.json'),JSON.stringify(expected));
console.log('PASS N2 stock command parity reference: original',
 original.movements.length,'after',completed.movements.length);
