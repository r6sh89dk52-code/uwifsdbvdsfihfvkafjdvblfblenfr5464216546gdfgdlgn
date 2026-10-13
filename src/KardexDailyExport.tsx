import {useMemo,useState} from 'react';
import {FileSpreadsheet,Share2} from 'lucide-react';
import {type StockLedger} from './kardexMovements';
import {buildDailyReport} from './dailyKardex';
import {exportOfficialKardex,reportFilename} from './kardexExcelTemplate';
import {shareXlsx} from './shareKardexFile';

type Props={ledger:StockLedger;responsible:string};
const localDate=()=>{const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')};
export default function KardexDailyExport({ledger,responsible}:Props){
 const [date,setDate]=useState(localDate);
 const [turn,setTurn]=useState('');
 const [template,setTemplate]=useState<Uint8Array|null>(null);
 const [templateName,setTemplateName]=useState('');
 const [error,setError]=useState('');
 const [busy,setBusy]=useState(false);
 const [counts,setCounts]=useState<Record<string,number>>({});
 const [filter,setFilter]=useState('');
 const result=useMemo(()=>{try{return {report:buildDailyReport(ledger,date,counts),error:''}}catch(e){return {report:null,error:e instanceof Error?e.message:'No se pudo generar el reporte.'}}},[ledger,date,counts]);
 const rows=result.report?.rows.filter(r=>r.name.toLowerCase().includes(filter.toLowerCase()))||[];
 async function loadTemplate(file?:File){
  setError('');setTemplate(null);setTemplateName('');
  if(!file)return;
  if(!file.name.toLowerCase().endsWith('.xlsx')||file.size>6*1024*1024){setError('Selecciona la plantilla Excel oficial (.xlsx, máximo 6 MB).');return}
  const data=new Uint8Array(await file.arrayBuffer());setTemplate(data);setTemplateName(file.name);
 }
 async function exportReport(){
  if(!result.report||!template)return;
  setError('');setBusy(true);
  try{
   if(!turn)throw Error('Selecciona un turno.');
   const xlsx=exportOfficialKardex(template,result.report,turn,responsible);
   await shareXlsx(reportFilename(date),xlsx);
  }catch(e){setError(e instanceof Error?e.message:'No fue posible exportar el archivo Excel.')}
  finally{setBusy(false)}
 }
 return <section className="panel kardexDaily">
  <h3><FileSpreadsheet size={18}/>Reporte diario · Excel oficial</h3>
  <p className="hint">Selecciona la fecha y el turno. El Excel conserva exclusivamente «KARDEX ENFERMERAS»: 98 productos y mismo formato de impresión; no incluye donados. Todo se procesa localmente.</p>
  <div className="fields two">
   <label>Fecha del reporte<input type="date" value={date} max={localDate()} onChange={e=>{setDate(e.target.value);setError('')}}/></label>
   <label>Turno<select value={turn} onChange={e=>setTurn(e.target.value)}><option value="">Seleccionar turno…</option><option>MAÑANA</option><option>TARDE</option><option>NOCHE</option></select></label>
  </div>
  <label>Plantilla original del Kardex
   <input type="file" accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" onChange={e=>{void loadTemplate(e.target.files?.[0])}}/>
  </label>
  {template&&<p className="hint">Plantilla seleccionada: {templateName}. Se usará para generar una copia, sin modificar el original.</p>}
  <p className="hint">Responsable: {responsible}. El cálculo cubre el día completo. El turno identifica el reporte, pero no filtra horas: aún no hay saldos históricos comprobables por turno.</p>
  {result.error&&<p className="kardexError" role="alert">{result.error}</p>}
  {result.report&&<>
   <div className="kardexStats"><div><strong>98</strong><span>Enfermeras</span></div><div><strong>{result.report.warnings.length}</strong><span>Observaciones</span></div></div>
   {result.report.warnings.length>0&&<div className="kardexError"><strong>Exportación bloqueada: revisa la conciliación</strong>
    <ul>{result.report.warnings.slice(0,12).map((w,i)=><li key={i}>{w}</li>)}</ul>
    {result.report.warnings.length>12&&<p>Hay {result.report.warnings.length-12} observaciones adicionales.</p>}
   </div>}
   <details className="kardexPreviewDetails"><summary>Mostrar vista previa y recuento físico ({result.report.rows.length} productos)</summary>
   <p className="hint">Los recuentos introducidos aquí son temporales; completa y exporta antes de cambiar de sección.</p>
   <label>Filtrar vista previa por medicamento<input value={filter} onChange={e=>setFilter(e.target.value)} placeholder="Nombre del producto…"/></label>
   <p className="hint">D inicial + E extraordinario = F total; F − G consumo = H final. F/S queda vacío si no has contado físicamente el producto.</p>
   <div className="dailyTableScroll"><table><thead><tr><th>Medicamento</th><th>D</th><th>E</th><th>F</th><th>G</th><th>H</th><th>Recuento físico</th><th>F/S</th></tr></thead><tbody>
    {rows.slice(0,25).map(r=><tr key={r.code}><td>{r.name}</td><td>{r.stockKnown?r.initial:'—'}</td><td>{r.stockKnown?r.extraordinary:'—'}</td><td>{r.stockKnown?r.total:'—'}</td><td>{r.stockKnown?r.consumed:'—'}</td><td>{r.stockKnown?r.final:'—'}</td><td><input className="dailyPhysicalCount" type="number" inputMode="decimal" min="0" step="any" aria-label={'Recuento físico '+r.name}
   value={counts[r.code]===undefined?'':counts[r.code]} onChange={e=>{
    const raw=e.target.value;
    setCounts(prev=>{const next={...prev};if(raw.trim()==='')delete next[r.code];else next[r.code]=Number(raw);return next})
   }}/></td><td>{r.fs===null?'—':r.fs}</td></tr>)}
   </tbody></table></div>
   {rows.length>25&&<p className="hint">Vista previa de 25 de {rows.length} productos. El Excel contiene todos los productos.</p>}
   </details>
  </>}
  {error&&<p className="kardexError" role="alert">{error}</p>}
  <div className="kardexActions"><button type="button" className="workerPrimary" disabled={!result.report?.exportable||!template||!turn||busy} onClick={()=>void exportReport()}><Share2 size={18}/>{busy?'Preparando Excel…':'Generar Excel y compartir'}</button></div>
  <p className="hint">Datos ficticios. No se modifica el historial de atenciones, inventario ni movimientos al exportar. Para validar F/S se necesitará incorporar el conteo físico por producto en una etapa posterior.</p>
 </section>;
}
