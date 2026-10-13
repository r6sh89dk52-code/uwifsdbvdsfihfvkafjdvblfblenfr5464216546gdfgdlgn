import {useMemo,useState} from 'react';
import {ArrowDownCircle,ClipboardCheck,PackageOpen,RefreshCw} from 'lucide-react';
import {countPhysicalUnits,type StockLot} from './inventoryRules';
import {postStockMovement,suggestFEFOLot,type StockLedger,type StockCommand,type MovementKind} from './kardexMovements';

type Props={ledger:StockLedger;onChange:(value:StockLedger)=>void};
const fmt=(v:number)=>new Intl.NumberFormat('es-PE',{maximumFractionDigits:3}).format(v);
function numberValue(v:string){return v.trim()===''?Number.NaN:Number(v.replace(',','.'))}
function label(l:StockLot){return l.name+(l.lot?' — lote '+l.lot:' — sin lote')+(l.expires?' · vence '+l.expires:'')}
function changedName(kind:MovementKind){return kind==='extraordinary'?'Ingreso extraordinario':kind==='use'?'Consumo de prueba':'Ajuste auditado'}
export default function KardexMovementsPanel({ledger,onChange}:Props){
 const [kind,setKind]=useState<MovementKind>('extraordinary');
 const [productCode,setProductCode]=useState('');
 const [lotId,setLotId]=useState('');
 const [count,setCount]=useState('1');
 const [sealed,setSealed]=useState('0');
 const [loose,setLoose]=useState('0');
 const [newSealed,setNewSealed]=useState('0');
 const [newLoose,setNewLoose]=useState('0');
 const [newOpened,setNewOpened]=useState('0');
 const [confirmOpening,setConfirmOpening]=useState(false);
 const [reason,setReason]=useState('');
 const [error,setError]=useState('');
 const [historyLimit,setHistoryLimit]=useState(15);
 const available=useMemo(()=>Array.from(new Map<string,string>(ledger.lots.map(x=>[x.code,x.name] as const)).entries()).sort((a,b)=>a[1].localeCompare(b[1],'es')),[ledger.lots]);
 const matching=useMemo(()=>ledger.lots.filter(x=>x.code===productCode).sort((a,b)=>(a.expires||'9999-12-31').localeCompare(b.expires||'9999-12-31')),[ledger.lots,productCode]);
 const fefo=suggestFEFOLot(ledger.lots,productCode);
 const selected=ledger.lots.find(x=>x.id===lotId);
 const pack=selected ? (selected.container!=='unidad'||selected.unitsPerContainer!==1||selected.catalogUnit!=='UND'):false;
 const day=new Date().toISOString().slice(0,10);
 const expired=Boolean(selected?.expires&&selected.expires<day);
 const history=ledger.movements.slice().reverse().slice(0,historyLimit);
 function chooseProduct(code:string){
  setProductCode(code);
  const suggested=suggestFEFOLot(ledger.lots,code);
  chooseLot(suggested?.id||ledger.lots.find(x=>x.code===code)?.id||'');
  setError('');setConfirmOpening(false);
 }
 function chooseLot(id:string){
  setLotId(id);setError('');setConfirmOpening(false);
  const l=ledger.lots.find(x=>x.id===id);
  if(l){setNewSealed(String(l.sealedContainers));setNewLoose(String(l.looseUnits));setNewOpened(String(l.openedRemaining))}
 }
 function selectKind(next:MovementKind){
  setKind(next);setError('');setConfirmOpening(false);
  const l=ledger.lots.find(x=>x.id===lotId);
  if(l&&next==='adjustment'){
    setNewSealed(String(l.sealedContainers));setNewLoose(String(l.looseUnits));setNewOpened(String(l.openedRemaining));
  }
}
 function apply(){
  if(!selected){setError('Selecciona primero un producto con inventario y su lote.');return}
  const cmd:StockCommand={
   kind,id:crypto.randomUUID(),lotId:selected.id,at:Date.now(),description:reason.trim(),
   ...(kind==='extraordinary'?{sealedAdded:numberValue(sealed),looseAdded:numberValue(loose)}:
    kind==='use'?{quantity:numberValue(count),allowOpen:confirmOpening}:
    {newSealed:numberValue(newSealed),newLoose:numberValue(newLoose),newOpened:numberValue(newOpened)})
  };
  try{
   const next=postStockMovement(ledger,cmd);
   onChange(next);setError('');setReason('');setConfirmOpening(false);
   if(kind==='extraordinary'){setSealed('0');setLoose('0')}
   if(kind==='adjustment'){const current=next.lots.find(x=>x.id===selected.id);if(current){setNewSealed(String(current.sealedContainers));setNewLoose(String(current.looseUnits));setNewOpened(String(current.openedRemaining))}}
  }catch(e){setError(e instanceof Error?e.message:'No se pudo registrar el movimiento.')}
 }
 return <section className="panel kardexMovementPanel">
  <h3><ArrowDownCircle size={18}/>Movimientos y aperturas</h3>
  <p className="hint">Movimientos manuales de prueba. Cada cambio queda registrado con saldo anterior y posterior. Las atenciones aún no descuentan stock automáticamente.</p>
  <div className="kardexActionKinds">
   {(['extraordinary','use','adjustment'] as MovementKind[]).map(v=><button key={v} type="button" className={kind===v?'selected':''} onClick={()=>selectKind(v)}>{changedName(v)}</button>)}
  </div>
  {available.length===0?<p className="kardexEmpty">Registra primero un inventario inicial para habilitar movimientos.</p>:<>
   <label>Producto con inventario<select value={productCode} onChange={e=>chooseProduct(e.target.value)}><option value="">Seleccionar producto…</option>{available.map(([code,name])=><option key={code} value={code}>{name}</option>)}</select></label>
   {matching.length>0&&<label>Lote / vencimiento<select value={lotId} onChange={e=>chooseLot(e.target.value)}>{matching.map(x=><option value={x.id} key={x.id}>{label(x)} · {fmt(countPhysicalUnits(x))} {x.catalogUnit}</option>)}</select></label>}
   {selected&&<>
    <p className="kardexPreview">Saldo actual: <strong>{fmt(countPhysicalUnits(selected))} {selected.catalogUnit}</strong> · {selected.sealedContainers} cerrados · {fmt(selected.openedRemaining)} abiertos restantes</p>
    {fefo?.id===selected.id&&kind==='use'&&<p className="hint">Sugerencia FEFO: lote con vencimiento más próximo entre los disponibles.</p>}
    {fefo?.id!==selected.id&&kind==='use'&&fefo&&<p className="hint">FEFO sugiere primero el lote <strong>{fefo.lot||'sin lote'}</strong> (vence {fefo.expires||'sin fecha'}). Puedes seleccionar otro lote válido si corresponde.</p>}
    {expired&&kind==='use'&&<p className="kardexError">Este lote está vencido. La aplicación no permite registrar su consumo.</p>}
    {kind==='extraordinary'&&<div className="fields two">
      <label>Envases cerrados ingresados<input inputMode="numeric" type="number" min="0" step="1" value={sealed} onChange={e=>setSealed(e.target.value)}/></label>
      <label>Cantidad suelta ingresada ({selected.catalogUnit})<input inputMode="decimal" type="number" min="0" step="any" value={loose} onChange={e=>setLoose(e.target.value)}/></label>
    </div>}
    {kind==='use'&&<>
     <label>Cantidad física utilizada ({selected.catalogUnit})<input inputMode="decimal" type="number" min="0" step="any" value={count} onChange={e=>setCount(e.target.value)}/></label>
     {pack&&<label className="kardexCheck"><input type="checkbox" checked={confirmOpening} onChange={e=>setConfirmOpening(e.target.checked)}/> Confirmo que es necesario abrir un envase cerrado nuevo.</label>}
     <p className="hint">Envasados: Excel CONSUMOS cantidad 1 únicamente si se abre un nuevo envase; en usos posteriores del mismo envase, 0. Se conserva por separado la cantidad física gastada.</p>
    </>}
    {kind==='adjustment'&&<div className="fields two">
     <label>Nuevos envases cerrados<input inputMode="numeric" type="number" min="0" step="1" value={newSealed} onChange={e=>setNewSealed(e.target.value)}/></label>
     <label>Nuevas unidades sueltas<input inputMode="decimal" type="number" min="0" step="any" value={newLoose} onChange={e=>setNewLoose(e.target.value)}/></label>
     <label>Nuevo contenido abierto restante<input inputMode="decimal" type="number" min="0" step="any" value={newOpened} onChange={e=>setNewOpened(e.target.value)}/></label>
    </div>}
    <label>Motivo del movimiento (obligatorio)<input value={reason} maxLength={250} onChange={e=>setReason(e.target.value)} placeholder={kind==='extraordinary'?'Ejemplo: ingreso extraordinario de prueba':kind==='use'?'Ejemplo: uso de demostración':'Ejemplo: diferencia en recuento físico'}/></label>
    {error&&<p className="kardexError" role="alert">{error}</p>}
    <div className="kardexActions"><button className="workerPrimary" onClick={apply} disabled={expired&&kind==='use'}><ClipboardCheck size={18}/>Registrar {kind==='use'?'salida':kind==='extraordinary'?'ingreso':'ajuste'}</button></div>
   </>}
  </>}
  <div className="kardexHistory">
   <h3><PackageOpen size={18}/>Historial de movimientos</h3>
   {history.length===0?<p className="hint">Sin movimientos registrados.</p>:history.map(m=><article key={m.id} className="kardexHistoryItem">
    <div><strong>{changedName(m.kind)} · {m.name}</strong><small>{new Date(m.at).toLocaleString('es-PE')}</small></div>
    <p>{m.description}{m.before.lot?' · Lote '+m.before.lot:''}</p>
    <p>Antes: {fmt(countPhysicalUnits(m.before))} {m.unit} → Después: {fmt(countPhysicalUnits(m.after))} {m.unit}</p>
    <p>Variación física: {m.physicalChange>0?'+':''}{fmt(m.physicalChange)} {m.unit}{m.kind==='use'?' · CONSUMOS R: '+fmt(m.excelQuantity):''}{m.openedNewContainer?' · Apertura confirmada':''}</p>
   </article>)}
   {ledger.movements.length>historyLimit&&<button className="workerSecondary" onClick={()=>setHistoryLimit(v=>v+15)}><RefreshCw size={16}/>Ver más movimientos</button>}
  </div>
 </section>;
}
