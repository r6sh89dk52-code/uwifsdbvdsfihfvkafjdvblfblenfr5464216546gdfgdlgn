import {useMemo,useRef,useState} from 'react';
import {FileSpreadsheet,Share2} from 'lucide-react';
import {type StockLedger} from './kardexMovements';
import {buildAmbulatoryRows,type ExportVisit} from './ambulatoryRows';
import {exportAmbulatoryWorkbook} from './ambulatoryExcel';
import {shareXlsx} from './shareKardexFile';
import templateLayout from './ambulatoryTemplate.json';import {DANPER_WORKSITES} from './danperWorksites';import {findOfficialArea} from './organizationDirectory';
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
 const otherSiteVisits=useMemo(()=>attentions.filter(a=>a.status==='saved'&&a.date>=start&&a.date<=end&&Boolean(subdivision)&&Boolean(a.worker.site)&&a.worker.site!==subdivision),[attentions,start,end,subdivision]);
 const withoutSite=useMemo(()=>attentions.filter(a=>a.status==='saved'&&a.date>=start&&a.date<=end&&!a.worker.site),[attentions,start,end]);
 const combined=subdivision==='ALL';
 const siteVisits=useMemo(()=>subdivision&&!combined?attentions.filter(a=>a.status!=='saved'||a.worker.site===subdivision):attentions,[attentions,subdivision,combined]);
 const unlinkedAreas=useMemo(()=>siteVisits.filter(a=>{
  if(a.status!=='saved'||a.date<start||a.date>end||!subdivision)return false;
  try{return !findOfficialArea(combined?a.worker.site:subdivision,a.worker.area||'')}catch{return true}
 }),[siteVisits,start,end,subdivision,combined]);
 const result=useMemo(()=>{try{return{data:buildAmbulatoryRows(siteVisits,ledger,start,end,{subdivision:combined?'':subdivision,perVisitSubdivision:combined,mappings,incidents}),error:''}}
  catch(e){return{data:null,error:e instanceof Error?e.message:'No se pudo preparar el informe.'}}},[siteVisits,ledger,start,end,subdivision,combined,mappings,incidents]);
 const shared=useMemo(()=>{if(!result.data)return{data:null,error:''};
  try{return{data:combined?sharedMonthlyReconciliation(ledger,result.data):null,error:''}}
  catch(e){return{data:null,error:e instanceof Error?e.message:'No se pudo reconstruir el inventario.'}}},[result.data,ledger,combined]);
 async function exportBook(){
  if(!result.data||exporting.current)return;
  exporting.current=true;setBusy(true);setError('');setDone('');
  try{
   if(result.data.blockers.length)throw Error('Verifica las entregas pendientes antes de exportar.');
   if(!subdivision)throw Error('Selecciona primero una sede.');
   if(withoutSite.length)throw Error('Completa la sede de todas las atenciones del período antes de generar el Excel.');
   await new Promise<void>(resolve=>requestAnimationFrame(()=>setTimeout(resolve,0)));
   const bytes=exportAmbulatoryWorkbook(internalTemplate(),result.data,shared.data||undefined);
   await shareXlsx('DANPER_Indicador_Ambulatorio_'+(combined?'AMBAS_SEDES':subdivision)+'_'+start+'_al_'+end+'.xlsx',bytes,'Indicador Ambulatorio DANPER');
   setDone('Libro de diez hojas generado. Finaliza el guardado en Archivos o comparte la copia.');
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
   <h4><span className="stageCIndex">1</span> Elegir período y lugar de reporte</h4>
   <p className="hint"><strong>Período:</strong> las atenciones se agrupan desde el día 9 de un mes hasta el día 8 del siguiente. <strong>Sede o fundo:</strong> selecciona la ubicación oficial a la que pertenece tu reporte. Por ejemplo, LA VENTUROSA o PLVENTUROSA. Son opciones integradas del Excel; no debes escribirlas ni adjuntar archivos.</p>
  <div className="fields two">
   <label>Mes en que empieza el reporte (día 9)<input type="month" className="ambulatoryMonthInput" value={month} min="2020-01" max="2099-12" onChange={e=>{if(e.target.value)setMonth(e.target.value);setError('');setDone('')}}/></label>
   <label>Fechas que incluirá este Excel<input readOnly aria-label="Período mensual oficial" value={period.label}/></label>
  </div>
  <label>Sede o fundo del reporte<select value={subdivision} onChange={e=>setSubdivision(e.target.value)}><option value="">Seleccionar reporte</option><option value="ALL">Ambas sedes · inventario físico compartido</option>{DANPER_WORKSITES.map(p=><option key={p.code} value={p.id}>{p.label} · {p.code}</option>)}</select></label>
  <p className="hint">El reporte incluye del día 9 al día 8 siguiente. Solo las entregas confirmadas se reflejan como consumo en la hoja CONSUMOS. No se duplican registros ni se generan movimientos por exportar.</p>
  </div>
  <div className="stageCExportStep">
   <h4><span className="stageCIndex">2</span> Comprobar atenciones y existencias</h4>
   <p className="stageCStatus" role="status">{!subdivision?'Pendiente: seleccionar subdivisión':result.error||shared.error?'Hay errores que revisar':result.data?.blockers.length?'Existen entregas pendientes':shared.data?.warnings.length?'Hay advertencias de saldo para revisar':'Datos calculados. Comprueba los recuentos antes de exportar.'}</p>
  <p className="hint" role="status">El archivo incluye las diez hojas originales. Se comprueban las atenciones, el inventario que puede conciliarse y las entregas pendientes. Los saldos no conocidos quedan sin informar; jamás se rellenan como cero automáticamente.</p>
  {result.data&&<div className="kardexStats">
   <div><strong>{result.data.visits}</strong><span>Atenciones</span></div>
   <div><strong>{result.data.lines.length}</strong><span>Filas de consumo</span></div>
   <div><strong>{shared.data?.openingConfirmed||0}</strong><span>Materiales conciliados</span></div>
  </div>}
  {!combined&&otherSiteVisits.length>0&&<p className="stageCStatus" role="status">Este archivo incluirá únicamente las atenciones de {subdivision}. Las {otherSiteVisits.length} atenciones de la otra sede se excluyen expresamente; para exportarlas, genera un segundo reporte seleccionando su sede.</p>}
  {unlinkedAreas.length>0&&<p className="stageCStatus" role="status">{unlinkedAreas.length} atenciones tienen un área libre o sin coincidencia en @uo. Podrás exportarlas con el nombre de área registrado; la unidad organizativa quedará sin código automático cuando no exista una equivalencia oficial.</p>}
  {withoutSite.length>0&&<div className="kardexError" role="alert">Hay {withoutSite.length} atenciones sin sede identificada en este período. Revisa esas fichas antes de exportar: no se asignarán códigos por suposición.</div>}
  {result.data?.blockers.length?<div className="kardexError" role="alert"><strong>Entregas pendientes: {result.data.blockers.length}</strong>
   <ul>{result.data.blockers.slice(0,8).map((x,i)=><li key={i}>{x}</li>)}</ul></div>:null}
  {!combined&&subdivision&&<p className="hint">Reporte individual de sede: los consumos se filtran por sede, pero el stock físico es compartido. Las existencias, ingresos y recuentos se dejan pendientes, no se copian como saldo exclusivo de esta sede.</p>}
  {shared.data&&<p className="hint">Existencias calculadas desde el inventario único para {shared.data.openingConfirmed} códigos oficiales. Los demás permanecen sin saldo informado; un dato pendiente nunca se convierte en cero. CONTEO físico no se inventa.</p>}
  {shared.data?.warnings.length?<details className="kardexPreviewDetails"><summary>Revisar saldos y advertencias ({shared.data.warnings.length})</summary><ul>{shared.data.warnings.slice(0,40).map((x,i)=><li key={i} className="hint">{x}</li>)}</ul></details>:null}
  {reconciliation.length>0&&<div className="warning">Hay {reconciliation.length} registros del módulo de conciliación antiguo. Se conservan para auditoría, pero no se duplican ni se trasladan automáticamente al inventario físico. Requieren revisión antes de considerarlos equivalentes.</div>}
  {(result.error||shared.error||error)&&<p className="kardexError" role="alert">{result.error||shared.error||error}</p>}
  </div>
  <div className="stageCExportStep">
   <h4><span className="stageCIndex">3</span> Crear archivo y compartir</h4>
   <p className="hint">Al pulsar el botón se crea un archivo .xlsx de diez hojas y se abre la opción para guardarlo en Archivos, enviarlo por correo o compartirlo. No se modifica el Kardex ni el historial.</p>
  <div className="kardexActions"><button type="button" className="workerPrimary"
   disabled={!subdivision||!result.data||result.data.blockers.length>0||withoutSite.length>0||busy}
   onClick={()=>void exportBook()}><Share2 size={18}/>{busy?'Preparando Excel…':'Generar Excel (10 hojas) y compartir'}</button></div>
  {done&&<p className="hint" role="status">{done}</p>}
  <p className="hint">Sólo datos ficticios. La exportación no altera stock, atenciones, lotes ni historial.</p>
  </div>
 </section>;
}
