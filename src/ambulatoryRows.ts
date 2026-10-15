/** Read-only export. Never infer R from clinical quantities or alter stock. */
import products from './products.json';
import template from './ambulatoryTemplate.json';
import {validDanperWorksite} from './danperWorksites';
import {validateStockLedger,postStockMovement,type StockLedger,type StockMovement} from './kardexMovements';
import {type CatalogMappingEvent,type DeliveryIncident,validateMappingEvents,validateDeliveryIncidents} from './reconciliationRules';
import {procedureDetail} from './procedureRules';
import {isReviewedAssociation} from './reviewedKardexAssociations';
export type ExportVisit={
 id:string;status:'draft'|'saved';date:string;time:string;
 worker:{dni:string;name:string;area:string;labor:string;sex:string;age:string|number;ubigeo:string;site?:string};
 category:string;system:string;segment:string;diagnosis:string;
 items:{id:string;code:string;name:string;unit:string;quantity:number;procedure:string}[];
 permission:string;workStatus:string;permissionTime:string;blueBandage:boolean;returned:boolean;photoSent:boolean;
 responsible:string;responsibleDni:string;standaloneProcedures?:string[];
};
export type ExportValue=string|number;
export type ExportLine={id:string;cells:ExportValue[]};
export type ExportPlan={lines:ExportLine[];warnings:string[];blockers:string[];start:string;end:string;visits:number;linkedDeliveries:number};
export type ExportOptions={subdivision?:string;perVisitSubdivision?:boolean;mappings?:CatalogMappingEvent[];incidents?:DeliveryIncident[]};
const productMap=new Map(products.map(p=>[p.code,p]));
const frequencies=['PRIMERA','SEGUNDA','TERCERA','CUARTA','QUINTA'];
export function validExportDate(v:string):boolean{
 if(!/^\d{4}-\d{2}-\d{2}$/.test(v)||v<'1900-03-01'||v>'9999-12-31')return false;
 const d=new Date(v+'T00:00:00Z');return Number.isFinite(d.getTime())&&d.toISOString().slice(0,10)===v;
}
export function excelDate(v:string):number{
 if(!validExportDate(v))throw Error('Fecha de atención inválida.');
 return (Date.parse(v+'T00:00:00Z')-Date.UTC(1899,11,30))/86400000;
}
function excelTime(v:string,optional=false):ExportValue{
 if(optional&&v==='')return '';
 if(!/^([01]\d|2[0-3]):[0-5]\d$/.test(v))throw Error('Hora de atención o permiso inválida.');
 const [h,m]=v.split(':').map(Number);return (h*60+m)/1440;
}
function auditedQuantity(m:StockMovement):number{
 if(m.kind!=='use'||!m.dispenseRef)throw Error('El movimiento no es una entrega confirmada.');
 // Replay on a disposable state to validate R=1/0 and both lot snapshots.
 const replay=postStockMovement({lots:[m.before],movements:[]},{id:m.id,lotId:m.lotId,at:m.at,kind:'use',description:m.description,quantity:m.quantity,allowOpen:m.openedNewContainer,dispenseRef:m.dispenseRef}).movements[0];
 if(JSON.stringify(replay.after)!==JSON.stringify(m.after)||replay.excelQuantity!==m.excelQuantity||replay.physicalChange!==m.physicalChange||m.sealedAdded!==0||m.looseAdded!==0)
  throw Error('Cantidad R o apertura incompatible con la entrega auditada.');
 return m.excelQuantity;
}
export function buildAmbulatoryRows(visits:ExportVisit[],ledger:StockLedger,start:string,end:string,options:ExportOptions={}):ExportPlan{
 if(!validExportDate(start)||!validExportDate(end)||start>end)throw Error('Intervalo de fechas inválido.');
 const valid=validateStockLedger(ledger);
 validateMappingEvents(options.mappings||[]);const incidents=validateDeliveryIncidents(options.incidents||[]);
 const selected=visits.filter(v=>v.status==='saved'),seen=new Set<string>();
 for(const a of selected){
  if(!a.id?.trim()||seen.has(a.id))throw Error('Atención duplicada o sin identificador.');seen.add(a.id);
  // Invalid dates must not disappear outside the interval by string comparison.
  if(!validExportDate(a.date))throw Error('Atención guardada con fecha inválida.');
 }
 const ordered=selected.filter(v=>v.date>=start&&v.date<=end).sort((a,b)=>a.date.localeCompare(b.date)||a.time.localeCompare(b.time)||a.id.localeCompare(b.id));
 const lines:ExportLine[]=[],warnings:string[]=[],blockers:string[]=[];
 let linkedDeliveries=0;
 const frequencyCount=new Map<string,number>(),deliveryMap=new Map<string,StockMovement>();
 for(const m of valid.movements)if(m.dispenseRef)deliveryMap.set(JSON.stringify([m.dispenseRef.attentionId,m.dispenseRef.itemId]),m);
 const subdivision=options.subdivision||'';
 const perVisitSubdivision=options.perVisitSubdivision===true;
 if(perVisitSubdivision&&subdivision)throw Error('No combines una sede fija con el modo de ambas sedes.');
 if(subdivision&&!validDanperWorksite(subdivision))throw Error('Solo se admiten las dos sedes verificadas.');
 if(!subdivision&&!perVisitSubdivision&&ordered.length)blockers.push('Selecciona la subdivisión de estas atenciones para completar A y C.');
 for(const a of ordered){
  if(!a.worker||!/^\d{8}$/.test(a.worker.dni)||!a.worker.name?.trim()||!a.diagnosis?.trim())throw Error('Atención con datos obligatorios incompletos.');
  const rowSubdivision=perVisitSubdivision?(a.worker.site||''):subdivision;
  if(perVisitSubdivision&&!validDanperWorksite(rowSubdivision))blockers.push('Atención sin sede oficial: '+a.id.slice(0,8));
  if(!perVisitSubdivision&&subdivision&&a.worker.site&&a.worker.site!==subdivision)
   throw Error('La atención pertenece a otra sede y no puede mezclarse en este reporte.');
  const time=excelTime(a.time),permissionTime=excelTime(a.permissionTime,true);
  if(a.responsibleDni&&!/^\d{8}$/.test(a.responsibleDni))throw Error('DNI de responsable inválido.');
  if(!Array.isArray(a.items))throw Error('Artículos de atención incompatibles.');
  const key=JSON.stringify([a.date,a.worker.dni]),count=(frequencyCount.get(key)||0)+1;frequencyCount.set(key,count);
  if(count>5)warnings.push('Más de cinco atenciones en un día: frecuencia marcada REVISAR.');
  const itemIds=new Set<string>();
  for(const item of a.items.length?a.items:[null]){
   let code:ExportValue='',name:ExportValue='',quantity:ExportValue='',procedure='';
   if(item){
    if(!item.id?.trim()||itemIds.has(item.id))throw Error('Artículo duplicado o sin identificador.');itemIds.add(item.id);
    if(!/^[0-9]+$/.test(item.code))throw Error('Código no numérico excluido.');
    const p=productMap.get(item.code);
    if(!p||p.name.trim()!==item.name?.trim()||p.unit.trim()!==item.unit?.trim())throw Error('Material o unidad no verificados: '+item.code);
    if(!Number.isInteger(item.quantity)||item.quantity<=0||!item.procedure?.trim())throw Error('Cantidad clínica o procedimiento inválido.');
    code=p.code;name=p.name;procedure=item.procedure;
    const m=deliveryMap.get(JSON.stringify([a.id,item.id]));
    if(!m)blockers.push('Cantidad sin entrega conciliada: '+a.id.slice(0,8)+' / '+item.code);
    else{
     const ref=m.dispenseRef!;
     if(ref.clinicalCode!==item.code||ref.clinicalName.trim()!==item.name.trim()||ref.clinicalUnit.trim()!==item.unit.trim()||ref.clinicalQuantity!==item.quantity)
      throw Error('La atención fue modificada después de confirmar la entrega.');
     // The official Indicator code and the nursing Kardex stock code are
     // independent catalogs. Only explicit user-reviewed pairs are valid.
     if(m.code!==item.code&&!isReviewedAssociation(item.code,m.code))
      blockers.push('Falta correspondencia aprobada entre el material y el lote: '+item.code);
     if(incidents.some(i=>i.movementId===m.id))blockers.push('Entrega con devolución o discrepancia pendiente de conciliación: '+item.code);
     quantity=auditedQuantity(m);linkedDeliveries++;
    }
   }else procedure=(a.standaloneProcedures||[]).join(' / ');
   const rawAge=String(a.worker.age),age=Number(rawAge);
   const cells:ExportValue[]=[rowSubdivision,a.worker.area||'','','',a.worker.labor||'',excelDate(a.date),time,
    a.worker.dni,a.worker.name,/^\d{1,3}$/.test(rawAge)&&age<=120?age:'',a.worker.sex||'',a.worker.ubigeo||'',
    a.category||'',a.system||'',a.segment||'',code,name,quantity,count<=5?frequencies[count-1]:'REVISAR',procedure,
    item?procedureDetail(procedure):'',a.permission||'',a.workStatus||'',permissionTime,a.blueBandage?'SI':'NO',a.returned?'SI':'NO',a.photoSent?'SI':'NO',a.responsibleDni||'',a.responsible||'',a.diagnosis];
   if(cells.length!==30)throw Error('El indicador debe tener exactamente 30 columnas.');
   if(cells.some(v=>typeof v==='string'&&(v.length>32767||/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(v))))throw Error('Texto incompatible con Excel.');
   lines.push({id:JSON.stringify([a.id,item?.id||null]),cells});
   if(lines.length>10000)throw Error('El prototipo admite hasta 10 000 filas por exportación.');
  }
 }
 warnings.push('CONTEO, INGRESOS y saldos: pendientes de conciliación. Solo los consumos confirmados corresponden al período.');
 return {lines,warnings:[...new Set(warnings)],blockers:[...new Set(blockers)],start,end,visits:ordered.length,linkedDeliveries};
}
