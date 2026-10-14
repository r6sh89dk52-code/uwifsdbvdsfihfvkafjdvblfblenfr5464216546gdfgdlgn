import {useState} from 'react';
import {migrateFromVerifiedPortableBackup} from './secureDemoStore';
import {feedback} from './nativeHaptics';

/** No app state mounts while this gate is visible. Nothing is exported,
 * uploaded or changed until user supplies their local backup and password.
 */
export default function ClinicalMigrationGate(){
 const [selected,setSelected]=useState<File|null>(null);
 const [password,setPassword]=useState('');
 const [busy,setBusy]=useState(false);
 const [status,setStatus]=useState('');
 const [error,setError]=useState('');
 async function proceed(){
  if(busy)return;
  setError('');setStatus('');
  if(!selected){setError('Selecciona el archivo .danperbackup que verificaste anteriormente.');return}
  if(password.length<14){setError('Ingresa la contraseña original de ese respaldo (al menos 14 caracteres).');return}
  setBusy(true);setStatus('Comprobando que el respaldo coincida exactamente con la base actual…');
  try{
   const result=await migrateFromVerifiedPortableBackup(await selected.text(),password);
   setPassword('');
   setStatus('Migración cifrada verificada: '+result.workers.length+' trabajadores y '+result.attentions.length+' atenciones. Reabriendo…');
   feedback('success');
   window.location.reload();
  }catch(e){
   setStatus('');
   setError(e instanceof Error?e.message:'No fue posible completar la comprobación. Los registros anteriores deben conservarse.');
   feedback('error');
  }finally{setBusy(false)}
 }
 return <div className="app"><main className="secureLoading migrationGate">
  <h1>Protección de tus registros</h1>
  <p role="status">Detectamos tu padrón y tus registros del formato anterior. La nueva versión no los migrará sin comprobar antes tu respaldo externo cifrado.</p>
  <section className="panel">
   <h3>1. Selecciona tu respaldo verificado</h3>
   <p className="hint">El mismo archivo .danperbackup que ya guardaste en Archivos y comprobaste con su contraseña en la versión anterior. El archivo se procesa únicamente en el iPhone.</p>
   <label>Archivo cifrado
    <input type="file" accept=".danperbackup" disabled={busy} onChange={e=>{
     const file=e.currentTarget.files?.[0]??null;
     if(file&&(file.size>42*1024*1024||file.size<100||!file.name.toLowerCase().endsWith('.danperbackup'))){
      setSelected(null);setError('Selecciona un archivo .danperbackup válido de hasta 42 MB.');
     }else{setSelected(file);setError('')}
     e.currentTarget.value='';
    }}/>
   </label>
   {selected&&<p className="hint">Archivo seleccionado: {selected.name}</p>}
   <h3>2. Introduce su contraseña</h3>
   <label>Contraseña original del respaldo
    <input type="password" autoComplete="off" value={password} disabled={busy}
     placeholder="Contraseña del archivo, no la de tu iPhone"
     onChange={e=>{setPassword(e.target.value);setError('')}}/>
   </label>
   <p className="hint">Si algún trabajador, atención, movimiento o existencia ha cambiado después de crear la copia, tendrás que generar y comprobar una más reciente desde la versión anterior. Nunca se mezclan dos bases diferentes automáticamente.</p>
   <button type="button" className="workerPrimary wide" disabled={busy} onClick={()=>void proceed()}>
    {busy?'Comprobando y protegiendo los registros…':'Comprobar respaldo e iniciar migración'}
   </button>
   {status&&<p role="status" className="hint">{status}</p>}
   {error&&<p className="importError" role="alert">{error}</p>}
  </section>
  <p className="hint">No desinstales la aplicación ni borres sus datos. Si no tienes un respaldo actualizado, conserva el archivo anterior y consulta antes de continuar.</p>
 </main></div>;
}
