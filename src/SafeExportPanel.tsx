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
 // Verification uses its OWN password: creating a backup must not require
 // keeping the export password in memory, and a failed check retains the file.
 const [verifyPassword,setVerifyPassword]=useState('');
 const [verifyFileSelection,setVerifyFileSelection]=useState<File|null>(null);
 const [verifying,setVerifying]=useState(false);
 const [verifyStatus,setVerifyStatus]=useState('');
 const [verifyError,setVerifyError]=useState('');
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
 async function verifySelectedFile(){
  setVerifyStatus('');setVerifyError('');
  if(!native||busy||sharing||verifying)return;
  const file=verifyFileSelection;
  if(!file){setVerifyError('Selecciona primero el archivo .danperbackup guardado en Archivos.');return}
  if(!file.name.toLowerCase().endsWith('.danperbackup')||file.size>42*1024*1024||file.size<100){
   setVerifyError('El archivo seleccionado no es un respaldo .danperbackup válido de hasta 42 MB.');return
  }
  if(verifyPassword.length<14){
   setVerifyError('Introduce aquí la contraseña original con la que creaste este respaldo (al menos 14 caracteres).');
   return
  }
  setVerifying(true);setVerifyStatus('Comprobando contraseña y autenticidad del respaldo…');
  try{
   const snapshot=validateDemoSnapshot(await decryptPortableBackup(await file.text(),verifyPassword));
   setVerifyStatus('Respaldo comprobado correctamente: '+snapshot.workers.length+' trabajadores y '+snapshot.attentions.length+' atenciones. Ningún dato fue restaurado, eliminado ni modificado.');
   setVerifyPassword(''); // do not retain the secret after successful verification
   feedback('success');
  }catch(e){
   // Keep file and input available so the user can correct a typing error.
   setVerifyStatus('');
   setVerifyError(e instanceof Error?e.message:'No se pudo verificar el archivo. Comprueba la contraseña original.');
   feedback('error');
  }finally{setVerifying(false)}
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
  <section className="backupVerifySection" aria-label="Comprobar respaldo cifrado guardado">
   <h4>Comprobar el archivo guardado</h4>
   <p className="hint">Esta operación <strong>solo comprueba</strong> que el respaldo guardado pueda descifrarse. No restaura, mezcla ni elimina trabajadores o atenciones.</p>
   <label>Archivo cifrado guardado en Archivos
    <input type="file" accept=".danperbackup" disabled={!native||busy||sharing||verifying} onChange={e=>{
      const file=e.currentTarget.files?.[0]??null;
      setVerifyFileSelection(file);setVerifyStatus('');setVerifyError('');
      e.currentTarget.value='';
    }}/>
   </label>
   {verifyFileSelection&&<p className="hint" role="status">Seleccionado: {verifyFileSelection.name}</p>}
   <label>Contraseña del archivo de respaldo (para comprobarlo)
    <input type="password" autoComplete="off" value={verifyPassword}
      onChange={e=>{setVerifyPassword(e.target.value);setVerifyError('');setVerifyStatus('')}}
      placeholder="Escribe la contraseña original del respaldo" disabled={!native||busy||sharing||verifying}/>
   </label>
   <button type="button" className="workerPrimary wide"
    disabled={!native||busy||sharing||verifying}
    onClick={()=>void verifySelectedFile()}>{verifying?'Verificando respaldo…':'Verificar respaldo seleccionado'}</button>
   {(verifyStatus||verifyError)&&<div className="backupFeedback" aria-live="polite">
    {verifyStatus&&<p role="status">{verifyStatus}</p>}
    {verifyError&&<p className="importError" role="alert">{verifyError}</p>}
   </div>}
  </section>
  {!native&&<p className="hint">La exportación privada solo funciona dentro de la aplicación nativa de iPhone.</p>}
 </section>;
}
