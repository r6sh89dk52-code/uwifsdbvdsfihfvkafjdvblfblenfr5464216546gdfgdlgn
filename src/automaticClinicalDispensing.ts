/**
 * v0.21.10+ — Clinically recorded consumption is finalized with the visit.
 * A *physical* Kardex subtraction is automatic only if identity, unit,
 * correspondence, available stock and FEFO lot are unambiguous.
 *
 * Never infer a physical balance, package size or quantity from a catalog
 * listing. Pending clinical consumption is retained in the saved visit and
 * surfaced to the provisional Excel without constructing false movements.
 */
import {type SavedClinicalAttention,postConfirmedAttentionDelivery,alreadyDispensed,availableLots} from './attentionKardex';
import {type StockLedger,validateStockLedger} from './kardexMovements';
import {reviewedAssociationsFor} from './reviewedKardexAssociations';
import {countPhysicalUnits} from './inventoryRules';

/** Selected *inside* the attention, never in a separate Kardex confirmation screen. */
export type InVisitPhysicalUse={lotId:string;quantity:number};
export type InVisitClinicalLine=SavedClinicalAttention['items'][number]&{physicalUse?:InVisitPhysicalUse};
export type InVisitSavedAttention=Omit<SavedClinicalAttention,'items'>&{items:InVisitClinicalLine[];date?:string};
export type AutoOutcome='already-linked'|'deducted'|'pending';
export type AutoDispenseResult={
 ledger:StockLedger;
 results:{itemId:string;clinicalCode:string;outcome:AutoOutcome;reason:string}[];
 deducted:number;
 pending:number;
};
/** The user-approved clinical quantity is physically self-identical for individual units ONLY.
 * Boxes, bottles, kits etc. require clinical quantity in their internal physical units,
 * which the current form does not capture. These remain pending, never guessed.
 */
