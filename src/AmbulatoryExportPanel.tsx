import {useMemo,useState,useRef} from 'react';
import {FileSpreadsheet,Share2} from 'lucide-react';
import {type StockLedger} from './kardexMovements';
import {buildAmbulatoryRows,type ExportVisit} from './ambulatoryRows';
import {exportAmbulatoryWorkbook} from './ambulatoryExcel';
import {shareXlsx} from './shareKardexFile';
import templateLayout from './ambulatoryTemplate.json';
import {type CatalogMappingEvent,type DeliveryIncident} from './reconciliationRules';
const iso=(d:Date)=>d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0');
function weekStart(){const d=new Date();d.setDate(d.getDate()-((d.getDay()+6)%7));return iso(d)}
type Props={attentions:ExportVisit[];ledger:StockLedger;mappings:CatalogMappingEvent[];incidents:DeliveryIncident[]};
export default function AmbulatoryExportPanel({attentions,ledger,mappings,incidents}:Props){
 const[start,setStart]=useState(weekStart),[end,setEnd]=useState(()=>iso(new Date()));
 const[template,setTemplate]=useState<Uint8Array|null>(null),[templateName,setTemplateName]=useState('');
 const[busy,setBusy]=useState(false),[error,setError]=useState(''),[subdivision,setSubdivision]=useState(''),[done,setDone]=useState('');
 const selection=useRef(0),exporting=useRef(false);
 const result=useMemo(()=>{try{return{data:buildAmbulatoryRows(attentions,ledger,start,end,{subdivision,mappings,incidents}),error:''}}
  catch(e){return{data:null,error:e instanceof Error?e.message:'No se pudo preparar la exportación.'}}},[attentions,ledger,start,end,subdivision,mappings,incidents]);
 async function select(file?:File){
  const token=++selection.current;
  setError('');setDone('');setTemplate(null);setTemplateName('');
  if(!file)return;
  if(!file.name.toLowerCase().endsWith('.xlsx')||file.size>20_000_000){setError('Selecciona el libro original XLSX de 10 hojas (máximo 20 MB).');return}
  try{const buffer=new Uint8Array(await file.arrayBuffer());if(token===selection.current){setTemplate(buffer);setTemplateName(file.name)}}
  catch{if(token===selection.current)setError('No se pudo leer el archivo seleccionado.');}
 }
 async function exportBook(){
  if(!template||!result.data||exporting.current)return;
  exporting.current=true;setBusy(true);setError('');setDone('');
  try{
   if(result.data.blockers.length)throw Error('Resuelve primero las entregas pendientes de conciliación.');
   await new Promise<void>(resolve=>requestAnimationFrame(()=>setTimeout(resolve,0)));
   const bytes=exportAmbulatoryWorkbook(template,result.data);
   const name='DANPER_Indicador_Ambulatorio_'+start+'_al_'+end+'.xlsx';
   await shareXlsx(name,bytes,'Indicador Ambulatorio DANPER');
   setDone('Excel preparado. Completa su guardado en la hoja de compartir o en Descargas.');
  }catch(e){setError(e instanceof Error?e.message:'No se pudo exportar el libro de Excel.');}
  finally{exporting.current=false;setBusy(false)}
 }
 return <section className="panel ambulatoryExport">
  <h3><FileSpreadsheet size={18}/>Indicador ambulatorio · Libro Excel original</h3>
  <p className="hint">Exportación local para registros ficticios. Selecciona el libro original de diez hojas; DANPER creará una copia sin el padrón histórico ni los vínculos externos.</p>
  <fieldset disabled={busy}><div className="fields two">
   <label>Desde<input type="date" value={start} onChange={e=>setStart(e.target.value)}/></label>
   <label>Hasta<input type="date" value={end} onChange={e=>setEnd(e.target.value)}/></label>
  </div>
  <label>Subdivisión de las atenciones del período<select value={subdivision} onChange={e=>setSubdivision(e.target.value)}><option value="">Seleccionar subdivisión</option>{templateLayout.subdivisions.map(p=><option key={p[1]} value={p[0]}>{p[0]}</option>)}</select></label>
  <p className="hint">Comprueba que todas las atenciones del período correspondan a esta subdivisión. El área de cada trabajador se conserva como unidad organizativa; su código queda vacío si no coincide con el catálogo original.</p>
  <label>Plantilla oficial · Indicador Ambulatorio (10 hojas)
   <input type="file" accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" onChange={e=>{void select(e.target.files?.[0])}}/>
  </label></fieldset>
  {template&&<p className="hint">Plantilla seleccionada: {templateName}</p>}
  {result.data&&<div className="kardexStats">
   <div><strong>{result.data.visits}</strong><span>Atenciones</span></div>
   <div><strong>{result.data.lines.length}</strong><span>Filas CONSUMOS</span></div>
   <div><strong>{result.data.linkedDeliveries}</strong><span>Entregas verificadas</span></div>
  </div>}
  {result.data?.blockers.length?<div className="kardexError" role="alert">
   <strong>Conciliaciones pendientes: {result.data.blockers.length}</strong>
   <ul>{result.data.blockers.slice(0,8).map((x,i)=><li key={i}>{x}</li>)}</ul>
   <p>La exportación queda bloqueada hasta verificar las cantidades. No se inventarán consumos.</p>
  </div>:null}
  {result.data?.warnings.length?<div className="hint" role="status"><ul>{result.data.warnings.map((x,i)=><li key={i}>{x}</li>)}</ul></div>:null}
  {(result.error||error)&&<p role="alert" className="kardexError">{result.error||error}</p>}
  <div className="kardexActions"><button type="button" className="workerPrimary"
   disabled={!template||!result.data||result.data.blockers.length>0||busy}
   onClick={()=>{void exportBook()}}><Share2 size={18}/>{busy?'Preparando Excel…':'Exportar las 10 hojas y compartir'}</button></div>
  {done&&<p role="status" className="hint">{done}</p>}
  <p className="hint">El archivo conservará las diez hojas y los 432 materiales oficiales. Los saldos no conciliados permanecen vacíos y señalados como pendientes. No modifica el inventario ni crea nuevas entregas.</p>
 </section>;
}
