import {useState} from 'react';
import {Capacitor} from '@capacitor/core';
import {Share} from '@capacitor/share';
import {validateDemoSnapshot} from './secureDemoStore';
import {decryptPortableBackup} from './portableBackup';
import {prepareEncryptedBackup,type PreparedBackup} from './safeBackupFile';
import {feedback} from './nativeHaptics';

export default function SafeExportPanel(){
 const native=Capacitor.isNativePlatform()&&Capacitor.getPlatform()==='ios';
 const [secret,setSecret]=useState(''),[confirm,setConfirm]=useState('');
 const [busy,setBusy]=useState(false),[sharing,setSharing]=useState(false);
 const [prepared,setPrepared]=useState<PreparedBackup|null>(null);
 const [status,setStatus]=useState(''),[error,setError]=useState('');
 const mismatch=confirm.length>0&&secret!==confirm;
 const ready=secret.length>=14&&secret===confirm;
 async function prepare(){
  if(!native||busy||sharing)return;
  setError('');setStatus('');setPrepared(null);
  if(secret.length<14){setError('La contraseña necesita como mínimo 14 caracteres.');feedback('warning');return}
  if(secret!==confirm){setError('Las contraseñas no coinciden exactamente. Revisa mayúsculas, espacios y símbolos.');feedback('warning');return}
  setBusy(true);
  try{
   const result=await prepareEncryptedBackup(secret,setStatus);
   setPrepared(result);
   setStatus('Respaldo cifrado creado y comprobado. Ahora toca «Compartir / Guardar en Archivos».');
   feedback('success');
  }catch(e){
   setError('No se pudo preparar el respaldo: '+(e instanceof Error?e.message:'error de almacenamiento desconocido.'));
   feedback('error');
  }finally{setBusy(false)}
 }
 async function sharePrepared(){
  if(!native||!prepared||sharing||busy)return;
  setError('');setSharing(true);setStatus('Abriendo la hoja de compartir de iOS…');
  try{
   // This is invoked directly from a second user tap. The data is already
   // encrypted and written, so no lengthy operations delay the share sheet.
   await Share.share({title:'Respaldo cifrado DANPER Salud Móvil',url:prepared.uri,dialogTitle:'Guardar en Archivos o compartir'});
   setStatus('Hoja de compartir cerrada. Comprueba en Archivos que el respaldo esté guardado fuera de la aplicación.');
   feedback('success');
  }catch(e){
   setError('No se pudo abrir Compartir en iOS: '+(e instanceof Error?e.message:'fallo del sistema.'));
   setStatus('El archivo cifrado sigue preparado en la aplicación. Puedes volver a pulsar Compartir.');
   feedback('error');
  }finally{setSharing(false)}
 }
 async function verifyFile(file:File|undefined){
  setError('');setStatus('');
  if(!native||!file||busy||sharing)return;
  if(!file.name.toLowerCase().endsWith('.danperbackup')||file.size>42*1024*1024){
   setError('Selecciona un archivo de respaldo .danperbackup de hasta 42 MB.');return
  }
  if(secret.length<14){setError('Introduce primero la contraseña del respaldo que deseas comprobar.');return}
  setBusy(true);setStatus('Leyendo y autenticando el archivo seleccionado…');
  try{
   const snapshot=validateDemoSnapshot(await decryptPortableBackup(await file.text(),secret));
   setStatus('Archivo externo verificado: '+snapshot.workers.length+' trabajadores y '+snapshot.attentions.length+' atenciones. Ningún registro fue modificado.');
   feedback('success');
  }catch(e){
   setError(e instanceof Error?e.message:'No se pudo verificar el respaldo externo.');
   feedback('error');
  }finally{setBusy(false)}
 }
 return <section className="panel safeExportPanel">
  <h3>Respaldo cifrado de seguridad</h3>
  <p className="hint">Esta versión conserva el almacenamiento actual. El respaldo cifrado incluye trabajadores, atenciones, alergias, inventario y conciliaciones; no se sube a GitHub.</p>
  <label>Contraseña del respaldo
   <input type="password" autoComplete="off" value={secret} onChange={e=>{setSecret(e.target.value);setPrepared(null);setError('')}} placeholder="14 caracteres como mínimo" disabled={!native||busy||sharing}/>
  </label>
  <label>Repetir contraseña
   <input type="password" autoComplete="off" value={confirm} onChange={e=>{setConfirm(e.target.value);setPrepared(null);setError('')}} placeholder="Confirmar contraseña" disabled={!native||busy||sharing}/>
  </label>
  <p className="hint" role="status">{secret.length<14?'Contraseña: faltan '+(14-secret.length)+' caracteres.':mismatch?'Las contraseñas todavía no coinciden.':ready?'Contraseña válida y coincidente. Puedes preparar el respaldo.':'Repite la contraseña para continuar.'}</p>
  <p className="hint">Conserva la contraseña fuera del iPhone. Sin ella no será posible recuperar el respaldo.</p>
  <button type="button" className="workerPrimary wide" disabled={!native||busy||sharing} onClick={()=>void prepare()}>
   {busy?'Preparando el respaldo…':'1. Crear y verificar respaldo cifrado'}
  </button>
  {prepared&&<div className="backupPrepared">
   <strong>Archivo cifrado listo</strong>
   <p className="hint">{prepared.name} · Archivo temporal; debes guardarlo fuera de la aplicación.</p>
   <button type="button" className="workerPrimary wide" disabled={busy||sharing} onClick={()=>void sharePrepared()}>
    {sharing?'Abriendo Compartir…':'2. Compartir / Guardar en Archivos'}
   </button>
  </div>}
  {(status||error)&&<div className="backupFeedback" aria-live="polite">
   {status&&<p role="status">{status}</p>}
   {error&&<p className="importError" role="alert">{error}</p>}
  </div>}
  <h4>Comprobar el archivo guardado</h4>
  <p className="hint">Después de guardar una copia en Archivos, selecciónala aquí para confirmar que tu contraseña la descifra. No restaura ni elimina información.</p>
  <input type="file" accept=".danperbackup" disabled={!native||busy||sharing} onChange={e=>{const file=e.currentTarget.files?.[0];void verifyFile(file);e.currentTarget.value=''}}/>
  {!native&&<p className="hint">La exportación privada solo funciona dentro de la aplicación nativa de iPhone.</p>}
 </section>;
}
