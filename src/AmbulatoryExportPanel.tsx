import {useMemo,useRef,useState} from 'react';
import {FileSpreadsheet,Share2} from 'lucide-react';
import {type StockLedger} from './kardexMovements';
import {buildAmbulatoryRows,type ExportVisit} from './ambulatoryRows';
import {exportAmbulatoryWorkbook} from './ambulatoryExcel';
import {shareXlsx} from './shareKardexFile';
import templateLayout from './ambulatoryTemplate.json';
import {findOfficialArea} from './organizationDirectory';
import {validDanperWorksite} from './danperWorksites';
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
 const [busy,setBusy]=useState(false),[error,setError]=useState(''),[done,setDone]=useState('');
 const exporting=useRef(false);
 const period=useMemo(()=>reportMonth(month),[month]);
 const {start,end}=period;
 // One report and one physical ledger. Site is written per row for the official organizational formulas.
 const withoutSite=useMemo(()=>attentions.filter(a=>a.status==='saved'&&a.date>=start&&a.date<=end&&!validDanperWorksite(a.worker.site)),[attentions,start,end]);
 const unlinkedAreas=useMemo(()=>attentions.filter(a=>{
  if(a.status!=='saved'||a.date<start||a.date>end||!validDanperWorksite(a.worker.site))return false;
  try{return !findOfficialArea(a.worker.site,a.worker.area||'')}catch{return true}
 }),[attentions,start,end]);
 const result=useMemo(()=>{try{return{data:buildAmbulatoryRows(attentions,ledger,start,end,{perVisitSubdivision:true,mappings,incidents}),error:''}}
  catch(e){return{data:null,error:e instanceof Error?e.message:'No se pudo preparar el informe.'}}},[attentions,ledger,start,end,mappings,incidents]);
 const shared=useMemo(()=>{if(!result.data)return{data:null,error:''};
  try{return{data:sharedMonthlyReconciliation(ledger,result.data),error:''}}
  catch(e){return{data:null,error:e instanceof Error?e.message:'No se pudo reconstruir el inventario compartido.'}}},[result.data,ledger]);
 // Only missing physical confirmations can be provisionally reported.
 // Never bypass invalid worker site, tampered ledger, unreviewed mapping or incident.
 const canDraft=Boolean(result.data&&shared.data&&!withoutSite.length&&result.data.blockers.length>0&&
  result.data.blockers.every(message=>message.startsWith('Cantidad sin entrega conciliada: ')));
 async function exportBook(provisional=false){
  if(!result.data||!shared.data||exporting.current)return;
  if(provisional&&!canDraft)return;
  if(provisional&&!window.confirm('EXCEL PROVISIONAL — hay entregas sin confirmar. El libro incluirá las atenciones y productos, pero dejará VACÍA la columna R donde falta conciliación. No calcula stock inicial desconocido, no resta cantidades ni confirma entregas. NO utilizar como reporte final de consumo. ¿Generar borrador?'))return;
  exporting.current=true;setBusy(true);setError('');setDone('');
  try{
   const plan=provisional?buildAmbulatoryRows(attentions,ledger,start,end,{perVisitSubdivision:true,mappings,incidents,allowPendingDeliveries:true}):result.data;
   if(plan.blockers.length)throw Error('Verifica las entregas pendientes antes de exportar.');
   if(withoutSite.length)throw Error('Completa la sede de las atenciones del período antes de generar el Excel consolidado.');
   const reconciled=provisional?sharedMonthlyReconciliation(ledger,plan):shared.data;
   await new Promise<void>(resolve=>requestAnimationFrame(()=>setTimeout(resolve,0)));
   const bytes=provisional?exportAmbulatoryWorkbook(internalTemplate(),plan,reconciled):exportAmbulatoryWorkbook(internalTemplate(),result.data,shared.data);
   const suffix=provisional?'_PROVISIONAL_PENDIENTE_CONCILIACION':'';
   await shareXlsx('DANPER_Indicador_Ambulatorio_'+start+'_al_'+end+suffix+'.xlsx',bytes,'Indicador Ambulatorio DANPER');
   setDone(provisional?'BORRADOR PROVISIONAL generado (10 hojas). Faltan entregas por conciliar; verifica la columna R antes de un envío oficial.':'Libro de diez hojas generado. Finaliza el guardado en Archivos o comparte la copia.');
  }catch(e){setError(e instanceof Error?e.message:'No fue posible generar el libro oficial.')}
  finally{setBusy(false);exporting.current=false}
 }
 return <section className="panel ambulatoryExport">
  <h3><FileSpreadsheet size={18}/>Generar Indicador Ambulatorio</h3>
  <p className="hint">Esta herramienta crea el archivo Excel oficial de diez hojas con las atenciones y consumos del período elegido. <strong>No tienes que adjuntar ninguna plantilla:</strong> ya está integrada en la aplicación. El Kardex de Enfermería se controla diariamente, por separado.</p>
  <div className="stageCProgress" aria-label="Generar Indicador Ambulatorio: tres etapas">
   <span><b>1</b> Configurar</span><span><b>2</b> Revisar</span><span><b>3</b> Compartir</span>
  </div>
  <div className="stageCExportStep">
   <h4><span className="stageCIndex">1</span> Elegir período</h4>
   <p className="hint"><strong>Un único reporte para ambas sedes:</strong> el período comprende desde el día 9 de un mes hasta el 8 del siguiente. Todas las atenciones del Fundo y de Planta La Venturosa se incluyen juntas. Cada fila conserva su sede para que Excel calcule los códigos oficiales.</p>
  <div className="fields two">
   <label>Mes en que empieza el reporte (día 9)<input type="month" className="ambulatoryMonthInput" value={month} min="2020-01" max="2099-12" onChange={e=>{if(e.target.value)setMonth(e.target.value);setError('');setDone('')}}/></label>
   <label>Fechas que incluirá este Excel<input readOnly aria-label="Período mensual oficial" value={period.label}/></label>
  </div>
  <p className="hint"><strong>Kardex único:</strong> todas las entregas de ambas sedes descuentan del mismo inventario físico. No se calculan ni exportan stocks separados.</p>
  <p className="hint">El reporte incluye del día 9 al día 8 siguiente. Solo las entregas confirmadas se reflejan como consumo en la hoja CONSUMOS. No se duplican registros ni se generan movimientos por exportar.</p>
  </div>
  <div className="stageCExportStep">
   <h4><span className="stageCIndex">2</span> Comprobar atenciones y existencias</h4>
   <p className="stageCStatus" role="status">{result.error||shared.error?'Hay errores que revisar':withoutSite.length?'Hay atenciones sin sede confirmada':result.data?.blockers.length?'Existen entregas pendientes':shared.data?.warnings.length?'Hay advertencias de saldo para revisar':'Datos consolidados. Comprueba los recuentos antes de exportar.'}</p>
  <p className="hint" role="status">El archivo incluye las diez hojas originales. Se comprueban las atenciones, el inventario que puede conciliarse y las entregas pendientes. Los saldos no conocidos quedan sin informar; jamás se rellenan como cero automáticamente.</p>
  {result.data&&<div className="kardexStats">
   <div><strong>{result.data.visits}</strong><span>Atenciones</span></div>
   <div><strong>{result.data.lines.length}</strong><span>Filas de consumo</span></div>
   <div><strong>{shared.data?.openingConfirmed||0}</strong><span>Materiales conciliados</span></div>
  </div>}
  {unlinkedAreas.length>0&&<p className="stageCStatus" role="status">{unlinkedAreas.length} atenciones tienen un área libre o sin coincidencia en @uo. Podrás exportarlas con el nombre de área registrado; la unidad organizativa quedará sin código automático cuando no exista una equivalencia oficial.</p>}
  {withoutSite.length>0&&<div className="kardexError" role="alert">Hay {withoutSite.length} atenciones sin sede identificada en este período. Revisa esas fichas antes de exportar: no se asignarán códigos por suposición.</div>}
  {result.data?.blockers.length?<div className="kardexError" role="alert"><strong>Entregas pendientes: {result.data.blockers.length}</strong>
   <ul>{result.data.blockers.slice(0,8).map((x,i)=><li key={i}>{x}</li>)}</ul></div>:null}
  {shared.data&&<p className="hint">Existencias calculadas desde el inventario único para {shared.data.openingConfirmed} códigos oficiales. Los demás permanecen sin saldo informado; un dato pendiente nunca se convierte en cero. CONTEO físico no se inventa.</p>}
  {shared.data?.warnings.length?<details className="kardexPreviewDetails"><summary>Revisar saldos y advertencias ({shared.data.warnings.length})</summary><ul>{shared.data.warnings.slice(0,40).map((x,i)=><li key={i} className="hint">{x}</li>)}</ul></details>:null}
  {reconciliation.length>0&&<div className="warning">Hay {reconciliation.length} registros del módulo de conciliación antiguo. Se conservan para auditoría, pero no se duplican ni se trasladan automáticamente al inventario físico. Requieren revisión antes de considerarlos equivalentes.</div>}
  {(result.error||shared.error||error)&&<p className="kardexError" role="alert">{result.error||shared.error||error}</p>}
  </div>
  <div className="stageCExportStep">
   <h4><span className="stageCIndex">3</span> Crear archivo y compartir</h4>
   <p className="hint">Al pulsar el botón se crea un archivo .xlsx de diez hojas y se abre la opción para guardarlo en Archivos, enviarlo por correo o compartirlo. No se modifica el Kardex ni el historial.</p>
   <p className="hint"><strong>Después de exportar:</strong> en RESU puedes escribir la proyección mensual en K y justificar tu pedido en M (COMENTARIO). Las columnas F (Consumos), G (Stock final), J (Diferencia) y L (Requerimiento) conservan sus fórmulas; no las reemplaces por valores manuales.</p>
  <div className="kardexActions"><button type="button" className="workerPrimary"
   disabled={!result.data||!shared.data||result.data.blockers.length>0||withoutSite.length>0||busy}
   onClick={()=>void exportBook(false)}><Share2 size={18}/>{busy?'Preparando Excel…':'Generar Excel (10 hojas) y compartir'}</button></div>
  {canDraft&&<div className="warning" role="status"><strong>Exportación provisional disponible</strong>
    <p>Puedes descargar las diez hojas con los medicamentos e insumos registrados. Las cantidades de CONSUMOS!R quedarán vacías para las entregas aún no confirmadas. Se conservarán los saldos desconocidos sin convertirlos en cero y no se descontará ningún producto.</p>
    <p><strong>El archivo se marcará PROVISIONAL y no sustituye la conciliación ni el reporte definitivo.</strong></p>
    <button type="button" className="workerSecondary wide" disabled={busy} onClick={()=>void exportBook(true)}><FileSpreadsheet size={18}/> Generar borrador provisional (con advertencia)</button>
  </div>}
  {done&&<p className="hint" role="status">{done}</p>}
  <p className="hint">La exportación solo lee datos locales; no modifica el stock, las atenciones, los lotes ni el historial. Revisa el contenido antes de compartirlo.</p>
  </div>
 </section>;
}
