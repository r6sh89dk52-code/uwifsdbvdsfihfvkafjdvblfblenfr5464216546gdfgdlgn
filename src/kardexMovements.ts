/** DANPER v0.11 — demo-only, auditable movements for the physical stock by lot.
 * Excel consumption for packaged supplies is 1 when a new container is opened,
 * 0 for later uses from that container. Physical consumption is tracked separately.
 */
import {countPhysicalUnits,peruStockDate,validateStockLot,validateStockLots,type StockLot} from './inventoryRules';

export type MovementKind='extraordinary'|'use'|'adjustment';
export type DispenseRef={
 attentionId:string;itemId:string;clinicalCode:string;clinicalName:string;
 clinicalUnit:string;clinicalQuantity:number;confirmedAt:number;
 /** For one clinical item split into several auditable FEFO lot issues. Legacy records omit both. */
 partIndex?:number;partCount?:number;
};
export type StockMovement={
 id:string;lotId:string;code:string;name:string;unit:string;at:number;
 kind:MovementKind;description:string;quantity:number;
 sealedAdded:number;looseAdded:number;openedNewContainer:boolean;
 excelQuantity:number;physicalChange:number;
 before:StockLot;after:StockLot;
 dispenseRef?:DispenseRef;
};
export type StockLedger={lots:StockLot[];movements:StockMovement[]};
export type StockCommand={
 id:string;lotId:string;at:number;description:string;kind:MovementKind;
 quantity?:number;sealedAdded?:number;looseAdded?:number;
 allowOpen?:boolean;newSealed?:number;newLoose?:number;newOpened?:number;
 dispenseRef?:DispenseRef;
};
const round=(v:number)=>Math.round((v+Number.EPSILON)*1000)/1000;
const maxMoves=1000;
function amount(value:unknown,label:string,integer=false,allowZero=false){
 if(typeof value!=='number'||!Number.isFinite(value)||value<0||value>10000000||
   (integer&&!Number.isInteger(value))||(!allowZero&&value===0))
   throw Error(label+': cantidad inválida.');
 return value;
}
function validDispenseRef(ref:DispenseRef,id:string,kind:MovementKind,at:number){
 const split=ref.partIndex!==undefined||ref.partCount!==undefined;
 const validSplit=split&&Number.isSafeInteger(ref.partCount)&&Number.isSafeInteger(ref.partIndex)&&
    ref.partCount! >= 2&&ref.partCount! <= 500&&ref.partIndex! >= 1&&ref.partIndex! <= ref.partCount!;
 const expected='ATT:'+ref.attentionId+':ITEM:'+ref.itemId+
   (split?':PART:'+ref.partIndex:'');
 if((split&&!validSplit)||kind!=='use'||id!==expected||
   ![ref.attentionId,ref.itemId,ref.clinicalCode,ref.clinicalName,ref.clinicalUnit].every(x=>typeof x==='string'&&x.trim().length>0)||
   !Number.isInteger(ref.clinicalQuantity)||ref.clinicalQuantity<=0||
   !Number.isSafeInteger(ref.confirmedAt)||ref.confirmedAt!==at)
   throw Error('Vínculo de atención y Kardex inválido.');
}
function validCommand(c:StockCommand){
 if(!c.id?.trim()||!c.lotId?.trim()||!Number.isSafeInteger(c.at)||c.at<=0)throw Error('Movimiento sin identificador o fecha válidos.');
 if(!['extraordinary','use','adjustment'].includes(c.kind))throw Error('Tipo de movimiento inválido.');
 if(c.dispenseRef)validDispenseRef(c.dispenseRef,c.id,c.kind,c.at);
 if(typeof c.description!=='string'||c.description.trim().length<3||c.description.length>250)
   throw Error('Indica un motivo de al menos 3 caracteres (máximo 250).');
}
export function validateStockMovements(v:unknown,allowIncompleteParts=false):StockMovement[]{
 if(!Array.isArray(v)||v.length>maxMoves)throw Error('Historial de movimientos incompatible o demasiado grande.');
 const ids=new Set<string>();
 const links=new Set<string>();
 const groups=new Map<string,StockMovement[]>();
 const validated=v.map(raw=>{
  if(!raw||typeof raw!=='object'||Array.isArray(raw))throw Error('Movimiento inválido.');
  const m=raw as StockMovement;
  if(typeof m.id!=='string'||!m.id.trim()||typeof m.lotId!=='string'||!m.lotId.trim()||ids.has(m.id)||
    !['extraordinary','use','adjustment'].includes(m.kind)||
    typeof m.code!=='string'||typeof m.name!=='string'||typeof m.unit!=='string'||
    typeof m.description!=='string'||m.description.length<3||m.description.length>250||
    !Number.isSafeInteger(m.at)||m.at<=0||typeof m.openedNewContainer!=='boolean')
    throw Error('Movimiento de Kardex inválido o duplicado.');
  if(m.dispenseRef){
    validDispenseRef(m.dispenseRef,m.id,m.kind,m.at);
    const pair=JSON.stringify([m.dispenseRef.attentionId,m.dispenseRef.itemId]);
    const idKey=pair+':'+(m.dispenseRef.partIndex??'legacy');
    if(links.has(idKey))throw Error('Dos movimientos duplicados vinculados a un producto de atención.');
    links.add(idKey);
    groups.set(pair,[...(groups.get(pair)||[]),m]);
  }
  for(const key of ['quantity','sealedAdded','looseAdded','excelQuantity','physicalChange'] as const)
   if(typeof m[key]!=='number'||!Number.isFinite(m[key]))throw Error('Cantidad corrupta de un movimiento.');
  const before=validateStockLot(m.before),after=validateStockLot(m.after);
  if(before.id!==m.lotId||after.id!==m.lotId||before.code!==after.code||m.code!==after.code||
    round(countPhysicalUnits(after)-countPhysicalUnits(before))!==round(m.physicalChange))
    throw Error('Inconsistencia histórica en el movimiento.');
  ids.add(m.id);
  return {...m,before,after};
 });
 // The group of physical movements is indivisible. Never accept a partial
 // multi-lot commit into clinical/stock persistence or a restored backup.
 for(const group of groups.values()){
  const first=group[0].dispenseRef!;
  const split=first.partCount!==undefined;
  if(group.some(m=>{
   const ref=m.dispenseRef!;
   return (ref.partCount!==undefined)!==split||ref.clinicalCode!==first.clinicalCode||
    ref.clinicalName!==first.clinicalName||ref.clinicalUnit!==first.clinicalUnit||
    ref.clinicalQuantity!==first.clinicalQuantity||ref.confirmedAt!==first.confirmedAt||
    (split&&ref.partCount!==first.partCount);
  }))throw Error('Inconsistencia entre partes de una misma atención.');
  if(split){
   if(!allowIncompleteParts && group.length!==first.partCount)
    throw Error('La entrega FEFO multilote está incompleta.');
   const counted=['UND','TBL','PAR'].includes(first.clinicalUnit.trim().toUpperCase());
   const total=group.reduce((n,m)=>n+m.quantity,0);
   if(counted&&(!Number.isInteger(total)||total>first.clinicalQuantity||
     (!allowIncompleteParts&&total!==first.clinicalQuantity)))
    throw Error('La cantidad sumada de los lotes no coincide con la atención.');
  }else if(group.length!==1)throw Error('Una entrega antigua no puede duplicarse.');
 }
 return validated;
}

