import {useMemo,useState} from 'react';
import {Check,PackageCheck} from 'lucide-react';
import {alreadyDispensed,availableLots,type SavedClinicalAttention} from './attentionKardex';
import {postDeliveryWithMapping,type CatalogMappingEvent} from './reconciliationRules';
import {reviewedAssociationsFor,isReviewedAssociation} from './reviewedKardexAssociations';
import {kardexCatalog} from './kardexCatalog';
import {countPhysicalUnits} from './inventoryRules';
import {type StockLedger} from './kardexMovements';
type Props={attentions:SavedClinicalAttention[];ledger:StockLedger;mappings?:CatalogMappingEvent[];onChange:(next:StockLedger)=>void};
export default function AttentionDeliveryPanel({attentions,ledger,onChange}:Props){
 const [attentionId,setAttentionId]=useState('');
 const [itemId,setItemId]=useState('');
 const [lotId,setLotId]=useState('');
 const [quantity,setQuantity]=useState('1');
 const [identity,setIdentity]=useState(false);
 const [units,setUnits]=useState(false);
 const [given,setGiven]=useState(false);
 const [open,setOpen]=useState(false);
 const [message,setMessage]=useState('');
 const saved=useMemo(()=>attentions.filter(a=>a.status==='saved'&&a.items.length>0),[attentions]);
 const attention=saved.find(a=>a.id===attentionId);
 const item=attention?.items.find(i=>i.id===itemId);
 const lot=ledger.lots.find(l=>l.id===lotId);
 const permitted=lot?availableLots(ledger.lots,lot.code):[];
 const candidates=item?reviewedAssociationsFor(item.code).filter(p=>p.clinicalName===item.name&&p.clinicalUnit===item.unit):[];
 const allowedLots=ledger.lots.filter(l=>candidates.some(p=>p.kardexCode===l.code&&p.kardexName===l.name)&&kardexCatalog.some(p=>p.id===l.code));
 const done=Boolean(attention&&item&&alreadyDispensed(ledger,attention.id,item.id));
 function resetChecks(){setIdentity(false);setUnits(false);setGiven(false);setOpen(false);setMessage('')}
 function chooseAttention(id:string){setAttentionId(id);setItemId('');setLotId('');resetChecks()}
 function chooseItem(id:string){setItemId(id);setLotId('');resetChecks()}
 function chooseLot(id:string){setLotId(id);resetChecks()}
 function send(){
  if(!attention||!item||!lot){setMessage('Selecciona atención, producto de atención y lote del Kardex.');return}
  if(done){setMessage('Este producto ya fue descontado para esa atención.');return}
  const physicalQuantity=quantity.trim()===''?Number.NaN:Number(quantity.replace(',','.'));
  try{
   const next=postDeliveryWithMapping(ledger,attention,{
    itemId:item.id,lotId:lot.id,physicalQuantity,
    confirmIdentity:identity,confirmUnits:units,confirmDelivery:given,openNewContainer:open,timestamp:Date.now()
   },[]);
   onChange(next);resetChecks();setMessage('Entrega ficticia registrada y descontada una sola vez. Comprueba el movimiento en Kardex.');
  }catch(error){setMessage(error instanceof Error?error.message:'No se pudo descontar el producto.')}
 }
 return <section className="panel attentionDelivery">
  <h3><PackageCheck size={18}/>Conciliación de entregas anteriores</h3>
  <p className="hint">Las nuevas atenciones descuentan automáticamente existencias físicas verificables al finalizar. Utiliza esta pantalla únicamente para aclarar registros anteriores pendientes. Solo se permiten las 86 asociaciones aprobadas. La equivalencia no genera entregas automáticas: selecciona el lote y confirma las cantidades.</p>
  <label>Atención confirmada
   <select value={attentionId} onChange={e=>chooseAttention(e.target.value)}>
    <option value="">Seleccionar una atención guardada…</option>
    {saved.map(a=><option key={a.id} value={a.id}>{a.id.slice(0,8)} · {a.items.length} medicamento(s) registrados</option>)}
   </select>
  </label>
  {attention&&<label>Medicamento o insumo registrado
   <select value={itemId} onChange={e=>chooseItem(e.target.value)}>
    <option value="">Seleccionar producto de esa atención…</option>
    {attention.items.map(i=><option key={i.id} value={i.id}>{i.name} · {i.quantity} {i.unit}</option>)}
   </select>
  </label>}
  {item&&<div className="kardexPreview"><strong>Producto de atención:</strong> {item.name} · código {item.code} · {item.quantity} {item.unit}
    <p className="hint">Debes confirmar personalmente la equivalencia con el producto del Kardex y convertir la cantidad a las unidades físicas correctas.</p>
  </div>}
  {item&&candidates.length===0&&<p className="kardexError" role="alert">Producto sin correspondencia aprobada. No puede descontarse desde el Kardex de Enfermería.</p>}
  {item&&candidates.length>0&&<p className="hint">Correspondencia(s) aprobada(s): {candidates.map(p=>p.kardexName+' ('+p.kardexCode+')').join(' / ')}. {candidates.length>1?'Elige expresamente la presentación utilizada; no se descontarán ambas.':''}</p>}
  {item&&candidates.length>0&&<label>Producto y lote del Kardex (selección explícita)
   <select value={lotId} onChange={e=>chooseLot(e.target.value)}>
    <option value="">Seleccionar producto/lote disponible…</option>
    {allowedLots.filter(l=>availableLots(ledger.lots,l.code).some(x=>x.id===l.id)).sort((a,b)=>a.name.localeCompare(b.name,'es')).map(l=>
     <option key={l.id} value={l.id}>{l.name} · lote {l.lot||'sin registrar'} · {countPhysicalUnits(l)} {l.catalogUnit}</option>)}
   </select>
  </label>}
  {lot&&item&&<><p className="kardexPreview">Saldo anterior: <strong>{countPhysicalUnits(lot)} {lot.catalogUnit}</strong> · {lot.sealedContainers} envases cerrados · {lot.openedRemaining} abiertos restantes</p>
    <label>Cantidad física que se entregará ({lot.catalogUnit})
     <input inputMode="decimal" type="number" min="0" step="any" value={quantity} onChange={e=>{setQuantity(e.target.value);setMessage('')}}/>
    </label>
    {(lot.container!=='unidad'||lot.unitsPerContainer!==1||lot.catalogUnit!=='UND')&&<label className="kardexCheck"><input type="checkbox" checked={open} onChange={e=>setOpen(e.target.checked)}/>Confirmo apertura de envase nuevo, cuando sea necesario (R=1 solo al abrir).</label>}
    <label className="kardexCheck"><input type="checkbox" checked={identity} onChange={e=>setIdentity(e.target.checked)}/>He verificado que es el mismo medicamento/insumo y la misma presentación.</label>
    <label className="kardexCheck"><input type="checkbox" checked={units} onChange={e=>setUnits(e.target.checked)}/>He verificado la unidad de medida y la cantidad física equivalente.</label>
    <label className="kardexCheck"><input type="checkbox" checked={given} onChange={e=>setGiven(e.target.checked)}/>Confirmo que la entrega del producto se realizó.</label>
  </>}
  {done&&<p className="kardexPreview"><Check size={16}/> Ya existe una entrega registrada para este medicamento de esta atención. No se permite un segundo descuento.</p>}
  {message&&<p className="hint" role="status">{message}</p>}
  <div className="kardexActions"><button type="button" className="workerPrimary" disabled={!lot||!item||!isReviewedAssociation(item.code,lot.code)||!allowedLots.some(x=>x.id===lot.id)||done||!permitted.some(x=>x.id===lot.id)} onClick={send}><PackageCheck size={18}/> Confirmar entrega y descontar</button></div>
  <p className="hint">No se sincroniza con el Excel oficial ni realiza conversiones automáticamente. Los datos continúan siendo exclusivos de pruebas.</p>
 </section>;
}
