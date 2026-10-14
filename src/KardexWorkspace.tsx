import {useState} from 'react';
import {feedback} from './nativeHaptics';
import {ArrowLeft,ArrowLeftRight,ClipboardCheck,FileSpreadsheet,PackageSearch} from 'lucide-react';
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
const names:Record<Section,string>={home:'Kardex de Enfermería',inventory:'Inventario',movements:'Movimientos',deliveries:'Entregas',reports:'Reportes'};
export default function KardexWorkspace({onExit,onOpenIndicator,ledger,attentions,mappings,incidents,onChange,onMappings,onIncidents,responsible}:Props){
 const [section,setSection]=useState<Section>('home');
 const [deliveryTab,setDeliveryTab]=useState<'confirm'|'incidents'>('confirm');
 function navigate(next:Section){feedback('selection');setSection(next);window.scrollTo({top:0,behavior:'auto'})}
 return <div className="kardexWorkspace">
  {section==='home'?<>
   <div className="pageHead"><button type="button" onClick={onExit} aria-label="Volver al inicio"><ArrowLeft/></button><div><span>GESTIÓN DE EXISTENCIAS</span><h2>Kardex</h2><small>Control físico de existencias de prueba</small></div></div>
   <p className="hint">Control de existencias, lotes, movimientos y reportes. Solo utilizar datos ficticios.</p>
   <div className="kardexStats"><div><strong>{kardexMainCount}</strong><span>Productos oficiales</span></div><div><strong>{ledger.lots.filter(l=>/^E-/.test(l.code)).length}</strong><span>Lotes registrados</span></div></div>
   <div className="kardexSectionGrid">
    <button type="button" onClick={()=>navigate('inventory')}><PackageSearch/><strong>Inventario</strong><span>Existencias, lotes y vencimientos</span></button>
    <button type="button" onClick={()=>navigate('movements')}><ArrowLeftRight/><strong>Movimientos</strong><span>Ingresos, consumos, ajustes e historial</span></button>
    <button type="button" onClick={()=>navigate('deliveries')}><ClipboardCheck/><strong>Entregas</strong><span>Confirmaciones clínicas e incidencias</span></button>
    <button type="button" onClick={()=>navigate('reports')}><FileSpreadsheet/><strong>Reportes</strong><span>Excel oficial del Kardex diario</span></button>
   </div>
  </>:<>
   <div className="kardexSectionHeader"><button type="button" onClick={()=>navigate('home')}><ArrowLeft size={17}/> Kardex</button><h3>{names[section]}</h3></div>
   {section==='inventory'&&<KardexPanel ledger={ledger} mappings={mappings} onChange={onChange} responsible={responsible} onOpenIndicator={onOpenIndicator}/>}
   {section==='movements'&&<KardexMovementsPanel ledger={ledger} mappings={mappings} onChange={onChange}/>}
   {section==='reports'&&<KardexDailyExport ledger={ledger} responsible={responsible}/>}
   {section==='deliveries'&&<>
    <div className="kardexSubtabs"><button type="button" className={deliveryTab==='confirm'?'selected':''} onClick={()=>{feedback('selection');setDeliveryTab('confirm')}}>Confirmar entrega</button><button type="button" className={deliveryTab==='incidents'?'selected':''} onClick={()=>{feedback('selection');setDeliveryTab('incidents')}}>Incidencias y equivalencias</button></div>
    {deliveryTab==='confirm'?<AttentionDeliveryPanel attentions={attentions} ledger={ledger} mappings={mappings} onChange={onChange}/>:<ReconciliationPanel attentions={attentions} ledger={ledger} mappings={mappings} incidents={incidents} onMappings={onMappings} onIncidents={onIncidents}/>}
   </>}
  </>}
 </div>;
}