/** Detect corrupted or overwritten stock history before allowing further writes. */
export function validateStockLedger(value:StockLedger,allowIncompleteParts=false):StockLedger{
 const lots=validateStockLots(value.lots);
 const movements=validateStockMovements(value.movements,allowIncompleteParts);
 const last=new Map<string,StockLot>();
 for(const move of movements){
  const previous=last.get(move.lotId);
  if(previous && JSON.stringify(previous)!==JSON.stringify(move.before))
    throw Error('El historial del lote contiene movimientos discontinuos.');
  last.set(move.lotId,move.after);
 }
 for(const [lotId,after] of last.entries()){
  const current=lots.find(x=>x.id===lotId);
  if(!current||JSON.stringify(current)!==JSON.stringify(after))
   throw Error('El saldo del lote no coincide con el historial auditado.');
 }
 return {lots,movements};
}
function postStockMovementInternal(ledger:StockLedger,command:StockCommand,allowIncompleteParts=false):StockLedger{
 validCommand(command);
 const {lots,movements}=validateStockLedger(ledger,allowIncompleteParts);
 const existing=movements.find(x=>x.id===command.id);
 if(existing){
   if(existing.lotId!==command.lotId||existing.kind!==command.kind||existing.at!==command.at||
      existing.description!==command.description.trim()||
      JSON.stringify(existing.dispenseRef??null)!==JSON.stringify(command.dispenseRef??null)||
      (command.kind==='use'&&existing.quantity!==command.quantity)||
      (command.kind==='extraordinary'&&(existing.sealedAdded!==(command.sealedAdded??0)||existing.looseAdded!==(command.looseAdded??0))))
     throw Error('Identificador de movimiento reutilizado con otros datos.');
   return {lots,movements}; // Retry is idempotent.
 }
 if(movements.length>=maxMoves)throw Error('Límite de movimientos del prototipo alcanzado. No se guardó el movimiento.');
 const index=lots.findIndex(x=>x.id===command.lotId);
 if(index<0)throw Error('Lote no encontrado. Actualiza la pantalla.');
 const before=lots[index];
 let after:StockLot={...before};
 let quantity=0,excelQuantity=0,sealedAdded=0,looseAdded=0,openedNewContainer=false;
 const pack=before.container!=='unidad'||before.unitsPerContainer!==1||before.catalogUnit!=='UND';
 // The report's R column follows the OFFICIAL issue unit, not the number of
 // visits and not blindly the packaging of a physical lot. E.g. tablets/UND
 // must report each tablet even if kept in a box of 100; a CJA or FCO tracks
 // the opening (1), with later withdrawals from the opened container (0).
 const clinicalUnit=command.dispenseRef?.clinicalUnit.trim().toUpperCase();
 const individuallyCounted=clinicalUnit==='UND'||clinicalUnit==='TBL'||clinicalUnit==='PAR';
 if(command.kind==='use'&&individuallyCounted){
  const stockUnit=before.catalogUnit.trim().toUpperCase();
  const compatible=clinicalUnit==='PAR'?stockUnit==='PAR':
   stockUnit==='UND'||stockUnit==='TBL';
  if(!compatible)throw Error('Unidad física incompatible: medicamento individual requiere conteo en UND/TBL o PAR, no un frasco/caja contabilizado como envase.');
  if(!Number.isInteger(command.quantity)||
   (command.dispenseRef!.partCount===undefined
    ?command.quantity!==command.dispenseRef!.clinicalQuantity
    :command.quantity>command.dispenseRef!.clinicalQuantity))
   throw Error('Cantidad física individual diferente de la cantidad entregada en la atención.');
 }
 if(command.kind==='extraordinary'){
  sealedAdded=amount(command.sealedAdded??0,'Envases ingresados',true,true);
  looseAdded=amount(command.looseAdded??0,'Unidades ingresadas',false,true);
  if(!sealedAdded&&!looseAdded)throw Error('Registra al menos un envase cerrado o una cantidad suelta.');
  after.sealedContainers+=sealedAdded;after.looseUnits=round(after.looseUnits+looseAdded);
  quantity=round(sealedAdded*before.unitsPerContainer+looseAdded);
 }else if(command.kind==='use'){
  const day=peruStockDate(command.at);
  if(before.expires && before.expires < day)throw Error('Lote vencido: no está permitido registrar su uso.');
  quantity=amount(command.quantity,'Cantidad utilizada',!pack);
  quantity=round(quantity);
  if(quantity<=0)throw Error('Cantidad demasiado pequeña.');
  if(!pack){
   if(quantity>countPhysicalUnits(before))throw Error('Stock insuficiente para esta salida.');
   let rest=quantity;
   const fromLoose=Math.min(rest,after.looseUnits);after.looseUnits=round(after.looseUnits-fromLoose);rest=round(rest-fromLoose);
   const fromSealed=Math.min(rest,after.sealedContainers);after.sealedContainers-=fromSealed;rest=round(rest-fromSealed);
   if(rest>0){after.openedRemaining=round(after.openedRemaining-rest);}
   excelQuantity=quantity;
  }else if(after.openedRemaining>0){
   if(quantity>after.openedRemaining)throw Error('El envase abierto no alcanza. Registra su consumo restante primero, y luego una nueva apertura.');
   after.openedRemaining=round(after.openedRemaining-quantity);
   excelQuantity=0;
  }else if(after.looseUnits>=quantity && !command.allowOpen){
   after.looseUnits=round(after.looseUnits-quantity);
   excelQuantity=0; // Ya estaban sueltas; no abrir otra caja/frase.
  }else if(after.sealedContainers>0 && command.allowOpen===true){
   if(quantity>before.unitsPerContainer)throw Error('La cantidad supera la capacidad de un envase.');
   after.sealedContainers--;
   after.openedRemaining=round(before.unitsPerContainer-quantity);
   openedNewContainer=true;excelQuantity=1;
  }else if(after.sealedContainers>0){
   throw Error('Confirma la apertura del envase antes del primer consumo.');
  }else{
   throw Error('No hay contenido abierto suficiente ni envases cerrados disponibles.');
  }
   // A box containing individual tablets is still dispensed by tablets.
   // The R=1/0 rule applies only to materials whose official count is per
   // container (CJA/FCO/PAQ), never to an individual tablet or pair.
   if(individuallyCounted)excelQuantity=quantity;
 }else{
  after.sealedContainers=amount(command.newSealed,'Nuevo saldo cerrado',true,true);
  after.looseUnits=round(amount(command.newLoose,'Nuevo saldo suelto',false,true));
  after.openedRemaining=round(amount(command.newOpened,'Contenido abierto restante',false,true));
  if(after.sealedContainers===before.sealedContainers&&after.looseUnits===before.looseUnits&&after.openedRemaining===before.openedRemaining)
   throw Error('No existen diferencias para registrar un ajuste.');
 }
 after.updatedAt=command.at;
 after=validateStockLot(after);
 const delta=round(countPhysicalUnits(after)-countPhysicalUnits(before));
 if(!Number.isFinite(delta)||Math.abs(delta)>10000000)throw Error('Movimiento físico fuera del límite de prueba.');
 if(command.kind==='extraordinary'&&delta<=0)throw Error('Ingreso sin incremento físico.');
 if(command.kind==='use'&&delta!==-quantity)throw Error('Descuento físico inconsistente; no se registró.');
 const newMovement:StockMovement={
  id:command.id,lotId:before.id,code:before.code,name:before.name,unit:before.catalogUnit,at:command.at,
  kind:command.kind,description:command.description.trim(),quantity,
  sealedAdded,looseAdded,openedNewContainer,excelQuantity,physicalChange:delta,before,after,
  ...(command.dispenseRef?{dispenseRef:command.dispenseRef}:{})
 };
 const next=[...lots];next[index]=after;
 return {lots:next,movements:[...movements,newMovement]};
}

/** FEFO ordering, expired lots excluded; products without known expiration come last. */
export function suggestFEFOLot(lots:StockLot[],code:string,at:number=Date.now()):StockLot|undefined{
 const today=peruStockDate(at);
 return lots.filter(x=>x.code===code&&countPhysicalUnits(x)>0&&(!x.expires||x.expires>=today))
 .sort((a,b)=>(a.expires||'9999-12-31').localeCompare(b.expires||'9999-12-31')||a.id.localeCompare(b.id))[0];
}

/** Public API cannot emit an incomplete multi-lot group. */
export function postStockMovement(ledger:StockLedger,command:StockCommand):StockLedger{
 return postStockMovementInternal(ledger,command);
}

/** All parts succeed or none is exposed. Intended for a single saved attention item. */
export function postStockMovementsBatch(ledger:StockLedger,commands:StockCommand[]):StockLedger{
 if(!commands.length)throw Error('Entrega multilote sin movimientos.');
 validateStockLedger(ledger);
 let next=ledger;
 for(const command of commands)next=postStockMovementInternal(next,command,true);
 return validateStockLedger(next);
}
