/**
 * v0.21.10+ — Clinically recorded consumption is finalized with the visit.
 * A *physical* Kardex subtraction is automatic only if identity, unit,
 * correspondence, available stock and FEFO lot are unambiguous.
 *
 * Never infer a physical balance, package size or quantity from a catalog
 * listing. Pending clinical consumption is retained in the saved visit and
 * surfaced to the provisional Excel without constructing false movements.
 */
import {type SavedClinicalAttention,postConfirmedAttentionDelivery,dispenseMovementId,alreadyDispensed,availableLots} from './attentionKardex';
import {type StockLedger,type StockCommand,postStockMovement,postStockMovementsBatch,validateStockLedger} from './kardexMovements';
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
  // Selecting an ambiguous *presentation* in the attention does not lock us
  // to its first lot: all matching lots of that approved product use FEFO.
  const selectedLot=explicit?matching.find(l=>l.id===explicit.lotId):undefined;
  if(explicit&&!selectedLot){
   pending('La presentación elegida ya no corresponde a una existencia autorizada.');continue;
  }
  if(explicit&&unitCounted&&explicit.quantity!==item.quantity)
   throw Error('La cantidad física de UND/TBL/PAR debe coincidir con la cantidad clínica.');
  const code=selectedLot?.code||allowedCodes[0];
  const chosen=matching.filter(l=>l.code===code&&(!selectedLot||l.name===selectedLot.name));
  if(!unitCounted&&explicit&&chosen.some(l=>l.container==='unidad'||l.unitsPerContainer<=1)){
   pending('Presentación por envase sin capacidad interna verificada; no se puede inferir una conversión física.');
   continue;
  }
  const physicalQuantity=explicit?explicit.quantity:item.quantity;
  const sorted=availableLots(chosen,code,at);
  const total=sorted.reduce((n,l)=>n+countPhysicalUnits(l),0);
  if(!sorted.length||total+0.00001<physicalQuantity){
   pending('Saldo FEFO total insuficiente. Se conserva el consumo clínico sin inventar saldo negativo.');
   continue;
  }
  // Plan using the same audited stock engine on a DISPOSABLE ledger.
  // No partial movement can ever be persisted. In particular, a box/FCO may
  // require first consuming an open remnant (R=0), then opening the next (R=1).
  type Part={lotId:string;quantity:number;open:boolean};
  const parts:Part[]=[];
  let probe:StockLedger={lots:current.lots,movements:current.movements};
  let remaining=physicalQuantity;
  let impossible='';
  while(remaining>0.00001){
   const fefo=availableLots(probe.lots.filter(l=>chosen.some(c=>c.id===l.id)),code,at);
   if(!fefo.length){impossible='No se encontró un lote FEFO disponible para completar el consumo.';break}
   const lot=fefo[0];
   const pack=lot.container!=='unidad'||lot.unitsPerContainer!==1||lot.catalogUnit!=='UND';
   const room=pack?(lot.openedRemaining>0?lot.openedRemaining:lot.looseUnits>0?lot.looseUnits:
     lot.sealedContainers>0?lot.unitsPerContainer:0):countPhysicalUnits(lot);
   const available=unitCounted?Math.floor(room+0.000001):room;
   const amount=Math.round(Math.min(remaining,available)*1000)/1000;
   if(amount<=0){impossible='El remanente FEFO no admite una salida de unidades completas.';break}
   const open=pack&&lot.openedRemaining===0&&lot.looseUnits===0&&lot.sealedContainers>0;
   if(parts.length>=490){impossible='La salida requiere demasiadas aperturas o lotes.';break}
   try{
    probe=postStockMovement(probe,{id:'FEFO:PREVIEW:'+visit.id+':'+item.id+':'+parts.length,
     lotId:lot.id,kind:'use',at,quantity:amount,allowOpen:open,
     description:'Simulación local de reparto FEFO'});
   }catch(error){impossible=error instanceof Error?error.message:'No se pudo verificar el reparto FEFO.';break}
   parts.push({lotId:lot.id,quantity:amount,open});
   remaining=Math.round((remaining-amount)*1000)/1000;
  }
  if(impossible||remaining>0.00001){
   pending('Reparto FEFO no verificable: '+(impossible||'cantidad pendiente')+'. No se realizó descuento.');
   continue;
  }
  // Every physical part carries the same clinical identity and part count.
  // Old single-lot references remain fully backwards compatible.
  const ref={attentionId:visit.id,itemId:item.id,clinicalCode:item.code,
   clinicalName:item.name,clinicalUnit:item.unit,clinicalQuantity:item.quantity,confirmedAt:at};
  const commands:StockCommand[]=parts.map((part,i)=>({
   id:parts.length===1?dispenseMovementId(visit.id,item.id):
      dispenseMovementId(visit.id,item.id)+':PART:'+(i+1),
   lotId:part.lotId,kind:'use',at,quantity:part.quantity,allowOpen:part.open,
   description:'Consumo FEFO vinculado a atención',
   dispenseRef:{...ref,...(parts.length===1?{}:{partIndex:i+1,partCount:parts.length})}
  }));
  // Batch commit either validates ALL physical parts, or the whole item stays pending.
  // A single command uses the existing audited path for compatibility.
  current=parts.length===1
   ?postConfirmedAttentionDelivery(current,visit,{
      itemId:item.id,lotId:parts[0].lotId,physicalQuantity:parts[0].quantity,
      confirmIdentity:true,confirmUnits:true,confirmDelivery:true,
      openNewContainer:parts[0].open,timestamp:at})
   :postStockMovementsBatch(current,commands);
  results.push({itemId:item.id,clinicalCode:item.code,outcome:'deducted',
   reason:parts.length===1?'Salida FEFO automática.':
      parts.length+' salidas físicas FEFO auditadas; una sola fila clínica.'});
 }
 return{ledger:current,results,deducted:results.filter(x=>x.outcome==='deducted').length,
  pending:results.filter(x=>x.outcome==='pending').length};
}
