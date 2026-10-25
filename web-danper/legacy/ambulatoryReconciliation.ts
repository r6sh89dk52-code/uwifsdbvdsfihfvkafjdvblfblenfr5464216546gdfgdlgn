/** DANPER v0.16 — independent audited cutoffs for the 432 official materials.
 * Not the nursing Kardex (98 + 6). Does not mutate visits or dispensing.
 * All values are demo-only and recorded in official issue units (UND/CJA/FCO).
 */
import products from './products.json';
import {type ExportPlan,validExportDate} from './ambulatoryRows';
export type ReconciliationKind='opening'|'receipt'|'count'|'review'|'void';
export type ReconciliationEvent={
 id:string;kind:ReconciliationKind;subdivision:string;code:string;
 date:string;at:number;quantity:number;reason:string;
 document:string;expires:string;periodEnd:string;voidOf:string;
};
export type MaterialCutoff={
 code:string;opening?:number;receipts?:number;consumed:number;
 closing?:number;count?:number;difference?:number;
 receiptDetails:ReconciliationEvent[];
};
export type ReconciliationPlan={
 byCode:Record<string,MaterialCutoff>;
 openingConfirmed:number;countConfirmed:number;receiptsConfirmed:number;
 reviewed:boolean;warnings:string[];
};
const catalog=new Map(products.map(p=>[p.code,p]));
const allowed:ReconciliationKind[]=['opening','receipt','count','review','void'];
const maxEvents=1200, limit=10000000;
function text(value:unknown,min:number,max:number,label:string){
 if(typeof value!=='string'||value.trim().length<min||value.length>max)
  throw Error(label+' inválido.');
 return value.trim();
}
export function validateReconciliationEvents(input:unknown):ReconciliationEvent[]{
 if(!Array.isArray(input)||input.length>maxEvents)throw Error('La conciliación contiene demasiados registros o está dañada.');
 const ids=new Set<string>(),current=new Map<string,ReconciliationEvent>(),voided=new Set<string>();
 const all:ReconciliationEvent[]=[];
 for(const x of input){
  if(!x||typeof x!=='object'||Array.isArray(x))throw Error('Evento de conciliación inválido.');
  const raw=x as ReconciliationEvent;
  const id=text(raw.id,1,120,'Identificador');
  if(ids.has(id))throw Error('Evento de conciliación duplicado.');
  if(!allowed.includes(raw.kind))throw Error('Tipo de conciliación no admitido.');
  const subdivision=text(raw.subdivision,2,120,'Subdivisión');
  if(!validExportDate(raw.date))throw Error('Fecha de conciliación inválida.');
  if(!Number.isSafeInteger(raw.at)||raw.at<=0)throw Error('Hora del registro inválida.');
  const reason=text(raw.reason,8,240,'Justificación');
  const code=raw.code||'',document=raw.document||'',expires=raw.expires||'',
    periodEnd=raw.periodEnd||'',voidOf=raw.voidOf||'';
  if(typeof code!=='string'||typeof document!=='string'||typeof expires!=='string'||
    typeof periodEnd!=='string'||typeof voidOf!=='string')throw Error('Datos de conciliación incompatibles.');
  if(typeof raw.quantity!=='number'||!Number.isFinite(raw.quantity)||raw.quantity<0||raw.quantity>limit)
   throw Error('Cantidad de conciliación fuera de rango.');
  if(raw.kind==='opening'||raw.kind==='receipt'||raw.kind==='count'){
   if(!/^\d+$/.test(code)||!catalog.has(code))throw Error('Solo se admiten materiales oficiales numéricos.');
   if(!Number.isInteger(raw.quantity))throw Error('Las existencias en unidad oficial deben ser enteras.');
   if(raw.kind==='receipt'){
    if(raw.quantity===0)throw Error('Un ingreso confirmado debe tener cantidad positiva.');
    text(document,3,100,'Documento de ingreso');
    if(expires&&!validExportDate(expires))throw Error('Vencimiento del ingreso inválido.');
   }else if(document||expires)throw Error('Un conteo no puede contener datos de ingreso.');
   if(periodEnd||voidOf)throw Error('Campos de corte incorrectos.');
  }else if(raw.kind==='review'){
   if(code||document||expires||voidOf||raw.quantity!==0||!validExportDate(periodEnd)||periodEnd<raw.date)
    throw Error('Cierre de ingresos inválido.');
  }else{
   if(code||document||expires||periodEnd||raw.quantity!==0||!voidOf)
    throw Error('Anulación inválida.');
   const previous=current.get(voidOf);
   if(!previous||previous.kind==='void'||voided.has(voidOf)||previous.subdivision!==subdivision||raw.at<previous.at)
    throw Error('No se puede anular un registro inexistente o ya anulado.');
   voided.add(voidOf);
  }
  const e:ReconciliationEvent={id,kind:raw.kind,subdivision,code,date:raw.date,at:raw.at,
   quantity:raw.quantity,reason,document,expires,periodEnd,voidOf};
  ids.add(id);current.set(id,e);all.push(e);
 }
 const active=all.filter(e=>e.kind!=='void'&&!voided.has(e.id));
 const uniques=new Set<string>();
 for(const e of active){
  let key='';
  if(e.kind==='opening'||e.kind==='count')key=[e.subdivision,e.kind,e.date,e.code].join('|');
  if(e.kind==='review')key=[e.subdivision,'review',e.date,e.periodEnd].join('|');
  if(e.kind==='receipt')key=[e.subdivision,'receipt',e.date,e.code,e.document.toUpperCase()].join('|');
  if(key&&uniques.has(key))throw Error('Recuento, ingreso o cierre de período repetido.');
  uniques.add(key);
 }
 const reviews=active.filter(e=>e.kind==='review');
 for(const receipt of active.filter(e=>e.kind==='receipt')){
  if(reviews.some(r=>r.subdivision===receipt.subdivision&&receipt.date>=r.date&&receipt.date<=r.periodEnd&&receipt.at>r.at))
   throw Error('Un ingreso posterior al cierre exige anular el cierre y volver a revisarlo.');
 }
 return all;
}
export function appendReconciliationEvent(source:ReconciliationEvent[],event:ReconciliationEvent):ReconciliationEvent[]{
 return validateReconciliationEvents([...source,event]);
}
export function activeReconciliationEvents(source:ReconciliationEvent[]):ReconciliationEvent[]{
 const events=validateReconciliationEvents(source);
 const annulled=new Set(events.filter(e=>e.kind==='void').map(e=>e.voidOf));
 return events.filter(e=>e.kind!=='void'&&!annulled.has(e.id));
}
export function reconcileAmbulatoryReport(plan:ExportPlan,source:ReconciliationEvent[],subdivision:string):ReconciliationPlan{
 if(!validExportDate(plan.start)||!validExportDate(plan.end)||plan.start>plan.end)throw Error('Período inválido.');
 if(!subdivision.trim())throw Error('Selecciona una subdivisión antes de conciliar.');
 const events=activeReconciliationEvents(source).filter(e=>e.subdivision===subdivision);
 const review=events.find(e=>e.kind==='review'&&e.date===plan.start&&e.periodEnd===plan.end);
 const byCode:Record<string,MaterialCutoff>={},warnings:string[]=[];
 let openingConfirmed=0,countConfirmed=0,receiptsConfirmed=0;
 const consumption=new Map<string,number>();
 for(const line of plan.lines){
  const code=line.cells[15],q=line.cells[17];
  if(typeof code==='string'&&code!==''&&typeof q==='number'){
   if(!catalog.has(code)||!Number.isInteger(q)||q<0)throw Error('Consumos no conciliados o códigos inválidos.');
   consumption.set(code,(consumption.get(code)||0)+q);
  }
 }
 for(const p of products){
  const opening=events.find(e=>e.kind==='opening'&&e.code===p.code&&e.date===plan.start);
  const count=events.find(e=>e.kind==='count'&&e.code===p.code&&e.date===plan.end);
  const receipts=events.filter(e=>e.kind==='receipt'&&e.code===p.code&&e.date>=plan.start&&e.date<=plan.end)
     .sort((a,b)=>a.date.localeCompare(b.date)||a.at-b.at||a.id.localeCompare(b.id));
  if(receipts.length>4)throw Error('Más de cuatro ingresos para '+p.name+'. La hoja original admite solo cuatro; revisa el período.');
  const consumed=consumption.get(p.code)||0;
  const total=review?receipts.reduce((n,e)=>n+e.quantity,0):undefined;
  const closing=opening&&total!==undefined?opening.quantity+total-consumed:undefined;
  if(closing!==undefined&&closing<0)throw Error('Saldo final negativo para '+p.name+'. Verifica el stock inicial y las entregas.');
  const difference=closing!==undefined&&count?closing-count.quantity:undefined;
  byCode[p.code]={code:p.code,consumed,receiptDetails:receipts,
   ...(opening?{opening:opening.quantity}:{}),
   ...(total!==undefined?{receipts:total}:{}),
   ...(closing!==undefined?{closing}:{}),
   ...(count?{count:count.quantity}:{}),
   ...(difference!==undefined?{difference}:{})};
  if(opening)openingConfirmed++;
  if(count)countConfirmed++;
  receiptsConfirmed+=receipts.length;
 }
 if(!review)warnings.push('Ingresos no cerrados para el período: ninguna ausencia puede interpretarse como cero.');
 if(openingConfirmed<products.length)warnings.push('Stock inicial pendiente para '+(products.length-openingConfirmed)+' materiales.');
 if(countConfirmed<products.length)warnings.push('Recuento final pendiente para '+(products.length-countConfirmed)+' materiales.');
 return{byCode,openingConfirmed,countConfirmed,receiptsConfirmed,reviewed:!!review,warnings};
}

