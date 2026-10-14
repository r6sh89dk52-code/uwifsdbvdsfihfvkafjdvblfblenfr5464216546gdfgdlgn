import {useState} from 'react';
import {Capacitor} from '@capacitor/core';
import {Directory,Filesystem} from '@capacitor/filesystem';
import {Share} from '@capacitor/share';
import {readStableSnapshotForBackup,validateDemoSnapshot} from './secureDemoStore';
import {encryptPortableBackup} from './portableBackup';
import {feedback} from './nativeHaptics';
function fileBase64(s:string):string{
 const bytes=new TextEncoder().encode(s);let out='';
 for(let i=0;i<bytes.length;i+=8192)out+=String.fromCharCode(...bytes.subarray(i,i+8192));
 return btoa(out);
}
export default function SafeExportPanel(){
 const native=Capacitor.isNativePlatform()&&Capacitor.getPlatform()==='ios';
 const [secret,setSecret]=useState(''),[confirm,setConfirm]=useState('');
 const [busy,setBusy]=useState(false),[status,setStatus]=useState(''),[error,setError]=useState('');
 async function saveBackup(){
  if(!native||busy)return;
  setStatus('');setError('');
  if(secret.length<14||secret!==confirm){setError('La contraseña debe tener al menos 14 caracteres y coincidir en los dos campos.');return}
  setBusy(true);
  try{
   const snapshot=validateDemoSnapshot(await readStableSnapshotForBackup());
   const encrypted=await encryptPortableBackup(snapshot,secret);
   const filename='DANPER-Respaldo-'+new Date().toISOString().slice(0,10)+'.danperbackup';
   const file=await Filesystem.writeFile({path:filename,directory:Directory.Cache,data:fileBase64(encrypted)});
   await Share.share({title:'Copia cifrada de DANPER Salud Móvil',url:file.uri,dialogTitle:'Guardar respaldo cifrado fuera del iPhone'});
   setSecret('');setConfirm('');
   setStatus('Respaldo cifrado creado. Verifica que realmente quedó guardado fuera del dispositivo.');
   feedback('success');
  }catch(e){
   setError(e instanceof Error?e.message:'Error al crear o compartir el respaldo.');
   feedback('error');
  }finally{setBusy(false)}
 }
 return <section className="panel safeExportPanel">
  <h3>Respaldo cifrado de seguridad</h3>
  <p className="hint">Versión puente: exporta trabajadores, atenciones, inventario, alergias y reportes sin cambiar el almacenamiento actual. El archivo es privado y no se envía a GitHub.</p>
  <label>Contraseña del respaldo
   <input type="password" autoComplete="off" value={secret} onChange={e=>setSecret(e.target.value)} placeholder="14 caracteres como mínimo" disabled={!native||busy}/>
  </label>
  <label>Repetir contraseña
   <input type="password" autoComplete="off" value={confirm} onChange={e=>setConfirm(e.target.value)} placeholder="Confirmar contraseña" disabled={!native||busy}/>
  </label>
  <p className="hint">Guarda esta contraseña en un lugar seguro fuera del iPhone. Si se pierde, el respaldo no se podrá descifrar. Comprueba que el archivo aparece en Archivos o en otra ubicación segura.</p>
  <button type="button" className="workerPrimary wide" disabled={!native||busy||secret.length<14||secret!==confirm} onClick={()=>void saveBackup()}>{busy?'Cifrando…':'Crear y compartir respaldo cifrado'}</button>
  {!native&&<p className="hint">Esta función está disponible únicamente en la app nativa para iPhone.</p>}
  {status&&<p className="hint" role="status">{status}</p>}
  {error&&<p className="importError" role="alert">{error}</p>}
 </section>;
}
