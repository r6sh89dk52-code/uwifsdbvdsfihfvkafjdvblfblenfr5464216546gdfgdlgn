/** Stage B2: manual, explicit linking of a SAVED demo attention line to physical Kardex.
 * No automatic name matching, dispensing, dose inference or implicit unit conversions.
 */
import {postStockMovement,type StockLedger,type DispenseRef} from './kardexMovements';
import {countPhysicalUnits,type StockLot} from './inventoryRules';

export type ClinicalLine={id:string;code:string;name:string;quantity:number;unit:string};
export type SavedClinicalAttention={id:string;status:'saved'|'draft';items:ClinicalLine[]};
export type ConfirmedDelivery={itemId:string;lotId:string;physicalQuantity:number;confirmIdentity:boolean;confirmUnits:boolean;confirmDelivery:boolean;openNewContainer:boolean;timestamp:number};

export const dispenseMovementId=(attentionId:string,itemId:string)=>'ATT:'+attentionId+':ITEM:'+itemId;
export function alreadyDispensed(ledger:StockLedger,attentionId:string,itemId:string):boolean{
 const id=dispenseMovementId(attentionId,itemId);
 return ledger.movements.some(m=>m.id===id||(m.dispenseRef?.attentionId===attentionId&&m.dispenseRef.itemId===itemId));
}
export function availableLots(lots:StockLot[],code:string,at:number=Date.now()):StockLot[]{
 const day=new Date(at).toISOString().slice(0,10);
 return lots.filter(l=>l.code===code&&countPhysicalUnits(l)>0&&(!l.expires||l.expires>=day))
 .sort((a,b)=>(a.expires||'9999-12-31').localeCompare(b.expires||'9999-12-31')||a.id.localeCompare(b.id));
}
export function postConfirmedAttentionDelivery(ledger:StockLedger,attention:SavedClinicalAttention,confirmation:ConfirmedDelivery):StockLedger{
 if(!attention||attention.status!=='saved'||!attention.id?.trim())throw Error('La entrega requiere una atención ya guardada.');
 const item=attention.items.find(i=>i.id===confirmation.itemId);
 if(!item||!item.id?.trim()||!item.code?.trim()||!item.name?.trim()||!item.unit?.trim()||
  !Number.isInteger(item.quantity)||item.quantity<=0)
  throw Error('Producto de atención inválido: confirma primero el registro clínico.');
 if(alreadyDispensed(ledger,attention.id,item.id))
  throw Error('Este producto ya tiene una entrega vinculada. No se descontará por segunda vez.');
 if(confirmation.confirmIdentity!==true||confirmation.confirmUnits!==true||confirmation.confirmDelivery!==true)
  throw Error('Confirma producto/presentación, cantidad física y entrega antes de descontar.');
 if(!Number.isSafeInteger(confirmation.timestamp)||confirmation.timestamp<=0)
  throw Error('Fecha de entrega inválida.');
 const lot=ledger.lots.find(l=>l.id===confirmation.lotId);
 if(!lot)throw Error('Selecciona un lote existente.');
 if(!availableLots(ledger.lots,lot.code,confirmation.timestamp).some(l=>l.id===lot.id))
  throw Error('Lote vencido o sin existencias.');
 if(typeof confirmation.physicalQuantity!=='number'||!Number.isFinite(confirmation.physicalQuantity)||
   confirmation.physicalQuantity<=0||confirmation.physicalQuantity>10000000)
  throw Error('Cantidad física inválida.');
 // Clinical quantities can be tablets or packs. Physical quantity must be entered explicitly.
 const ref:DispenseRef={
  attentionId:attention.id,itemId:item.id,clinicalCode:item.code,clinicalName:item.name,
  clinicalUnit:item.unit,clinicalQuantity:item.quantity,confirmedAt:confirmation.timestamp
 };
 return postStockMovement(ledger,{
  id:dispenseMovementId(attention.id,item.id),lotId:lot.id,kind:'use',at:confirmation.timestamp,
  quantity:confirmation.physicalQuantity,allowOpen:confirmation.openNewContainer,
  description:'Entrega ficticia vinculada a atención',dispenseRef:ref
 });
}
