/** Kardex Etapa B0: recuento físico de prueba, no movimientos de consumo. */
export type ContainerKind='unidad'|'caja'|'frasco'|'paquete'|'blister'|'otro';
export type StockLot={
  id:string;
  code:string;
  name:string;
  catalogUnit:string;
  lot:string;
  expires:string;
  container:ContainerKind;
  unitsPerContainer:number;
  sealedContainers:number;
  looseUnits:number;
  openedRemaining:number;
  updatedAt:number;
};
const validKinds:ContainerKind[]=['unidad','caja','frasco','paquete','blister','otro'];
const round=(n:number)=>Math.round((n+Number.EPSILON)*1000)/1000;
function nonnegative(v:unknown,key:string,whole:boolean){
  if(typeof v!=='number'||!Number.isFinite(v)||v<0||v>10000000||(whole&&!Number.isInteger(v)))
    throw new Error(`Cantidad inválida para ${key}`);
  return v;
}
export function validateStockLot(x:unknown):StockLot{
  if(!x||typeof x!=='object'||Array.isArray(x))throw new Error('Lote inválido.');
  const v=x as Record<string,unknown>;
  for(const key of ['id','code','name','catalogUnit','lot','expires','container']){
    if(typeof v[key]!=='string')throw new Error('Falta '+key+' en el lote.');
  }
  if(!(v.code as string).trim()||!(v.name as string).trim()||!(v.id as string).trim())throw new Error('El lote no identifica un producto.');
  if(!validKinds.includes(v.container as ContainerKind))throw new Error('Envase desconocido.');
  const size=nonnegative(v.unitsPerContainer,'capacidad',true);
  if(size<1)throw new Error('La capacidad debe ser mayor que cero.');
  const sealed=nonnegative(v.sealedContainers,'envases cerrados',true);
  const loose=nonnegative(v.looseUnits,'unidades sueltas',false);
  const opened=nonnegative(v.openedRemaining,'contenido abierto restante',false);
  if(opened>size)throw new Error('El contenido abierto supera la capacidad del envase.');
  if(v.expires && (!/^\d{4}-\d{2}-\d{2}$/.test(v.expires as string)||Number.isNaN(Date.parse(v.expires as string))))
    throw new Error('Fecha de vencimiento inválida.');
  // El timestamp (milisegundos Unix) no es una cantidad física de inventario.
  // Date.now() ≈ 1.8e12, mayor que el límite de 10 millones para saldos.
  if(typeof v.updatedAt!=='number'||!Number.isSafeInteger(v.updatedAt)||v.updatedAt<0)
    throw new Error('Fecha de modificación inválida.');
  const updatedAt=v.updatedAt;
  return {id:v.id as string,code:(v.code as string).trim(),name:(v.name as string).trim(),catalogUnit:v.catalogUnit as string,
    lot:(v.lot as string).trim(),expires:v.expires as string,container:v.container as ContainerKind,unitsPerContainer:size,
    sealedContainers:sealed,looseUnits:loose,openedRemaining:opened,updatedAt};
}
export function validateStockLots(value:unknown):StockLot[]{
  if(!Array.isArray(value))throw new Error('El inventario tiene un formato inválido.');
  if(value.length>500)throw new Error('El prototipo admite un máximo de 500 lotes ficticios.');
  const ids=new Set<string>();
  return value.map(x=>{
    const lot=validateStockLot(x);
    if(ids.has(lot.id))throw new Error('Identificador de lote duplicado.');
    ids.add(lot.id);
    return lot;
  });
}
/** Physical contents = sealed*capacity + loose + remaining open; no double count. */
export function countPhysicalUnits(lot:StockLot):number{
  return round(lot.sealedContainers*lot.unitsPerContainer+lot.looseUnits+lot.openedRemaining);
}
export function inventoryTotals(lots:StockLot[]){
  return {
    products:new Set(lots.map(x=>x.code)).size,
    lots:lots.length,
    opened:lots.filter(x=>x.openedRemaining>0).length,
    expiring:lots.filter(x=>x.expires&&x.expires<=new Date(Date.now()+30*86400000).toISOString().slice(0,10)).length
  };
}
