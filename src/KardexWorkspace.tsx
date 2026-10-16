import {useLayoutEffect,useState} from 'react';
import {feedback} from './nativeHaptics';
import {ArrowLeft} from 'lucide-react';
import KardexPanel from './KardexPanel';
import KardexMovementsPanel from './KardexMovementsPanel';
import KardexDailyExport from './KardexDailyExport';
import AttentionDeliveryPanel from './AttentionDeliveryPanel';
import ReconciliationPanel from './ReconciliationPanel';
import {kardexMainCount} from './kardexCatalog';
import {type SavedClinicalAttention} from './attentionKardex';
import {type StockLedger} from './kardexMovements';
import {type CatalogMappingEvent,type DeliveryIncident} from './reconciliationRules';
type Section='home'|'inventory'|'movements'|'deliveries'|'reports';
type Props={onExit:()=>void;onOpenIndicator:()=>void;ledger:StockLedger;attentions:SavedClinicalAttention[];mappings:CatalogMappingEvent[];incidents:DeliveryIncident[];
 onChange:(ledger:StockLedger)=>void;onMappings:(m:CatalogMappingEvent[])=>void;onIncidents:(m:DeliveryIncident[])=>void;responsible:string};
const names:Record<Section,string>={home:'Kardex de Enfermería',inventory:'Inventario',movements:'Movimientos',deliveries:'Conciliación anterior',reports:'Reportes'};
export default function KardexWorkspace({onExit,onOpenIndicator,ledger,attentions,mappings,incidents,onChange,onMappings,onIncidents,responsible}:Props){
 const [section,setSection]=useState<Section>('home');
 const [deliveryTab,setDeliveryTab]=useState<'confirm'|'incidents'>('confirm');
 function navigate(next:Section){feedback('selection');setSection(next)}
 // Also reset the Kardex *submodule* scroll after React mounts it.
 useLayoutEffect(()=>{document.scrollingElement?.scrollTo({top:0,behavior:'auto'});const frame=requestAnimationFrame(()=>window.scrollTo(0,0));return()=>cancelAnimationFrame(frame)},[section]);
 return <div className="kardexWorkspace">
  {section==='home'?<>
   <div className="pageHead"><button type="button" onClick={onExit} aria-label="Volver al inicio"><ArrowLeft/></button><div><span>GESTIÓN DE EXISTENCIAS</span><h2>Kardex</h2><small>Control físico de existencias de prueba</small></div></div>
   <p className="hint">Control de existencias, lotes, movimientos y reportes. Solo utilizar datos ficticios.</p>
   <div className="kardexStats"><div><strong>{kardexMainCount}</strong><span>Productos oficiales</span></div><div><strong>{ledger.lots.filter(l=>/^E-/.test(l.code)).length}</strong><span>Lotes registrados</span></div></div>
   <div className="kardexGuide" aria-label="Ruta de trabajo sugerida">
    <div className="kardexGuideIntro"><strong>¿Qué necesitas hacer?</strong><span>Elige una opción. No es necesario completar todas en orden; ninguna crea movimientos por sí sola.</span></div>
    <div className="kardexGuideSteps">
     <button type="button" onClick={()=>navigate('inventory')}><span className="stageCIndex">1</span><strong>Inventario físico</strong><small>{ledger.lots.length===0?'Sin lotes cargados':'Consultar productos y lotes'}</small></button>
     <button type="button" onClick={()=>navigate('movements')}><span className="stageCIndex">2</span><strong>Entradas y salidas</strong><small>{ledger.movements.length} registro(s) de movimiento</small></button>
     <button type="button" onClick={()=>navigate('deliveries')}><span className="stageCIndex">3</span><strong>Revisar pendientes anteriores</strong><small>Entrega de insumos automática al guardar una atención; aquí solo se revisan excepciones históricas</small></button>
     <button type="button" onClick={()=>navigate('reports')}><span className="stageCIndex">4</span><strong>Exportar Kardex</strong><small>Genera un archivo Excel de existencias</small></button>
    </div>
   </div>

  </>:<>
   <div className="kardexSectionHeader"><button type="button" onClick={()=>navigate('home')}><ArrowLeft size={17}/> Kardex</button><h3>{names[section]}</h3></div>
   {section==='inventory'&&<KardexPanel ledger={ledger} mappings={mappings} onChange={onChange} responsible={responsible} onOpenIndicator={onOpenIndicator}/>}
   {section==='movements'&&<KardexMovementsPanel ledger={ledger} mappings={mappings} onChange={onChange}/>}
   {section==='reports'&&<KardexDailyExport ledger={ledger} responsible={responsible}/>}
   {section==='deliveries'&&<>
    <div className="kardexSubtabs"><button type="button" className={deliveryTab==='confirm'?'selected':''} onClick={()=>{feedback('selection');setDeliveryTab('confirm')}}>Conciliar entrega antigua</button><button type="button" className={deliveryTab==='incidents'?'selected':''} onClick={()=>{feedback('selection');setDeliveryTab('incidents')}}>Revisar devoluciones</button></div>
    {deliveryTab==='confirm'?<AttentionDeliveryPanel attentions={attentions} ledger={ledger} mappings={mappings} onChange={onChange}/>:<ReconciliationPanel attentions={attentions} ledger={ledger} mappings={mappings} incidents={incidents} onMappings={onMappings} onIncidents={onIncidents}/>}
   </>}
  </>}
 </div>;
}
