import {useEffect,useMemo,useState} from 'react';
import {unzipSync} from 'fflate';
import {FileSpreadsheet,Share2} from 'lucide-react';
import {type StockLedger} from './kardexMovements';
import {buildDailyReport,buildKardexRangeReport} from './dailyKardex';
import {exportOfficialKardex,reportFilename} from './kardexExcelTemplate';
import {shareXlsx} from './shareKardexFile';

type Props={ledger:StockLedger;responsible:string};
const localDate=()=>{const d=new Date();return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')};
export default function KardexDailyExport({ledger,responsible}:Props){
 const [date,setDate]=useState(localDate);
 const [turn,setTurn]=useState('');
 const [mode,setMode]=useState<'daily'|'weekly'|'custom'>('daily');
 const [rangeStart,setRangeStart]=useState(localDate);
 const [rangeEnd,setRangeEnd]=useState(localDate);
 const [template,setTemplate]=useState<Uint8Array|null>(null);
 const [templateStatus,setTemplateStatus]=useState<'loading'|'ready'|'missing'>('loading');
 const [error,setError]=useState('');
 const [busy,setBusy]=useState(false);
 const [counts,setCounts]=useState<Record<string,number>>({});
 const [filter,setFilter]=useState('');
 const [previewPage,setPreviewPage]=useState(0);
 const pageSize=20;
 const weekly=useMemo(()=>{
  const day=new Date(date+'T12:00:00Z'),shift=(day.getUTCDay()+6)%7;
  const monday=new Date(Date.UTC(day.getUTCFullYear(),day.getUTCMonth(),day.getUTCDate()-shift)).toISOString().slice(0,10);
  const sunday=new Date(Date.UTC(day.getUTCFullYear(),day.getUTCMonth(),day.getUTCDate()+6-shift)).toISOString().slice(0,10);
  return{start:monday,end:sunday>localDate()?localDate():sunday};
 },[date]);
 const from=mode==='daily'?date:mode==='weekly'?weekly.start:rangeStart;
 const to=mode==='daily'?date:mode==='weekly'?weekly.end:rangeEnd;
 const result=useMemo(()=>{try{return{report:mode==='daily'?buildDailyReport(ledger,date,counts):buildKardexRangeReport(ledger,from,to,counts),error:''}}catch(e){return{report:null,error:e instanceof Error?e.message:'No se pudo generar el reporte.'}}},[ledger,mode,date,from,to,counts]);
 const simplify=(value:string)=>value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
 const rows=result.report?.rows.filter(r=>simplify(r.name).includes(simplify(filter)))||[];
 const pageCount=Math.max(1,Math.ceil(rows.length/pageSize));
 const previewRows=rows.slice(previewPage*pageSize,(previewPage+1)*pageSize);
 useEffect(()=>{
  let cancelled=false;
  async function loadInternalTemplate(){
   try{
    const url=import.meta.env.BASE_URL+'internal/kardex-template.bin';
    const response=await fetch(url,{cache:'force-cache'});
    if(!response.ok)throw Error('El recurso interno no existe.');
    const data=new Uint8Array(await response.arrayBuffer());
    if(data.length<1500||data.length>6*1024*1024)throw Error('El recurso interno no es válido.');
    const files=unzipSync(data);
    for(const name of ['xl/workbook.xml','xl/worksheets/sheet2.xml','xl/styles.xml','xl/sharedStrings.xml'])
     if(!files[name])throw Error('Faltan componentes del formato oficial.');
    if(!cancelled){setTemplate(data);setTemplateStatus('ready');}
   }catch{
    if(!cancelled){setTemplate(null);setTemplateStatus('missing');setError('No está integrada la plantilla original depurada. El reporte no puede exportarse hasta incorporar el recurso oficial en la aplicación.');}
   }
  }
  void loadInternalTemplate();
  return()=>{cancelled=true};
 },[]);
 async function exportReport(){
  if(!result.report||!template)return;
  setError('');setBusy(true);
  try{
   if(mode==='daily'&&!turn)throw Error('Selecciona un turno.');
   const xlsx=exportOfficialKardex(template,result.report,mode==='daily'?turn:'CONSOLIDADO',responsible);
   await shareXlsx(mode==='daily'?reportFilename(date):'DANPER_Kardex_'+from+'_al_'+to+'.xlsx',xlsx);
  }catch(e){setError(e instanceof Error?e.message:'No fue posible exportar el archivo Excel.')}
  finally{setBusy(false)}
 }
 return <section className="panel kardexDaily">
  <h3><FileSpreadsheet size={18}/>Kardex · Excel oficial de Enfermería</h3>
  <p className="hint">Reportes diarios, semanales o de rango personalizado con el mismo inventario físico. El Kardex no utiliza el corte mensual del Indicador.</p>
  <label>Modalidad de reporte<select value={mode} onChange={e=>{setMode(e.target.value as 'daily'|'weekly'|'custom');setCounts({});setPreviewPage(0)}}><option value="daily">Diario</option><option value="weekly">Semanal</option><option value="custom">Rango personalizado</option></select></label>
  <div className="fields two">
   {mode!=='custom'?<label>{mode==='weekly'?'Día de la semana a consultar':'Fecha del reporte'}<input type="date" value={date} max={localDate()} onChange={e=>{setDate(e.target.value);setCounts({});setPreviewPage(0);setError('')}}/></label>:<>
    <label>Desde<input type="date" value={rangeStart} max={localDate()} onChange={e=>{setRangeStart(e.target.value);setCounts({});setPreviewPage(0)}}/></label>
    <label>Hasta<input type="date" value={rangeEnd} max={localDate()} onChange={e=>{setRangeEnd(e.target.value);setCounts({});setPreviewPage(0)}}/></label>
   </>}
   {mode==='daily'&&<label>Turno<select value={turn} onChange={e=>setTurn(e.target.value)}><option value="">Seleccionar turno…</option><option>MAÑANA</option><option>TARDE</option><option>NOCHE</option></select></label>}
  </div>
  {mode!=='daily'&&<p className="hint">Reporte consolidado del {from} al {to} (ambos incluidos). No se duplica el saldo inicial entre días.</p>}
  <p className="hint" role="status">{templateStatus==='ready'?'Plantilla oficial interna preparada. No es necesario importar ningún Excel.':templateStatus==='loading'?'Preparando el formato oficial del Kardex…':'Formato original interno pendiente de integración.'}</p>
  <p className="hint">Responsable: {responsible}. El cálculo se realiza por día completo. En modo diario el turno identifica el reporte, sin filtrar horas.</p>
  {result.error&&<p className="kardexError" role="alert">{result.error}</p>}
  {result.report&&<>
   <div className="kardexStats"><div><strong>98</strong><span>Enfermeras</span></div><div><strong>{result.report.warnings.length}</strong><span>Observaciones</span></div></div>
   {result.report.warnings.length>0&&<div className="kardexError"><strong>Exportación bloqueada: revisa la conciliación</strong>
    <ul>{result.report.warnings.slice(0,12).map((w,i)=><li key={i}>{w}</li>)}</ul>
    {result.report.warnings.length>12&&<p>Hay {result.report.warnings.length-12} observaciones adicionales.</p>}
   </div>}
   <details className="kardexPreviewDetails"><summary>Mostrar vista previa y recuento físico ({result.report.rows.length} productos)</summary>
   <p className="hint">Los recuentos introducidos aquí son temporales; completa y exporta antes de cambiar de sección.</p>
   <label>Filtrar vista previa por medicamento<input value={filter} onChange={e=>{setFilter(e.target.value);setPreviewPage(0)}} placeholder="Nombre del producto…"/></label>
   <p className="hint">D inicial + E extraordinario = F total; F − G consumo = H final. F/S queda vacío si no has contado físicamente el producto.</p>
   <div className="dailyTableScroll"><table><thead><tr><th>Medicamento</th><th>D</th><th>E</th><th>F</th><th>G</th><th>H</th><th>Recuento físico</th><th>F/S</th></tr></thead><tbody>
    {previewRows.map(r=><tr key={r.code}><td>{r.name}</td><td>{r.stockKnown?r.initial:'—'}</td><td>{r.stockKnown?r.extraordinary:'—'}</td><td>{r.stockKnown?r.total:'—'}</td><td>{r.stockKnown?r.consumed:'—'}</td><td>{r.stockKnown?r.final:'—'}</td><td><input className="dailyPhysicalCount" type="number" inputMode="decimal" min="0" step="any" aria-label={'Recuento físico '+r.name}
   value={counts[r.code]===undefined?'':counts[r.code]} onChange={e=>{
    const raw=e.target.value;
    setCounts(prev=>{const next={...prev};if(raw.trim()==='')delete next[r.code];else next[r.code]=Number(raw);return next})
   }}/></td><td>{r.fs===null?'—':r.fs}</td></tr>)}
   </tbody></table></div>
   <div className="kardexPagination" aria-label="Paginación de productos">
    <span>{rows.length===0?'Sin coincidencias':`Mostrando ${previewPage*pageSize+1}–${Math.min((previewPage+1)*pageSize,rows.length)} de ${rows.length}`} · Página {previewPage+1} de {pageCount}</span>
    <div><button type="button" disabled={previewPage===0} onClick={()=>setPreviewPage(p=>Math.max(0,p-1))}>Anterior</button><button type="button" disabled={previewPage>=pageCount-1} onClick={()=>setPreviewPage(p=>Math.min(pageCount-1,p+1))}>Siguiente</button></div>
   </div>
   </details>
  </>}
  {error&&<p className="kardexError" role="alert">{error}</p>}
  <div className="kardexActions"><button type="button" className="workerPrimary" disabled={!result.report?.exportable||!template||(mode==='daily'&&!turn)||busy} onClick={()=>void exportReport()}><Share2 size={18}/>{busy?'Preparando Excel…':'Generar Excel y compartir'}</button></div>
  <p className="hint">Datos ficticios. No se modifica el historial de atenciones, inventario ni movimientos al exportar. F/S se calcula únicamente a partir de los recuentos físicos introducidos; no se inventan saldos pendientes.</p>
 </section>;
}
