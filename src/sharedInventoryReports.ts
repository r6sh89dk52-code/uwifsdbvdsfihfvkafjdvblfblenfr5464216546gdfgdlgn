/** v0.17 — one physical source for daily Kardex and the 9th-to-8th Indicator.
 * Does not create a second stock ledger or infer unknown/uncertified conversions.
 */
import products from './products.json';
import {reviewedAssociations} from './reviewedKardexAssociations';
import {countPhysicalUnits,type StockLot} from './inventoryRules';
import {validateStockLedger,type StockLedger,type StockMovement} from './kardexMovements';
import {validExportDate,type ExportPlan} from './ambulatoryRows';
import {type MaterialCutoff,type ReconciliationEvent,type ReconciliationPlan} from './ambulatoryReconciliation';

export type MonthlyPeriod={start:string;end:string;label:string};
const official=new Map(products.map(p=>[p.code,p]));
const grouped=new Map<string,string[]>();
for(const p of reviewedAssociations)grouped.set(p.clinicalCode,[...(grouped.get(p.clinicalCode)||[]),p.kardexCode]);

export function reportMonth(date:string):MonthlyPeriod{
 const match=/^(\d{4})-(\d{2})$/.exec(date);
 if(!match)throw Error('Mes de informe inválido. Formato AAAA-MM.');
 const year=Number(match[1]),month=Number(match[2]);
 if(year<2020||year>2099||month<1||month>12)throw Error('Mes de informe fuera de rango.');
 const next=month===12?[year+1,1]:[year,month+1];
 const pad=(v:number)=>String(v).padStart(2,'0');
 const start=year+'-'+pad(month)+'-09',end=next[0]+'-'+pad(next[1])+'-08';
 return{start,end,label:'09/'+pad(month)+'/'+year+' al 08/'+pad(next[1])+'/'+next[0]};
}
export function currentReportMonth(now=new Date()):string{
 const fmt=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(now);
 const value=(t:string)=>fmt.find(x=>x.type===t)?.value||'';
 const year=Number(value('year')),month=Number(value('month')),day=Number(value('day'));
 if(day>=9)return year+'-'+String(month).padStart(2,'0');
 return (month===1?year-1:year)+'-'+String(month===1?12:month-1).padStart(2,'0');
}
export function limaDate(at:number):string{
 const fmt=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(at));
 const v=(name:string)=>fmt.find(p=>p.type===name)?.value||'';
 return v('year')+'-'+v('month')+'-'+v('day');
}
function physical(l:StockLot,unit:string):number|null{
 const stock=l.catalogUnit.toUpperCase();
 if(unit==='UND'||unit==='TBL'||unit==='PAR'){
  if(unit==='PAR'?stock!=='PAR':stock!=='UND'&&stock!=='TBL')return null;
  return countPhysicalUnits(l);
 }
 const kinds:Record<string,string[]>={CJA:['caja'],FCO:['frasco'],PAQ:['paquete']};
 if(kinds[unit] && kinds[unit].includes(l.container) && l.unitsPerContainer>1)
  return l.sealedContainers; // opened packages were already issued as R=1
 return null;
}
function timeline(lot:StockLot,moves:StockMovement[],day:string,atEnd:boolean){
 const history=moves.filter(m=>m.lotId===lot.id).sort((a,b)=>a.at-b.at);
 const original=history[0]?.before||lot;
 if(limaDate(original.updatedAt)>day)return null; // no invented pre-registration stock
 let result=original;
 for(const m of history){
  const key=limaDate(m.at);
  if(key<day||(atEnd&&key===day))result=m.after;
 }
 return result;
}
const rnd=(x:number)=>Math.round((x+Number.EPSILON)*1000)/1000;
function consumedByCode(plan:ExportPlan){
 const counts=new Map<string,number>();
 for(const row of plan.lines){
  const code=row.cells[15],qty=row.cells[17];
  if(typeof code==='string'&&code&&typeof qty==='number')
   counts.set(code,rnd((counts.get(code)||0)+qty));
 }
 return counts;
}
export function sharedMonthlyReconciliation(ledger:StockLedger,plan:ExportPlan):ReconciliationPlan{
 if(!validExportDate(plan.start)||!validExportDate(plan.end)||plan.start>plan.end)throw Error('Período del informe inválido.');
 const check=validateStockLedger(ledger);
 const today=limaDate(Date.now());
 const periodClosed=plan.end<=today;
 const consumption=consumedByCode(plan),byCode:Record<string,MaterialCutoff>={},warnings:string[]=[];
 for(const p of products)byCode[p.code]={code:p.code,consumed:consumption.get(p.code)||0,receiptDetails:[]};
 let openingConfirmed=0,receiptsConfirmed=0;
 for(const [code,codes]of grouped){
  const meta=official.get(code);
  if(!meta)throw Error('Código oficial no registrado: '+code);
  const lots=check.lots.filter(l=>codes.includes(l.code));
  if(!lots.length||plan.start>today)continue; // never convert absence to a confirmed zero
  let opening=0,closing=0,valid=true;
  for(const l of lots){
   const initial=timeline(l,check.movements,plan.start,false);
   const final=timeline(l,check.movements,plan.end,true);
   if(!initial||!final){valid=false;warnings.push(meta.name+': stock inicial desconocido antes del alta del lote.');break}
   const a=physical(initial,meta.unit),b=physical(final,meta.unit);
   if(a===null||b===null){valid=false;warnings.push(meta.name+': unidad o presentación no compatible con '+meta.unit+'.');break}
   opening+=a;closing+=b;
  }
  if(!valid)continue;
  const changes=check.movements.filter(m=>codes.includes(m.code)&&limaDate(m.at)>=plan.start&&limaDate(m.at)<=plan.end);
  if(changes.some(m=>m.kind==='adjustment')){
   warnings.push(meta.name+': existen ajustes físicos auditados; revisar antes de cerrar el período.');
   continue;
  }
  if(changes.some(m=>m.kind==='use'&&!m.dispenseRef)){
   warnings.push(meta.name+': consumo manual no vinculado a una atención confirmada.');
   continue;
  }
  const receipts:ReconciliationEvent[]=[];
  for(const m of changes.filter(m=>m.kind==='extraordinary')){
   const amount=meta.unit==='UND'||meta.unit==='TBL'||meta.unit==='PAR'?m.physicalChange:m.sealedAdded;
   if((meta.unit==='CJA'||meta.unit==='FCO'||meta.unit==='PAQ')&&m.looseAdded>0){
    valid=false;warnings.push(meta.name+': ingreso mixto requiere comprobar unidades.');break;
   }
   if(!Number.isInteger(amount)||amount<=0){valid=false;warnings.push(meta.name+': ingreso con unidad no verificable.');break}
   receipts.push({id:m.id,kind:'receipt',subdivision:'',code,date:limaDate(m.at),at:m.at,
     quantity:amount,reason:m.description,document:'',expires:m.after.expires,periodEnd:'',voidOf:''});
  }
  if(!valid)continue;
  if(receipts.length>4){warnings.push(meta.name+': más de cuatro ingresos; el formato oficial solo admite cuatro.');continue}
  const received=receipts.reduce((n,m)=>n+m.quantity,0),issued=consumption.get(code)||0;
  // Do not report a false closing balance if confirmed visits and stock movement disagree.
  if(periodClosed&&rnd(opening+received-issued)!==rnd(closing)){
   warnings.push(meta.name+': el saldo físico no coincide con las entregas confirmadas en CONSUMOS; revisar.');
   continue;
  }
  const cutoff=byCode[code];
  cutoff.opening=rnd(opening);
  if(periodClosed){
   cutoff.receipts=rnd(received);
   cutoff.receiptDetails=receipts;
   cutoff.closing=rnd(closing);
  }
  // A future month's remaining movements are unknowable.
  // Its report can be drafted but cannot claim a verified final/zero receipts.
  openingConfirmed++;
  receiptsConfirmed+=receipts.length;
 }
 if(!periodClosed)warnings.push('Período mensual todavía en curso; ingresos y saldos finales permanecen pendientes del cierre.');
 if(openingConfirmed<products.length)warnings.push('Inventario pendiente para '+(products.length-openingConfirmed)+' de los 432 códigos oficiales; sus saldos quedan vacíos.');
 warnings.push('CONTEO se deja vacío hasta registrar un recuento físico independiente: no equivale al saldo calculado.');
 return {byCode,openingConfirmed,countConfirmed:0,receiptsConfirmed,reviewed:false,warnings};
}
