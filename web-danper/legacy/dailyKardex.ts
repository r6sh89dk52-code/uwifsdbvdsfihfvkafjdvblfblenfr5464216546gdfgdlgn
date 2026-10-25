/** Kardex diario oficial: datos en unidades del formato, no mililitros para envases.
 * Un envase cerrado se descuenta al ABRIRLO; los usos posteriores del abierto
 * no descuentan otro envase en la columna G. El contenido físico queda en B1.
 */
import {kardexCatalog} from './kardexCatalog';
import {validateStockLedger,type StockLedger,type StockMovement} from './kardexMovements';
import {type StockLot,countPhysicalUnits} from './inventoryRules';
export type DailyRow={code:string;name:string;donated:boolean;stockKnown:boolean;initial:number;extraordinary:number;total:number;consumed:number;final:number;expiry:string;fs:number|null};
export type DailyReport={date:string;periodEnd?:string;rows:DailyRow[];warnings:string[];exportable:boolean};
const rnd=(x:number)=>Math.round((x+Number.EPSILON)*1000)/1000;
function dateOnly(t:number){
 const parts=new Intl.DateTimeFormat('en-US',{timeZone:'America/Lima',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date(t));
 const value=(type:string)=>parts.find(x=>x.type===type)?.value||'';
 return value('year')+'-'+value('month')+'-'+value('day');
}
// Official nursing count is by catalog U.M., not by the storage container.
 // A box of 20 UND tablets counts as 20 UND, not one issued CJA.
const packaged=(l:StockLot)=>!['UND','TBL','PAR'].includes(l.catalogUnit.trim().toUpperCase())&&
 (l.container!=='unidad'||l.unitsPerContainer!==1);
const reportBalance=(l:StockLot)=>packaged(l)?l.sealedContainers:countPhysicalUnits(l);
function dayMoves(moves:StockMovement[],date:string){return moves.filter(m=>dateOnly(m.at)===date)}
function stateAtEnd(lot:StockLot,moves:StockMovement[],date:string):StockLot{
 const after=moves.filter(m=>dateOnly(m.at)>date);
 return after.length?after[0].before:lot;
}
export function buildDailyReport(ledger:StockLedger,date:string,counts:Record<string,number>={}):DailyReport{
 if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||Number.isNaN(Date.parse(date)))throw Error('Fecha diaria inválida.');
 const valid=validateStockLedger(ledger);
 const warnings:string[]=[];
 const rows=kardexCatalog.map(p=>{
  const historic=valid.lots.filter(l=>l.code===p.id);
  const moves=valid.movements.filter(m=>m.code===p.id);
  const lots=historic.filter(l=>{
   const initial=moves.filter(m=>m.lotId===l.id).sort((a,b)=>a.at-b.at)[0]?.before||l;
   return dateOnly(initial.updatedAt)<=date;
  });
  const rowDay=dayMoves(moves,date);
  const stockKnown=lots.length>0;
  const kinds=[...new Set(lots.map(l=>packaged(l)?'envase':'unidad'))];
  if(kinds.length>1)warnings.push(p.name+': lotes con modos de conteo incompatibles');
  const initial=rnd(lots.reduce((n,l)=>{
   const all=moves.filter(m=>m.lotId===l.id);
   const day=dayMoves(all,date);
   const later=stateAtEnd(l,all,date);
   const before=day.length?day[0].before:later;
   return n+reportBalance(before);
  },0));
  const extraordinary=rnd(rowDay.filter(m=>m.kind==='extraordinary').reduce((n,m)=>{
   return n+(packaged(m.before)?m.sealedAdded:m.physicalChange);
  },0));
  const consumed=rnd(rowDay.filter(m=>m.kind==='use').reduce((n,m)=>
    n+(packaged(m.before)?m.excelQuantity:m.quantity),0));
  const adjustments=rowDay.filter(m=>m.kind==='adjustment');
  if(adjustments.length)warnings.push(p.name+': ajustes auditados del día pendientes de conciliación en el reporte');
  const total=rnd(initial+extraordinary);
  const final=rnd(total-consumed);
  const actual=rnd(lots.reduce((n,l)=>n+reportBalance(stateAtEnd(l,moves.filter(m=>m.lotId===l.id),date)),0));
  if(actual!==final)warnings.push(p.name+': saldo calculado distinto del saldo histórico; revisar aperturas y ajustes');
  // A lot created in the future is neither past stock nor a confirmed zero.
  // If it is the only stock on record, the dated export remains blank.
  const count=counts[p.id];
  if(count!==undefined&&(!Number.isFinite(count)||count<0))throw Error('Recuento físico inválido para '+p.name);
  const fs=count===undefined?null:rnd(count-final);
  const expiry=lots.map(l=>l.expires).filter(Boolean).sort()[0]||'';
  return {code:p.id,name:p.name,donated:p.donated,stockKnown,initial,extraordinary,total,consumed,final,expiry,fs};
 });
 return {date,rows,warnings,exportable:warnings.length===0};
}

/** Reuse the daily auditable calculations across any contiguous day range.
 * No extra monthly cutoff applies to nursing Kardex.
 */
export function buildKardexRangeReport(ledger:StockLedger,start:string,end:string,counts:Record<string,number>={}):DailyReport{
 if(!/^\d{4}-\d{2}-\d{2}$/.test(start)||!/^\d{4}-\d{2}-\d{2}$/.test(end)||start>end)
  throw Error('Rango de fechas inválido.');
 const first=Date.parse(start+'T00:00:00Z'),last=Date.parse(end+'T00:00:00Z');
 const days=Math.round((last-first)/86400000)+1;
 if(!Number.isSafeInteger(days)||days<1||days>366)throw Error('El Kardex admite un rango máximo de 366 días.');
 const daily:DailyReport[]=[];
 for(let i=0;i<days;i++)daily.push(buildDailyReport(ledger,new Date(first+i*86400000).toISOString().slice(0,10)));
 const warnings=Array.from(new Set(daily.flatMap(d=>d.warnings)));
 const rows=daily[0].rows.map((begin,n)=>{
  const each=daily.map(d=>d.rows[n]);
  const known=each.every(r=>r.stockKnown===begin.stockKnown)&&begin.stockKnown;
  for(let i=1;i<each.length;i++)if(each[i-1].stockKnown!==each[i].stockKnown||
    (each[i-1].stockKnown&&rnd(each[i-1].final)!==rnd(each[i].initial)))
   warnings.push(begin.name+': diferencia histórica entre '+daily[i-1].date+' y '+daily[i].date);
  const totalIngress=rnd(each.reduce((v,r)=>v+(r.stockKnown?r.extraordinary:0),0));
  const totalUse=rnd(each.reduce((v,r)=>v+(r.stockKnown?r.consumed:0),0));
  const initial=begin.initial,total=rnd(initial+totalIngress),final=rnd(total-totalUse);
  if(known&&rnd(final)!==rnd(each[each.length-1].final))
   warnings.push(begin.name+': saldo final del período diferente del saldo diario.');
  const physicalCount=counts[begin.code];
  if(physicalCount!==undefined&&(!Number.isFinite(physicalCount)||physicalCount<0))
   throw Error('Recuento físico inválido para '+begin.name);
  return{...begin,stockKnown:known,initial,extraordinary:totalIngress,total,consumed:totalUse,final,
   fs:physicalCount===undefined?null:rnd(physicalCount-final),expiry:each[each.length-1].expiry};
 });
 return{date:start,periodEnd:end,rows,warnings:Array.from(new Set(warnings)),exportable:warnings.length===0};
}

