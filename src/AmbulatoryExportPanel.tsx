import {useMemo,useRef,useState} from 'react';
import {FileSpreadsheet,Share2} from 'lucide-react';
import {type StockLedger} from './kardexMovements';
import {buildAmbulatoryRows,type ExportVisit} from './ambulatoryRows';
import {exportAmbulatoryWorkbook} from './ambulatoryExcel';
import {shareXlsx} from './shareKardexFile';
import templateLayout from './ambulatoryTemplate.json';
import {type CatalogMappingEvent,type DeliveryIncident} from './reconciliationRules';
import {type ReconciliationEvent} from './ambulatoryReconciliation';
import {currentReportMonth,reportMonth,sharedMonthlyReconciliation} from './sharedInventoryReports';
type Props={attentions:ExportVisit[];ledger:StockLedger;mappings:CatalogMappingEvent[];incidents:DeliveryIncident[];
 reconciliation:ReconciliationEvent[];onReconciliation:(next:ReconciliationEvent[])=>void};
/** 10-sheet reviewed template is already sanitized in ambulatoryTemplate.json.
 * Never require the employee to upload the historical workbook.
 */
const internalTemplate=()=>{
 const encoded=atob(templateLayout.zipBase64);
 return Uint8Array.from(encoded,c=>c.charCodeAt(0));
};
export default function AmbulatoryExportPanel({attentions,ledger,mappings,incidents,reconciliation}:Props){
 const [month,setMonth]=useState(currentReportMonth);
 const [busy,setBusy]=useState(false),[error,setError]=useState(''),[subdivision,setSubdivision]=useState(''),[done,setDone]=useState('');
 const exporting=useRef(false);
 const period=useMemo(()=>reportMonth(month),[month]);
 const {start,end}=period;
 const result=useMemo(()=>{try{return{data:buildAmbulatoryRows(attentions,ledger,start,end,{subdivision,mappings,incidents}),error:''}}
  catch(e){return{data:null,error:e instanceof Error?e.message:'No se pudo preparar el informe.'}}},[attentions,ledger,start,end,subdivision,mappings,incidents]);
 const shared=useMemo(()=>{if(!result.data)return{data:null,error:''};
  try{return{data:sharedMonthlyReconciliation(ledger,result.data),error:''}}
  catch(e){return{data:null,error:e instanceof Error?e.message:'No se pudo reconstruir el inventario.'}}},[result.data,ledger]);
 async function exportBook(){
  if(!result.data||!shared.data||exporting.current)return;
  exporting.current=true;setBusy(true);setError('');setDone('');
  try{
   if(result.data.blockers.length)throw Error('Verifica las entregas pendientes antes de exportar.');
   if(!subdivision)throw Error('Selecciona primero una subdivisión.');
   await new Promise<void>(resolve=>requestAnimationFrame(()=>setTimeout(resolve,0)));
   const bytes=exportAmbulatoryWorkbook(internalTemplate(),result.data,shared.data);
   await shareXlsx('DANPER_Indicador_Ambulatorio_'+start+'_al_'+end+'.xlsx',bytes,'Indicador Ambulatorio DANPER');
   setDone('Libro de diez hojas generado. Finaliza el guardado en Archivos o comparte la copia.');
  }catch(e){setError(e instanceof Error?e.message:'No fue posible generar el libro oficial.')}
  finally{setBusy(false);exporting.current=false}
 }
 return <section className="panel ambulatoryExport">
  <h3><FileSpreadsheet size={18}/>Indicador ambulatorio · Libro oficial de diez hojas</h3>
  <p className="hint">El formato original depurado ya está integrado en la aplicación. No debes importar ningún Excel. El Indicador cierra el día 9; el Kardex de Enfermería continúa calculando sus saldos diariamente.</p>
  <div className="fields two">
   <label>Mes de inicio del corte (día 9)<input type="month" className="ambulatoryMonthInput" value={month} min="2020-01" max="2099-12" onChange={e=>{if(e.target.value)setMonth(e.target.value);setError('');setDone('')}}/></label>
   <label>Período mensual oficial<input readOnly aria-label="Período mensual oficial" value={period.label}/></label>
  </div>
  <label>Subdivisión del informe<select value={subdivision} onChange={e=>setSubdivision(e.target.value)}><option value="">Seleccionar subdivisión</option>{templateLayout.subdivisions.map(p=><option key={p[1]} value={p[0]}>{p[0]}</option>)}</select></label>
  <p className="hint">El período va del día 9 hasta el día 8 del mes siguiente, sin duplicar el día 9. Los consumos proceden de entregas confirmadas y se registran en la hoja CONSUMOS.</p>
  <p className="hint" role="status">Plantilla interna lista: diez hojas originales, 432 materiales, 30 columnas de CONSUMOS y sus tablas y fórmulas verificadas.</p>
  {result.data&&<div className="kardexStats">
   <div><strong>{result.data.visits}</strong><span>Atenciones</span></div>
   <div><strong>{result.data.lines.length}</strong><span>Filas CONSUMOS</span></div>
   <div><strong>{shared.data?.openingConfirmed||0}</strong><span>Materiales con saldo verificable</span></div>
  </div>}
  {result.data?.blockers.length?<div className="kardexError" role="alert"><strong>Entregas pendientes: {result.data.blockers.length}</strong>
   <ul>{result.data.blockers.slice(0,8).map((x,i)=><li key={i}>{x}</li>)}</ul></div>:null}
  {shared.data&&<p className="hint">Existencias calculadas desde el inventario único para {shared.data.openingConfirmed} códigos oficiales. Los demás permanecen sin saldo informado; un dato pendiente nunca se convierte en cero. CONTEO físico no se inventa.</p>}
  {shared.data?.warnings.length?<details className="kardexPreviewDetails"><summary>Revisar saldos y advertencias ({shared.data.warnings.length})</summary><ul>{shared.data.warnings.slice(0,40).map((x,i)=><li key={i} className="hint">{x}</li>)}</ul></details>:null}
  {reconciliation.length>0&&<div className="warning">Hay {reconciliation.length} registros del módulo de conciliación antiguo. Se conservan para auditoría, pero no se duplican ni se trasladan automáticamente al inventario físico. Requieren revisión antes de considerarlos equivalentes.</div>}
  {(result.error||shared.error||error)&&<p className="kardexError" role="alert">{result.error||shared.error||error}</p>}
  <div className="kardexActions"><button type="button" className="workerPrimary"
   disabled={!subdivision||!result.data||!shared.data||result.data.blockers.length>0||busy}
   onClick={()=>void exportBook()}><Share2 size={18}/>{busy?'Preparando Excel…':'Exportar las diez hojas y compartir'}</button></div>
  {done&&<p className="hint" role="status">{done}</p>}
  <p className="hint">Sólo datos ficticios. La exportación no altera stock, atenciones, lotes ni historial.</p>
 </section>;
}
