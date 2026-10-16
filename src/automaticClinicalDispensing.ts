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
export function finalizeVisitAndPlanStock(ledger:StockLedger,visit:SavedClinicalAttention & {date?:string},at:number):AutoDispenseResult{
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
  const uniqueCodes=[...new Set(associations.map(x=>x.kardexCode))];
  const pending=(reason:string)=>results.push({itemId:item.id,clinicalCode:item.code,outcome:'pending',reason});
  if(uniqueCodes.length!==1){pending(uniqueCodes.length?'Presentaciones de Kardex ambiguas.':'Producto sin correspondencia autorizada.');continue}
  if(!individualUnit(item.unit)){
   pending('Presentación por envase: falta cantidad física interna para decidir apertura y descuento 1/0.');continue;
  }
  const code=uniqueCodes[0],association=associations[0];
  const compatible=current.lots.filter(l=>l.code===code&&l.name===association.kardexName&&(
    item.unit.toUpperCase()==='PAR'?l.catalogUnit.toUpperCase()==='PAR':['UND','TBL'].includes(l.catalogUnit.toUpperCase())));
  const candidates=availableLots(compatible,code,at).filter(l=>countPhysicalUnits(l)>=item.quantity);
  // FEFO chooses a real stock row; no synthetic lots and no negative balances.
  if(!candidates.length){pending('No existe saldo físico compatible y disponible. Se conservó el consumo clínico sin descuento.');continue}
  let posted=false;
  for(const lot of candidates){
   try{
    const next=postConfirmedAttentionDelivery(current,visit,{
     itemId:item.id,lotId:lot.id,physicalQuantity:item.quantity,
     confirmIdentity:true,confirmUnits:true,confirmDelivery:true,
     openNewContainer:(lot.container!=='unidad'||lot.unitsPerContainer!==1||lot.catalogUnit!=='UND')&&
             lot.openedRemaining===0&&lot.looseUnits===0&&lot.sealedContainers>0&&item.quantity<=lot.unitsPerContainer,timestamp:at
    });
    current=next;results.push({itemId:item.id,clinicalCode:item.code,outcome:'deducted',reason:'Salida física registrada automáticamente con FEFO.'});
    posted=true;break;
   }catch(err){
    // Existing stock in a closed container may need its packaging opening
    // explicitly tracked. Never silently make that decision.
    if(!(err instanceof Error))throw err;
    if(!/envase|contenido abierto|Stock insuficiente|Lote vencido/i.test(err.message))throw err;
   }
  }
  if(!posted)pending('Existencias presentes, pero requieren apertura/selección física específica. Pendiente de conciliación.');
 }
 return{ledger:current,results,deducted:results.filter(x=>x.outcome==='deducted').length,
  pending:results.filter(x=>x.outcome==='pending').length};
}
