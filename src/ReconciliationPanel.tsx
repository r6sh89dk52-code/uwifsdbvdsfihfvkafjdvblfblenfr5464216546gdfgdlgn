import {useState} from 'react';
import {ClipboardCheck,RotateCcw} from 'lucide-react';
import {kardexCatalog} from './kardexCatalog';
import {type StockLedger} from './kardexMovements';
import {type SavedClinicalAttention} from './attentionKardex';
import {recordDeliveryIncident,type CatalogMappingEvent,type DeliveryIncident,type IncidentKind} from './reconciliationRules';
import {reviewedAssociationsFor,reviewedAssociations} from './reviewedKardexAssociations';
type Props={attentions:SavedClinicalAttention[];ledger:StockLedger;mappings:CatalogMappingEvent[];incidents:DeliveryIncident[];
 onMappings?:(next:CatalogMappingEvent[])=>void;onIncidents:(next:DeliveryIncident[])=>void};
export default function ReconciliationPanel({attentions,ledger,mappings,incidents,onIncidents}:Props){
 const [attentionId,setAttentionId]=useState(''),[itemId,setItemId]=useState('');
 const [incidentId,setIncidentId]=useState(''),[incidentKind,setIncidentKind]=useState<IncidentKind>('returned');
 const [incidentQty,setIncidentQty]=useState('1'),[incidentReason,setIncidentReason]=useState(''),[feedback,setFeedback]=useState('');
 const attention=attentions.find(a=>a.id===attentionId&&a.status==='saved');
 const item=attention?.items.find(i=>i.id===itemId);
 const verified=item?reviewedAssociationsFor(item.code).filter(p=>p.clinicalName===item.name&&p.clinicalUnit===item.unit):[];
 const deliveryMoves=ledger.movements.filter(m=>m.kind==='use'&&m.dispenseRef&&kardexCatalog.some(p=>p.id===m.code));
 const original=deliveryMoves.find(m=>m.id===incidentId);
 function addIncident(){
  if(!original?.dispenseRef){setFeedback('Selecciona una entrega previa.');return}
  try{
   onIncidents(recordDeliveryIncident(ledger,incidents,{
    id:crypto.randomUUID(),movementId:original.id,attentionId:original.dispenseRef.attentionId,itemId:original.dispenseRef.itemId,
    kind:incidentKind,quantity:incidentKind==='returned'?Number(incidentQty):0,
    reason:incidentReason,at:Date.now(),stockRestored:false
   }));
   setIncidentReason('');setFeedback('Incidencia registrada sin modificar existencias.');
  }catch(e){setFeedback(e instanceof Error?e.message:'No se pudo registrar la incidencia.')}
 }
 return <section className="panel reconciliationPanel">
  <h3><ClipboardCheck size={18}/>Revisar productos y devoluciones</h3>
  <p className="hint">Usa esta pantalla para comprobar qué producto del registro de atención corresponde al inventario de Enfermería y para dejar constancia de devoluciones o diferencias.</p><div className="reconciliationExplainer"><strong>¿Qué significa una equivalencia?</strong><p>El nombre o código de un insumo puede ser diferente entre el registro clínico y el Kardex. Solo las asociaciones aprobadas permiten relacionarlos. Elegir una equivalencia no descuenta existencias; para eso debes confirmar la entrega y seleccionar el lote.</p><strong>¿Qué significa una incidencia?</strong><p>Es una observación sobre una entrega que ya confirmaste, por ejemplo una devolución o diferencia detectada. Se documenta para auditoría, pero no aumenta automáticamente el stock utilizable.</p></div><p className="hint">Hay 86 asociaciones revisadas. Los productos no asociados siguen visibles, pero no permiten descuentos clínicos vinculados. Las dos llaves de tres vías usan un código clínico compartido y requieren elegir lote expresamente.</p>
  <p className="hint">{reviewedAssociations.length} relaciones autorizadas. Hay 12 referencias sin asociación; estas se revisan por separado, sin inventar equivalencias.</p>
  <div className="reconciliationSectionTitle"><strong>1. Consultar equivalencias</strong><span>Comprueba un producto de una atención ya guardada.</span></div><label>Atención guardada<select value={attentionId} onChange={e=>{setAttentionId(e.target.value);setItemId('');setFeedback('')}}><option value="">Seleccionar…</option>
   {attentions.filter(a=>a.status==='saved'&&a.items.length).map(a=><option key={a.id} value={a.id}>Atención {a.id.slice(0,8)}</option>)}</select></label>
  {attention&&<label>Producto de atención<select value={itemId} onChange={e=>{setItemId(e.target.value);setFeedback('')}}><option value="">Seleccionar…</option>
   {attention.items.map(i=><option key={i.id} value={i.id}>{i.name} · {i.code}</option>)}</select></label>}
  {item&&<p className="kardexPreview">{verified.length?
   <>Kardex asociado: <strong>{verified.map(p=>p.kardexName+' ('+p.kardexCode+')').join(' / ')}</strong></>:
   <>Este producto no tiene correspondencia aprobada para consumos de Enfermería.</>}
   </p>}
  <div className="kardexHistory"><h3><RotateCcw size={18}/>2. Registrar una devolución o incidencia</h3>
   <p className="hint">Selecciona una entrega confirmada y explica lo ocurrido. Una devolución aquí solo se documenta: si cambia la existencia física, utiliza el ajuste auditado de Movimientos.</p>
   <label>Entrega confirmada<select value={incidentId} onChange={e=>{setIncidentId(e.target.value);setFeedback('')}}><option value="">Seleccionar…</option>
    {deliveryMoves.filter(m=>!incidents.some(i=>i.movementId===m.id)).map(m=><option key={m.id} value={m.id}>{m.name} · {m.quantity} {m.unit} · {m.id.slice(0,16)}</option>)}</select></label>
   {original&&<><label>Tipo<select value={incidentKind} onChange={e=>setIncidentKind(e.target.value as IncidentKind)}>
    <option value="returned">Devolución (sin reintegración)</option><option value="discrepancy">Incidencia del registro</option></select></label>
    {incidentKind==='returned'&&<label>Cantidad devuelta ({original.unit})<input type="number" min="0" step="any" value={incidentQty} onChange={e=>setIncidentQty(e.target.value)}/></label>}
    <label>Motivo obligatorio<input value={incidentReason} maxLength={240} onChange={e=>setIncidentReason(e.target.value)}/></label>
    <div className="kardexActions"><button className="workerPrimary" onClick={addIncident}>Registrar incidencia</button></div>
   </>}
   <p className="hint">Incidencias: {incidents.length} · Equivalencias manuales anteriores conservadas en historial: {mappings.length}</p>
  </div>
  {feedback&&<p role="status" className="hint">{feedback}</p>}
 </section>;
}