function individualUnit(unit:string):boolean{return ['UND','TBL','PAR'].includes(unit.trim().toUpperCase())}
function limaDay(at:number):string{
 const parts=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(at));
 const p=(type:string)=>parts.find(x=>x.type===type)?.value||'';
 return p('year')+'-'+p('month')+'-'+p('day');
}
export function finalizeVisitAndPlanStock(ledger:StockLedger,visit:InVisitSavedAttention,at:number):AutoDispenseResult{
 if(!visit||visit.status!=='saved'||!visit.id?.trim())throw Error('La atención debe estar finalizada.');
 if(!Number.isSafeInteger(at)||at<=0)throw Error('Hora de entrega inválida.');
 let current=validateStockLedger(ledger);
 const results:AutoDispenseResult['results']=[];
 const ids=new Set<string>();
 for(const item of visit.items){
  if(!item.id?.trim()||ids.has(item.id)||!/^[0-9]+$/.test(item.code)||
    !item.name?.trim()||!item.unit?.trim()||!Number.isSafeInteger(item.quantity)||item.quantity<=0)
    throw Error('Artículo de atención incompleto o duplicado.');
  ids.add(item.id);
  const linked=current.movements.find(m=>m.dispenseRef?.attentionId===visit.id&&m.dispenseRef.itemId===item.id);
  if(linked){
   if(linked.dispenseRef?.clinicalCode!==item.code||linked.dispenseRef?.clinicalName!==item.name||
     linked.dispenseRef?.clinicalUnit!==item.unit||linked.dispenseRef?.clinicalQuantity!==item.quantity)
    throw Error('La atención intenta cambiar un medicamento ya entregado. Se requiere corrección auditada.');
   results.push({itemId:item.id,clinicalCode:item.code,outcome:'already-linked',reason:'Entrega ya registrada. No se duplica.'});continue;
  }
  if(alreadyDispensed(current,visit.id,item.id))
    throw Error('Identificador de entrega inconsistente.');
  if(visit.date && visit.date!==limaDay(at)){
   results.push({itemId:item.id,clinicalCode:item.code,outcome:'pending',
    reason:'La fecha clínica difiere del día del guardado. No se descuenta stock actual por un consumo histórico.'});
   continue;
  }
  const associations=reviewedAssociationsFor(item.code).filter(x=>
    x.clinicalName===item.name&&x.clinicalUnit===item.unit);
  const allowedCodes=[...new Set(associations.map(x=>x.kardexCode))];
  const pending=(reason:string)=>results.push({itemId:item.id,clinicalCode:item.code,outcome:'pending',reason});
  if(!allowedCodes.length){pending('No existe correspondencia Kardex autorizada.');continue}
  const unitCounted=individualUnit(item.unit);
  const explicit=item.physicalUse;
  // A selection in the clinical form is evidence only when it exactly matches
  // an approved Kardex identity. It is NOT a second "confirm delivery" step.
  if(explicit!==undefined){
   if(!explicit||typeof explicit.lotId!=='string'||!explicit.lotId.trim()||
     typeof explicit.quantity!=='number'||!Number.isFinite(explicit.quantity)||explicit.quantity<=0||
     explicit.quantity>10000000)
    throw Error('Selecciona una existencia y una cantidad física válida dentro de la atención.');
  }
  if(!explicit&&allowedCodes.length!==1){
   pending('Varias presentaciones del Kardex: selecciona la utilizada en esta atención.');continue;
  }
  if(!explicit&&!unitCounted){
   pending('Para cajas/frascos indica la cantidad física utilizada en la atención, sin adivinar contenido.');continue;
  }
  const matching=current.lots.filter(l=>allowedCodes.includes(l.code)&&
    associations.some(assoc=>assoc.kardexCode===l.code&&assoc.kardexName===l.name)&&
    (!unitCounted||(item.unit.toUpperCase()==='PAR'?l.catalogUnit.toUpperCase()==='PAR':
    ['UND','TBL'].includes(l.catalogUnit.toUpperCase()))));
  const chosen=explicit?matching.filter(l=>l.id===explicit.lotId):matching.filter(l=>l.code===allowedCodes[0]);
  if(explicit&&!chosen.length){
   pending('La existencia elegida ya no corresponde al producto autorizado. Actualiza la ficha.');continue;
  }
  if(explicit&&unitCounted&&explicit.quantity!==item.quantity)
   throw Error('La cantidad física de UND/TBL/PAR debe coincidir con la cantidad clínica.');
  const physicalQuantity=explicit?explicit.quantity:item.quantity;
  const fefo=availableLots(chosen,explicit?chosen[0].code:allowedCodes[0],at);
  if(!explicit&&fefo.length>0&&countPhysicalUnits(fefo[0])<physicalQuantity){
   pending('El lote FEFO más próximo no alcanza: se requiere reparto entre lotes dentro de la atención. No se usó otro lote por suposición.');
   continue;
  }
  const candidates=fefo.filter(l=>countPhysicalUnits(l)>=physicalQuantity);
  if(!candidates.length){
   pending('No existe saldo físico del producto/selección con cantidad suficiente y sin vencer. No se inventó descuento.');
   continue;
  }
  let posted=false;
  for(const lot of candidates){
   try{
    // A fresh sealed container is opened only when there is no remainder
    // or loose content, and when the registered inner capacity is sufficient.
    const openNew=(lot.container!=='unidad'||lot.unitsPerContainer!==1||lot.catalogUnit!=='UND')&&
      lot.openedRemaining===0&&lot.looseUnits===0&&lot.sealedContainers>0&&
      physicalQuantity<=lot.unitsPerContainer;
    const next=postConfirmedAttentionDelivery(current,visit,{
     itemId:item.id,lotId:lot.id,physicalQuantity,
     confirmIdentity:true,confirmUnits:true,confirmDelivery:true,
     openNewContainer:openNew,timestamp:at
    });
    current=next;
    results.push({itemId:item.id,clinicalCode:item.code,outcome:'deducted',
      reason:'Descuento físico desde la atención, con selección verificable.'});
    posted=true;break;
   }catch(err){
    if(!(err instanceof Error))throw err;
    if(!/envase|contenido abierto|Stock insuficiente|Lote vencido/i.test(err.message))throw err;
   }
  }
  if(!posted)pending('Existencias presentes, pero requieren apertura/selección física específica. Pendiente de conciliación.');
 }
 return{ledger:current,results,deducted:results.filter(x=>x.outcome==='deducted').length,
  pending:results.filter(x=>x.outcome==='pending').length};
}
