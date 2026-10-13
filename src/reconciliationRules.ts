/** DANPER v0.13. Demo-only, append-only catalog evidence and delivery incidents.
 * A return never automatically restores available stock; a physical correction
 * must be processed separately through an audited inventory adjustment.
 */
import {kardexCatalog,legacyDonatedCatalog} from './kardexCatalog';
import {type StockLedger} from './kardexMovements';
import {postConfirmedAttentionDelivery,type ConfirmedDelivery,type SavedClinicalAttention} from './attentionKardex';
import {reviewedAssociationsFor} from './reviewedKardexAssociations';

export type MappingKind='verify'|'revoke';
export type CatalogMappingEvent={
 id:string;kind:MappingKind;clinicalCode:string;clinicalName:string;
 kardexCode:string;kardexName:string;reason:string;at:number;
};
export type IncidentKind='returned'|'discrepancy';
export type DeliveryIncident={
 id:string;movementId:string;attentionId:string;itemId:string;
 kind:IncidentKind;quantity:number;reason:string;at:number;stockRestored:false;
};
const maxRecords=500;
function validText(value:unknown,min:number,max:number,label:string){
 if(typeof value!=='string'||value.trim().length<min||value.length>max)
  throw Error(label+' inválido (de '+min+' a '+max+' caracteres).');
 return value.trim();
}
function validTime(time:unknown){if(!Number.isSafeInteger(time)||Number(time)<=0)throw Error('Marca de tiempo inválida.');return time as number}
export function validateMappingEvents(input:unknown):CatalogMappingEvent[]{
 if(!Array.isArray(input)||input.length>maxRecords)throw Error('Historial de equivalencias incompatible.');
 const ids=new Set<string>();
 return input.map(raw=>{
  if(!raw||typeof raw!=='object'||Array.isArray(raw))throw Error('Equivalencia dañada.');
  const e=raw as CatalogMappingEvent;
  if(!['verify','revoke'].includes(e.kind)||typeof e.id!=='string'||!e.id.trim()||ids.has(e.id))
   throw Error('Evento de equivalencia inválido o duplicado.');
  const clinicalCode=validText(e.clinicalCode,1,64,'Código de atención');
  const clinicalName=validText(e.clinicalName,1,240,'Producto de atención');
  const kardexCode=validText(e.kardexCode,1,64,'Código Kardex');
  const kardexName=validText(e.kardexName,1,240,'Producto Kardex');
  const reason=validText(e.reason,8,240,'Motivo');
  const catalogItem=[...kardexCatalog,...legacyDonatedCatalog].find(p=>p.id===kardexCode);
  if(!catalogItem||catalogItem.name!==kardexName)throw Error('El producto Kardex no existe en el catálogo oficial.');
  ids.add(e.id);
  return{id:e.id,kind:e.kind,clinicalCode,clinicalName,kardexCode,kardexName,reason,at:validTime(e.at)};
 });
}
export function activeCatalogMapping(events:CatalogMappingEvent[],clinicalCode:string):CatalogMappingEvent|undefined{
 const match=[...events].reverse().find(e=>e.clinicalCode===clinicalCode);
 return match?.kind==='verify'?match:undefined;
}
export function recordCatalogMapping(events:CatalogMappingEvent[],request:CatalogMappingEvent):CatalogMappingEvent[]{
 const previous=validateMappingEvents(events);
 const proposed=validateMappingEvents([request])[0];
 if(proposed.kind==='verify'&&!kardexCatalog.some(p=>p.id===proposed.kardexCode))throw Error('Donados excluidos de nuevas equivalencias.');
 if(previous.length>=maxRecords||previous.some(e=>e.id===proposed.id))throw Error('Equivalencia duplicada o límite alcanzado.');
 const prior=activeCatalogMapping(previous,proposed.clinicalCode);
 if(proposed.kind==='revoke'){
  if(!prior)throw Error('No hay una equivalencia vigente para revocar.');
  if(prior.kardexCode!==proposed.kardexCode)throw Error('La revocación no corresponde a la equivalencia vigente.');
 }else if(prior?.kardexCode===proposed.kardexCode){
  throw Error('La equivalencia ya está verificada. No es necesario crear otra.');
 }
 return [...previous,proposed];
}
export function validateDeliveryIncidents(input:unknown):DeliveryIncident[]{
 if(!Array.isArray(input)||input.length>maxRecords)throw Error('Historial de incidencias incompatible.');
 const ids=new Set<string>(),movements=new Set<string>();
 return input.map(raw=>{
  if(!raw||typeof raw!=='object'||Array.isArray(raw))throw Error('Incidencia dañada.');
  const i=raw as DeliveryIncident;
  if(!['returned','discrepancy'].includes(i.kind)||i.stockRestored!==false||
    typeof i.id!=='string'||!i.id.trim()||ids.has(i.id))throw Error('Incidencia inválida o duplicada.');
  const movementId=validText(i.movementId,1,200,'Movimiento vinculado');
  const attentionId=validText(i.attentionId,1,120,'Atención');
  const itemId=validText(i.itemId,1,120,'Artículo');
  const reason=validText(i.reason,8,240,'Motivo de incidencia');
  if(movements.has(movementId)||typeof i.quantity!=='number'||!Number.isFinite(i.quantity)||i.quantity<0||
    (i.kind==='returned'&&i.quantity<=0)||(i.kind==='discrepancy'&&i.quantity!==0))
    throw Error('Cantidad o movimiento duplicado en una incidencia.');
  ids.add(i.id);movements.add(movementId);
  return{id:i.id,movementId,attentionId,itemId,kind:i.kind,quantity:i.quantity,reason,at:validTime(i.at),stockRestored:false};
 });
}
export function recordDeliveryIncident(
 ledger:StockLedger,incidents:DeliveryIncident[],request:DeliveryIncident
):DeliveryIncident[]{
 const previous=validateDeliveryIncidents(incidents);
 const value=validateDeliveryIncidents([request])[0];
 if(previous.length>=maxRecords||previous.some(i=>i.id===value.id||i.movementId===value.movementId))
  throw Error('Esta entrega ya tiene una incidencia registrada.');
 const movement=ledger.movements.find(m=>m.id===value.movementId);
 if(!movement||movement.kind!=='use'||!movement.dispenseRef)
  throw Error('Solo se pueden registrar incidencias de entregas confirmadas desde una atención.');
 if(movement.dispenseRef.attentionId!==value.attentionId||movement.dispenseRef.itemId!==value.itemId)
  throw Error('La incidencia no coincide con la atención de origen.');
 if(value.kind==='returned'&&value.quantity>movement.quantity)
  throw Error('La cantidad devuelta no puede superar lo originalmente entregado.');
 if(value.at<movement.at)throw Error('La incidencia no puede ser anterior al movimiento.');
 return[...previous,value];
}
/** Every new attention-linked stock deduction must match the user-reviewed catalog.
 * Legacy manual mapping events are kept for history; they cannot authorize
 * an unreviewed product, nor pick one of two valves automatically.
 */
export function postDeliveryWithMapping(
 ledger:StockLedger,attention:SavedClinicalAttention,confirmation:ConfirmedDelivery,events:CatalogMappingEvent[]
):StockLedger{
 validateMappingEvents(events); // validates older history without using it as dispensing authorization
 const item=attention.items.find(i=>i.id===confirmation.itemId);
 if(!item)throw Error('Producto clínico no encontrado.');
 const lot=ledger.lots.find(l=>l.id===confirmation.lotId);
 const candidates=reviewedAssociationsFor(item.code);
 if(!candidates.length)throw Error('El material de la atención no tiene una correspondencia aprobada con el Kardex.');
 if(!lot)throw Error('Selecciona un lote real del Kardex.');
 const chosen=candidates.find(p=>p.kardexCode===lot.code);
 if(!chosen||chosen.kardexName!==lot.name||chosen.clinicalName!==item.name||chosen.clinicalUnit!==item.unit)
  throw Error('La selección no corresponde al producto y presentación verificados de esta atención.');
 if(!kardexCatalog.some(p=>p.id===lot.code&&p.name===lot.name))
  throw Error('Producto ausente del Kardex de Enfermería autorizado (98 productos).');
 return postConfirmedAttentionDelivery(ledger,attention,confirmation);
}
