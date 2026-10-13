import {useMemo,useState} from 'react';
import {ClipboardCheck,PackagePlus,Scale,RotateCcw} from 'lucide-react';
import products from './products.json';
import {appendReconciliationEvent,activeReconciliationEvents,reconcileAmbulatoryReport,
 type ReconciliationEvent,type ReconciliationKind} from './ambulatoryReconciliation';
import {type ExportPlan} from './ambulatoryRows';
type Props={plan:ExportPlan|null;events:ReconciliationEvent[];onChange:(events:ReconciliationEvent[])=>void;
 subdivision:string;start:string;end:string};
const iso=(date:Date)=>date.getFullYear()+'-'+String(date.getMonth()+1).padStart(2,'0')+'-'+String(date.getDate()).padStart(2,'0');
export default function AmbulatoryReconciliationPanel({plan,events,onChange,subdivision,start,end}:Props){
 const [kind,setKind]=useState<ReconciliationKind>('opening');
 const [code,setCode]=useState('');
 const [when,setWhen]=useState(start);
 const [quantity,setQuantity]=useState('0');
 const [reason,setReason]=useState('');
 const [document,setDocument]=useState('');
 const [expires,setExpires]=useState('');
 const [voidOf,setVoidOf]=useState('');
 const [search,setSearch]=useState('');
 const [feedback,setFeedback]=useState('');
 const [showAll,setShowAll]=useState(false);
 const productsFound=useMemo(()=>products.filter(p=>(p.code+' '+p.name).toLocaleLowerCase('es').includes(search.toLocaleLowerCase('es'))),[search]);
 const active=useMemo(()=>activeReconciliationEvents(events),[events]);
 const relevant=active.filter(e=>e.subdivision===subdivision);
 const summary=useMemo(()=>{try{return plan?reconcileAmbulatoryReport(plan,events,subdivision):null}catch{return null}},[plan,events,subdivision]);
 const current=products.find(p=>p.code===code);
 function chooseKind(next:ReconciliationKind){
  setKind(next);setFeedback('');setQuantity('0');setReason('');setDocument('');setExpires('');setVoidOf('');
  setWhen(next==='count'?end:start);
 }
 function save(){
  if(!subdivision){setFeedback('Selecciona primero la subdivisión del reporte.');return}
  const at=Date.now();
  const action:ReconciliationEvent={
   id:crypto.randomUUID(),kind,subdivision,code:kind==='opening'||kind==='receipt'||kind==='count'?code:'',
   date:kind==='opening'||kind==='review'?start:kind==='count'?end:when,
   at,quantity:kind==='review'||kind==='void'?0:Number(quantity),reason,
   document:kind==='receipt'?document:'',expires:kind==='receipt'?expires:'',
   periodEnd:kind==='review'?end:'',voidOf:kind==='void'?voidOf:''
  };
  try{
   const next=appendReconciliationEvent(events,action);
   onChange(next);setFeedback('Registro ficticio auditado guardado. No se han modificado atenciones ni stock.');
   setReason('');setQuantity('0');setDocument('');setExpires('');setVoidOf('');
  }catch(error){setFeedback(error instanceof Error?error.message:'No se pudo validar la conciliación.')}
 }
 return <section className="panel ambulatoryReconciliation">
  <h3><Scale size={18}/>Conciliación de inventario · Etapa v0.16</h3>
  <p className="hint">Exclusiva del Indicador Ambulatorio (432 códigos numéricos). Datos ficticios; ingresos y conteos independientes del Kardex de Enfermería. Un cero declarado es distinto de un dato pendiente.</p>
  <div className="kardexActionKinds">
   {([['opening','Stock inicial'],['receipt','Ingreso'],['count','Conteo final'],['review','Cerrar ingresos'],['void','Anular']] as [ReconciliationKind,string][]).map(([k,label])=>
    <button type="button" key={k} className={kind===k?'selected':''} onClick={()=>chooseKind(k)}>{label}</button>)}
  </div>
  {kind!=='review'&&kind!=='void'&&<>
   <label>Buscar material oficial<input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Código o nombre del catálogo…"/></label>
   <label>Material<select value={code} onChange={e=>{setCode(e.target.value);setFeedback('')}}><option value="">Seleccionar…</option>
    {productsFound.map(p=><option value={p.code} key={p.code}>{p.code} · {p.name} ({p.unit})</option>)}</select></label>
   {current&&<p className="hint">Unidad oficial del material: <strong>{current.unit}</strong>. No se convierten frascos a mL ni cajas a unidades automáticamente.</p>}
  </>}
  {kind==='receipt'&&<label>Fecha del ingreso<input type="date" value={when} min={start} max={end} onChange={e=>setWhen(e.target.value)}/></label>}
  {(kind==='opening'||kind==='count'||kind==='receipt')&&<label>
   {kind==='opening'?'Stock inicial en la fecha de inicio':kind==='count'?'Conteo físico en la fecha final':'Cantidad recibida'} (en unidad oficial)
   <input type="number" inputMode="numeric" step="1" min="0" value={quantity} onChange={e=>setQuantity(e.target.value)}/>
  </label>}
  {kind==='receipt'&&<div className="fields two">
   <label>Documento/guía de ingreso<input value={document} maxLength={100} onChange={e=>setDocument(e.target.value)}/></label>
   <label>Vencimiento, si corresponde<input type="date" value={expires} onChange={e=>setExpires(e.target.value)}/></label>
  </div>}
  {kind==='review'&&<p className="kardexPreview">Cierre explícito de ingresos del <strong>{start}</strong> al <strong>{end}</strong>. Después de cerrar, la ausencia de ingresos podrá contabilizarse como cero para los 432 materiales. Si surge un ingreso tardío, anula el cierre, regístralo y cierra nuevamente.</p>}
  {kind==='void'&&<label>Registro que se anulará<select value={voidOf} onChange={e=>setVoidOf(e.target.value)}>
   <option value="">Seleccionar registro…</option>
   {relevant.slice().reverse().map(e=><option key={e.id} value={e.id}>{e.kind} · {e.date} · {e.code||'cierre'} · {e.quantity} · {e.reason.slice(0,35)}</option>)}
  </select></label>}
  <label>Motivo / responsable de verificación (obligatorio)
   <input value={reason} maxLength={240} onChange={e=>setReason(e.target.value)} placeholder="Ej.: recuento físico verificado por responsable ficticio"/>
  </label>
  {feedback&&<p className="hint" role="status">{feedback}</p>}
  <div className="kardexActions"><button type="button" className="workerPrimary" onClick={save} disabled={!subdivision}>
   {kind==='receipt'?<PackagePlus size={18}/>:kind==='void'?<RotateCcw size={18}/>:<ClipboardCheck size={18}/>} {kind==='void'?'Anular con historial':'Registrar con trazabilidad'}
  </button></div>
  {summary&&<div className="kardexStats">
   <div><strong>{summary.openingConfirmed}/432</strong><span>Stocks iniciales</span></div>
   <div><strong>{summary.receiptsConfirmed}</strong><span>Ingresos del período</span></div>
   <div><strong>{summary.countConfirmed}/432</strong><span>Conteos finales</span></div>
  </div>}
  <p className="hint">Período con ingresos revisados: <strong>{summary?.reviewed?'Sí':'No'}</strong>. No se inventan saldos iniciales ni recuentos ausentes.</p>
  {summary?.warnings.map((message,i)=><p className="hint" key={i}>{message}</p>)}
  <div className="kardexHistory">
   <h3>Historial de conciliación</h3>
   {relevant.length===0?<p className="hint">No existen registros para esta subdivisión.</p>:
    (showAll?relevant:[...relevant].slice(-12)).slice().reverse().map(e=>
     <article key={e.id} className="kardexHistoryItem"><strong>{e.kind.toUpperCase()} · {e.code||'PERÍODO'} · {e.date}</strong>
      <p>Cantidad: {e.quantity} · {e.reason} {e.document?'· '+e.document:''}</p></article>)}
   {relevant.length>12&&!showAll&&<button className="workerSecondary" onClick={()=>setShowAll(true)}>Ver historial completo</button>}
  </div>
 </section>;
}
