import {useState} from 'react';
import {ClipboardCheck,RotateCcw} from 'lucide-react';
import {kardexCatalog} from './kardexCatalog';
import {type StockLedger} from './kardexMovements';
import {type SavedClinicalAttention} from './attentionKardex';
import {activeCatalogMapping,recordCatalogMapping,recordDeliveryIncident,type CatalogMappingEvent,type DeliveryIncident,type IncidentKind} from './reconciliationRules';
type Props={attentions:SavedClinicalAttention[];ledger:StockLedger;mappings:CatalogMappingEvent[];incidents:DeliveryIncident[];
 onMappings:(next:CatalogMappingEvent[])=>void;onIncidents:(next:DeliveryIncident[])=>void};
export default function ReconciliationPanel({attentions,ledger,mappings,incidents,onMappings,onIncidents}:Props){
 const [attentionId,setAttentionId]=useState(''),[itemId,setItemId]=useState(''),[kardexCode,setKardexCode]=useState('');
 const [reason,setReason]=useState(''),[incidentId,setIncidentId]=useState(''),[incidentKind,setIncidentKind]=useState<IncidentKind>('returned');
 const [incidentQty,setIncidentQty]=useState('1'),[incidentReason,setIncidentReason]=useState(''),[feedback,setFeedback]=useState('');
 const attention=attentions.find(a=>a.id===attentionId&&a.status==='saved');
 const item=attention?.items.find(i=>i.id===itemId),current=item?activeCatalogMapping(mappings,item.code):undefined;
 const deliveryMoves=ledger.movements.filter(m=>m.kind==='use'&&m.dispenseRef);
 const original=deliveryMoves.find(m=>m.id===incidentId);
 function mapEvent(kind:'verify'|'revoke'){
  if(!item)return;
  const target=kind==='verify'?kardexCatalog.find(k=>k.id===kardexCode):kardexCatalog.find(k=>k.id===current?.kardexCode);
  if(!target){setFeedback('Selecciona el producto del Kardex.');return}
  try{
   onMappings(recordCatalogMapping(mappings,{id:crypto.randomUUID(),kind,clinicalCode:item.code,clinicalName:item.name,
    kardexCode:target.id,kardexName:target.name,reason,at:Date.now()}));
   setReason('');setFeedback(kind==='verify'?'Equivalencia verificada para sugerencias futuras.':'Equivalencia revocada.');
  }catch(e){setFeedback(e instanceof Error?e.message:'No se pudo guardar la equivalencia.')}
 }
 function addIncident(){
  if(!original?.dispenseRef){setFeedback('Selecciona una entrega previa.');return}
  try{
   onIncidents(recordDeliveryIncident(ledger,incidents,{
    id:crypto.randomUUID(),movementId:original.id,attentionId:original.dispenseRef.attentionId,itemId:original.dispenseRef.itemId,
    kind:incidentKind,quantity:incidentKind==='returned'?Number(incidentQty):0,
    reason:incidentReason,at:Date.now(),stockRestored:false
   }));
   setIncidentReason('');setFeedback('Incidencia registrada sin modificar las existencias.');
  }catch(e){setFeedback(e instanceof Error?e.message:'No se pudo registrar la incidencia.')}
 }
 return <section className="panel reconciliationPanel">
  <h3><ClipboardCheck size={18}/>Equivalencias verificadas</h3>
  <p className="hint">Elige manualmente la equivalencia. Se conservará como referencia verificada, nunca como conversión ni descuento automático.</p>
  <label>Atención guardada<select value={attentionId} onChange={e=>{setAttentionId(e.target.value);setItemId('');setFeedback('')}}><option value="">Seleccionar…</option>
   {attentions.filter(a=>a.status==='saved'&&a.items.length).map(a=><option key={a.id} value={a.id}>Atención {a.id.slice(0,8)}</option>)}</select></label>
  {attention&&<label>Producto clínico<select value={itemId} onChange={e=>{setItemId(e.target.value);setFeedback('')}}><option value="">Seleccionar…</option>
   {attention.items.map(i=><option key={i.id} value={i.id}>{i.name} · {i.code}</option>)}</select></label>}
  {item&&<><p className="kardexPreview">Equivalencia vigente: <strong>{current?.kardexName||'Sin verificar'}</strong></p>
   <label>Producto oficial Kardex<select value={kardexCode} onChange={e=>setKardexCode(e.target.value)}><option value="">Seleccionar producto…</option>
    {kardexCatalog.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
   <label>Motivo de verificación o revocación<input maxLength={240} value={reason} onChange={e=>setReason(e.target.value)} placeholder="Indicar verificación de presentación"/></label>
   <div className="kardexActions"><button className="workerPrimary" onClick={()=>mapEvent('verify')}>Verificar equivalencia</button>
   {current&&<button className="workerSecondary" onClick={()=>mapEvent('revoke')}>Revocar</button>}</div>
  </>}
  <div className="kardexHistory"><h3><RotateCcw size={18}/>Devoluciones e incidencias</h3>
   <p className="hint">Una devolución NO aumenta el stock utilizable. La revisión del material y cualquier corrección física deben registrarse por separado mediante un ajuste auditado.</p>
   <label>Entrega confirmada<select value={incidentId} onChange={e=>{setIncidentId(e.target.value);setFeedback('')}}><option value="">Seleccionar…</option>
    {deliveryMoves.filter(m=>!incidents.some(i=>i.movementId===m.id)).map(m=><option key={m.id} value={m.id}>{m.name} · {m.quantity} {m.unit} · {m.id.slice(0,16)}</option>)}</select></label>
   {original&&<><label>Tipo<select value={incidentKind} onChange={e=>setIncidentKind(e.target.value as IncidentKind)}>
    <option value="returned">Devolución (sin reintegración)</option><option value="discrepancy">Incidencia del registro</option></select></label>
    {incidentKind==='returned'&&<label>Cantidad devuelta ({original.unit})<input type="number" min="0" step="any" value={incidentQty} onChange={e=>setIncidentQty(e.target.value)}/></label>}
    <label>Motivo obligatorio<input value={incidentReason} maxLength={240} onChange={e=>setIncidentReason(e.target.value)}/></label>
    <div className="kardexActions"><button className="workerPrimary" onClick={addIncident}>Registrar incidencia</button></div>
   </>}
   <p className="hint">Incidencias registradas: {incidents.length} · Equivalencias verificadas/revocadas: {mappings.length}</p>
  </div>
  {feedback&&<p role="status" className="hint">{feedback}</p>}
 </section>;
}
