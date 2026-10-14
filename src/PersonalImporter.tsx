import {useRef,useState} from 'react';
import {FileSpreadsheet,Upload,CheckCircle2,AlertTriangle} from 'lucide-react';
import{readPersonal}from'./workbookPersonal';
import{reconcileWorkers,type ImportResult,type WorkerRecord}from'./workerRules';
interface Props{current:WorkerRecord[];onApply:(workers:WorkerRecord[])=>void}
export default function PersonalImporter({current,onApply}:Props){
 const ref=useRef<HTMLInputElement>(null);
 const [preview,setPreview]=useState<ImportResult|null>(null);
 const [fileName,setFileName]=useState('');
 const [busy,setBusy]=useState(false);
 const [error,setError]=useState('');
 const [applied,setApplied]=useState(false);
 const estimated=preview?reconcileWorkers(current,preview.workers):null;
 async function pickFile(file?:File){if(!file)return;setBusy(true);setPreview(null);setApplied(false);setError('');setFileName(file.name);
  try{setPreview(await readPersonal(file));}catch(e){setError(e instanceof Error?e.message:'No se pudo interpretar el Excel.');}
  finally{setBusy(false)}
 }
 function confirm(){if(!estimated||!preview)return;onApply(estimated.workers);setApplied(true);setPreview(null);}
 return <section className="panel importPanel"><h3><FileSpreadsheet size={18}/> Importar padrón desde Excel</h3>
 <p className="hint">Selecciona un Excel de padrón que incluya la hoja <strong>PERSONAL</strong>: se leerá únicamente esa hoja. No se importan atenciones ni historias. Los nombres y DNIs del archivo no se incorporan al código de la aplicación.</p>
 <input ref={ref} type="file" accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" aria-label="Seleccionar Excel de trabajadores" onChange={e=>void pickFile(e.target.files?.[0])} className="importInput" />
 <button type="button" className="workerSecondary wide" onClick={()=>{if(ref.current)ref.current.value='';ref.current?.click()}} disabled={busy}><Upload size={16}/>{busy?'Procesando archivo...':'Seleccionar Excel (.xlsx)'}</button>
 {fileName&&<p className="hint">Archivo seleccionado: {fileName}</p>}
 {error&&<p role="alert" className="importError"><AlertTriangle size={16}/> {error}</p>}
 {applied&&<p role="status" className="importSuccess"><CheckCircle2 size={16}/> Padrón de prueba incorporado. Busca al trabajador por DNI o nombre.</p>}
 {preview&&estimated&&<div className="importPreview"><strong>Vista previa de importación</strong><div className="previewStats"><div><b>{preview.stats.valid}</b><span>DNIs únicos válidos</span></div><div><b>{estimated.stats.added}</b><span>Nuevos</span></div><div><b>{estimated.stats.merged}</b><span>Ya existentes</span></div></div>
 <p className="hint">DNI inválido: {preview.stats.invalidDni}. Sin nombre: {preview.stats.withoutName}. DNI repetido dentro del Excel: {preview.stats.duplicates}. Sexo vacío: {preview.stats.sexMissing}. Sexo fuera del catálogo: {preview.stats.sexInvalid}. Sexo contradictorio entre duplicados: {preview.stats.sexConflicts}. Fichas manuales conservadas: {estimated.stats.manualPreserved}.</p>
 {(preview.stats.sexConflicts>0||preview.stats.sexInvalid>0)&&<p className="kardexError" role="alert">Hay valores de sexo que requieren verificación. No se deducirá el sexo por el nombre ni se elegirán códigos contradictorios automáticamente.</p>}
 <p className="hint"><strong>La app respeta los cambios manuales existentes</strong> y completa sus campos vacíos con datos importados. Puedes revisar antes de confirmar.</p>
 <div className="importSample"><span>Muestra de registros reconocidos:</span>{preview.workers.slice(0,3).map(w=><div key={w.dni}>{w.dni} — {w.name}</div>)}</div>
 <div className="actions"><button type="button" className="secondary" onClick={()=>setPreview(null)}>Cancelar</button><button type="button" className="primary" onClick={confirm}><CheckCircle2 size={17}/> Confirmar importación</button></div></div>}
 <p className="hint">En iPhone el padrón se guarda localmente en un archivo cifrado AES-GCM, con clave privada en Keychain. El navegador sigue siendo un entorno de prueba sin cifrar. La información clínica todavía requiere una migración a una base segura antes de su uso real.</p>
 </section>
}
