import {useRef,useState} from 'react';
import {FileSpreadsheet,Upload,CheckCircle2,AlertTriangle} from 'lucide-react';
import{readPersonal}from'./workbookPersonal';import {feedback} from './nativeHaptics';
import{reconcileWorkers,type ImportResult,type WorkerRecord}from'./workerRules';
import {reviewOfficialRoster} from './officialRosterReview';
import {prepareOfficialRoster,type OperationalWorker} from './operationalRoster';
interface Props{current:WorkerRecord[];onApply:(workers:WorkerRecord[])=>void|Promise<void>;onActivateOfficial?:(workers:OperationalWorker[])=>void|Promise<void>;linkedDnis?:string[]}
export default function PersonalImporter({current,onApply,onActivateOfficial,linkedDnis=[]}:Props){
 const ref=useRef<HTMLInputElement>(null);
 const [preview,setPreview]=useState<ImportResult|null>(null);
 const [fileName,setFileName]=useState('');
 const [busy,setBusy]=useState(false);
 const [error,setError]=useState('');
 const [applied,setApplied]=useState(false);
 const estimated=preview?reconcileWorkers(current,preview.workers):null;
 let compared:ReturnType<typeof reviewOfficialRoster>|null=null;
 let reviewError='';
 if(preview&&current.length){try{compared=reviewOfficialRoster(current,preview.workers,linkedDnis)}catch(e){reviewError=e instanceof Error?e.message:'No pudo conciliarse el padrón oficial.'}}
 async function pickFile(file?:File){if(!file)return;setBusy(true);setPreview(null);setApplied(false);setError('');setFileName(file.name);
  try{setPreview(await readPersonal(file));}catch(e){setError(e instanceof Error?e.message:'No se pudo interpretar el Excel.');}
  finally{setBusy(false)}
 }
 async function activateOfficial(){if(!preview||busy||!onActivateOfficial)return;setBusy(true);setError('');try{const plan=prepareOfficialRoster(current,preview.workers,linkedDnis);if(!window.confirm('Activar padrón REAL: '+plan.officialCount+' oficiales visibles, '+plan.excludedCount+' registros anteriores fuera del buscador. Los datos antiguos y las atenciones NO se borrarán. Continúa solo si verificaste y guardaste el respaldo cifrado fuera del iPhone. ¿Confirmas?'))return;await onActivateOfficial(plan.workers);setApplied(true);setPreview(null);feedback('success')}catch(e){setError(e instanceof Error?e.message:'No se activó el padrón oficial.');feedback('error')}finally{setBusy(false)}}
 async function confirm(){if(!estimated||!preview||busy)return;setBusy(true);setError('');
  try{await onApply(estimated.workers);setApplied(true);setPreview(null);feedback('success')}
  catch(error){setError(error instanceof Error?error.message:'Error al guardar el padrón. No se ha confirmado.');feedback('error')}
  finally{setBusy(false)}
 }
 return <section className="panel importPanel"><h3><FileSpreadsheet size={18}/> Importar padrón desde Excel</h3>
 <p className="hint">Selecciona un Excel de padrón que incluya la hoja <strong>PERSONAL</strong>: se leerá únicamente esa hoja. No se importan atenciones ni historias. Los nombres y DNIs del archivo no se incorporan al código de la aplicación.</p>
 <input ref={ref} type="file" accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" aria-label="Seleccionar Excel de trabajadores" onChange={e=>void pickFile(e.target.files?.[0])} className="importInput" />
 <button type="button" className="workerSecondary wide" onClick={()=>{if(ref.current)ref.current.value='';ref.current?.click()}} disabled={busy}><Upload size={16}/>{busy?'Procesando archivo...':'Seleccionar Excel (.xlsx)'}</button>
 {fileName&&<p className="hint">Archivo seleccionado: {fileName}</p>}
 {error&&<p role="alert" className="importError"><AlertTriangle size={16}/> {error}</p>}
 {applied&&<p role="status" className="importSuccess"><CheckCircle2 size={16}/> Padrón incorporado y guardado. Busca al trabajador por DNI o nombre.</p>}
 {preview&&estimated&&<div className="importPreview"><strong>Vista previa de importación</strong><div className="previewStats"><div><b>{preview.stats.valid}</b><span>DNIs únicos válidos</span></div><div><b>{estimated.stats.added}</b><span>Nuevos</span></div><div><b>{estimated.stats.merged}</b><span>Ya existentes</span></div></div>
 <p className="hint">DNI inválido: {preview.stats.invalidDni}. Sin nombre: {preview.stats.withoutName}. DNI repetido dentro del Excel: {preview.stats.duplicates}. Sexo vacío: {preview.stats.sexMissing}. Sexo fuera del catálogo: {preview.stats.sexInvalid}. Sexo contradictorio entre duplicados: {preview.stats.sexConflicts}. Fichas manuales conservadas: {estimated.stats.manualPreserved}.</p>
 <p className="hint">Comparación con el padrón existente: {estimated.stats.added} nuevos, {estimated.stats.merged} ya registrados. Cambios de nombres por revisar: {estimated.stats.nameConflicts}. Cambios M/F por revisar: {estimated.stats.sexConflicts}. Los DNI existentes conservan una sola ficha.</p>
 {(preview.stats.sexConflicts>0||preview.stats.sexInvalid>0||estimated.stats.nameConflicts>0||estimated.stats.sexConflicts>0)&&<p className="kardexError" role="alert">Hay datos de identidad o sexo que requieren verificación. Nunca se deduce el sexo por el nombre; si un DNI ya existe, no se reemplazan automáticamente nombres ni sexos contradictorios.</p>}
 <p className="hint"><strong>La app respeta los cambios manuales existentes</strong> y completa sus campos vacíos con datos importados. Puedes revisar antes de confirmar.</p>
 {reviewError&&<p className="importError" role="alert">Revisión bloqueada: {reviewError}. No se eliminó ningún trabajador.</p>}
 {compared&&<section className="panel" aria-label="Conciliación de padrón oficial (solo lectura)">
  <h4>Revisión del padrón REAL: únicamente vista previa</h4>
  <p className="hint">El Excel PERSONAL es la referencia de DNI reales. No basta con que un DNI no aparezca para asegurar que sea ficticio; esta pantalla no borra ningún trabajador.</p>
  <p className="hint">Actualmente: <strong>{compared.currentCount}</strong> trabajadores. Excel: <strong>{compared.officialCount}</strong> DNI. Coinciden: <strong>{compared.matchingDni}</strong>. Ausentes del Excel: <strong>{compared.absentFromOfficial}</strong>.</p>
  <p className="hint">Requieren revisión individual: <strong>{compared.eligibleForFurtherReview}</strong>. Protegidos por creación manual o vínculos clínicos: <strong>{compared.protectedAbsent}</strong> (manuales {compared.protectedManual}; con atenciones/alergias {compared.protectedLinked}). Nombres discordantes para el mismo DNI: <strong>{compared.nameDiscrepancies}</strong>.</p>
  <p className="kardexError" role="status">No se eliminará a nadie al confirmar una importación. La depuración necesita un respaldo externo verificado y otra confirmación específica; la activación solo oculta registros anteriores del directorio operativo y NO borra el historial. Si existen diferencias, se bloqueará.</p>
 </section>}
 <div className="importSample"><span>Muestra de registros reconocidos:</span>{preview.workers.slice(0,3).map(w=><div key={w.dni}>{w.dni} — {w.name}</div>)}</div>
 <div className="actions"><button type="button" className="secondary" onClick={()=>setPreview(null)}>Cancelar</button><button type="button" className="primary" onClick={()=>void confirm()} disabled={busy}><CheckCircle2 size={17}/> Importación habitual (sin depurar)</button>{onActivateOfficial&&<button type="button" className="workerPrimary" onClick={()=>void activateOfficial()} disabled={busy||Boolean(reviewError)||preview.stats.invalidDni>0||preview.stats.withoutName>0||preview.stats.duplicates>0||preview.stats.nameConflicts>0||preview.stats.sexConflicts>0||preview.stats.sexInvalid>0}>Activar únicamente padrón REAL (reversible)</button>}</div></div>}
 <p className="hint">En iPhone el padrón se guarda localmente en un archivo cifrado AES-GCM, con clave privada en Keychain. El navegador sigue siendo un entorno de prueba sin cifrar. La información clínica todavía requiere una migración a una base segura antes de su uso real.</p>
 </section>
}
