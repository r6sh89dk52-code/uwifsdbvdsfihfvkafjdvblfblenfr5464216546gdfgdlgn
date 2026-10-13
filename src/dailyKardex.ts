/** Reporte diario: cálculo físico, no exportación ni reconstrucción del formato oficial. */
import {kardexCatalog} from './kardexCatalog';
import {type StockLedger,validateStockLedger} from './kardexMovements';
import {countPhysicalUnits} from './inventoryRules';
export type DailyRow={code:string;name:string;donated:boolean;unit:string;initial:number;extraordinary:number;consumed:number;final:number;expiry:string;counted?:number;fs?:number};
export type DailyReport={date:string;rows:DailyRow[];warnings:string[]};
const rnd=(x:number)=>Math.round((x+Number.EPSILON)*1000)/1000;
function dateOnly(t:number){const d=new Date(t);return d.toISOString().slice(0,10)}
export function buildDailyReport(ledger:StockLedger,date:string,physicalCounts:Record<string,number>={}):DailyReport{
 if(!/^\d{4}-\d{2}-\d{2}$/.test(date)||Number.isNaN(Date.parse(date)))throw Error('Fecha inválida');
 const valid=validateStockLedger(ledger);
 const warnings:string[]=[];
 const rows=kardexCatalog.map(p=>{
  const lots=valid.lots.filter(l=>l.code===p.id);
  const moves=valid.movements.filter(m=>m.code===p.id);
  const units=[...new Set(lots.map(l=>l.catalogUnit))];
  if(units.length>1)warnings.push(p.name+': unidades incompatibles entre lotes');
  const unit=units[0]||'';
  let finalNow=lots.reduce((n,l)=>n+countPhysicalUnits(l),0);
  // Rewind all movements after the end of the requested calendar day.
  const after=moves.filter(m=>dateOnly(m.at)>date);
  const laterDelta=after.reduce((n,m)=>n+m.physicalChange,0);
  const final=rnd(finalNow-laterDelta);
  const day=moves.filter(m=>dateOnly(m.at)===date);
  const extraordinary=rnd(day.filter(m=>m.kind==='extraordinary').reduce((n,m)=>n+m.physicalChange,0));
  const consumed=rnd(day.filter(m=>m.kind==='use').reduce((n,m)=>n-m.physicalChange,0));
  const adjustments=rnd(day.filter(m=>m.kind==='adjustment').reduce((n,m)=>n+m.physicalChange,0));
  if(adjustments!==0)warnings.push(p.name+': ajustes del día deben conciliarse por separado ('+adjustments+' '+unit+')');
  if(p.donated&&extraordinary!==0)warnings.push(p.name+': ingreso extraordinario sin columna equivalente en hoja DONADOS');
  const initial=rnd(final-extraordinary+consumed-adjustments);
  if(initial<0||final<0)warnings.push(p.name+': saldo histórico negativo; revisar datos');
  const counted=Object.prototype.hasOwnProperty.call(physicalCounts,p.id)?physicalCounts[p.id]:undefined;
  if(counted!==undefined&&(!Number.isFinite(counted)||counted<0))throw Error('Recuento físico inválido '+p.name);
  const expiry=lots.map(l=>l.expires).filter(Boolean).sort()[0]||'';
  // If a physical count is given, difference is physical minus theoretical.
  const fs=counted===undefined?undefined:rnd(counted-final);
  return{code:p.id,name:p.name,donated:p.donated,unit,initial,extraordinary,consumed,final,expiry,...(counted===undefined?{}:{counted,fs})};
 });
 return {date,rows,warnings};
}
