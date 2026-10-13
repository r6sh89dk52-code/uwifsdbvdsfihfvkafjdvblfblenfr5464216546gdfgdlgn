/** Kardex diario oficial: datos en unidades del formato, no mililitros para envases.
 * Un envase cerrado se descuenta al ABRIRLO; los usos posteriores del abierto
 * no descuentan otro envase en la columna G. El contenido físico queda en B1.
 */
import {kardexCatalog} from './kardexCatalog';
import {validateStockLedger,type StockLedger,type StockMovement} from './kardexMovements';
import {type StockLot,countPhysicalUnits} from './inventoryRules';
export type DailyRow={code:string;name:string;donated:boolean;initial:number;extraordinary:number;total:number;consumed:number;final:number;expiry:string;fs:number|null};
export type DailyReport={date:string;rows:DailyRow[];warnings:string[];exportable:boolean};
const rnd=(x:number)=>Math.round((x+Number.EPSILON)*1000)/1000;
function dateOnly(t:number){return new Date(t).toISOString().slice(0,10)}
const packaged=(l:StockLot)=>l.container!=='unidad'||l.unitsPerContainer!==1||l.catalogUnit!=='UND';
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
  const lots=valid.lots.filter(l=>l.code===p.id);
  const moves=valid.movements.filter(m=>m.code===p.id);
  const rowDay=dayMoves(moves,date);
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
  const consumed=rnd(rowDay.filter(m=>m.kind==='use').reduce((n,m)=>n+(packaged(m.before)?m.excelQuantity:m.quantity),0));
  const adjustments=rowDay.filter(m=>m.kind==='adjustment');
  if(adjustments.length)warnings.push(p.name+': ajustes auditados del día pendientes de conciliación en el reporte');
  if(p.donated&&extraordinary)warnings.push(p.name+': la hoja donados no tiene columna de ingresos extraordinarios');
  const total=rnd(initial+extraordinary);
  const final=rnd(total-consumed);
  const actual=rnd(lots.reduce((n,l)=>n+reportBalance(stateAtEnd(l,moves.filter(m=>m.lotId===l.id),date)),0));
  if(actual!==final)warnings.push(p.name+': saldo calculado distinto del saldo histórico; revisar aperturas y ajustes');
  if(lots.some(l=>l.updatedAt>Date.parse(date+'T23:59:59Z')&&!moves.some(m=>m.lotId===l.id)))
   warnings.push(p.name+': no hay historial suficiente para reconstruir esta fecha anterior');
  const count=counts[p.id];
  if(count!==undefined&&(!Number.isFinite(count)||count<0))throw Error('Recuento físico inválido para '+p.name);
  const fs=count===undefined?null:rnd(count-final);
  const expiry=lots.map(l=>l.expires).filter(Boolean).sort()[0]||'';
  return {code:p.id,name:p.name,donated:p.donated,initial,extraordinary,total,consumed,final,expiry,fs};
 });
 return {date,rows,warnings,exportable:warnings.length===0};
}
