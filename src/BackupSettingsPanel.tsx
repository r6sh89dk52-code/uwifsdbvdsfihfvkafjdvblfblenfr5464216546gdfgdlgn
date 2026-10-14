import {useState} from 'react';
import {Capacitor} from '@capacitor/core';
import {Directory,Filesystem} from '@capacitor/filesystem';
import {Share} from '@capacitor/share';
import {encryptPortableBackup,decryptPortableBackup} from './portableBackup';
import {loadDemoSnapshot,validateDemoSnapshot,hasActiveRecords,restoreEmptyDeviceFromBackup,type DemoSnapshot} from './secureDemoStore';
import {feedback} from './nativeHaptics';

function base64Utf8(value:string):string{
 const bytes=new TextEncoder().encode(value);
 let text='';
 for(let i=0;i<bytes.length;i+=8192)text+=String.fromCharCode(...bytes.subarray(i,i+8192));
 return btoa(text);
}
export default function BackupSettingsPanel(){
 const native=Capacitor.isNativePlatform()&&Capacitor.getPlatform()==='ios';
 const [password,setPassword]=useState('');
 const [confirmation,setConfirmation]=useState('');
 const [busy,setBusy]=useState(false);
 const [status,setStatus]=useState('');
 const [error,setError]=useState('');
 const [preview,setPreview]=useState<DemoSnapshot|null>(null);
 const [sourceName,setSourceName]=useState('');
 async function makeBackup(){
  if(!native||busy)return;
  setError('');setStatus('');
  if(password.length<14||password!==confirmation){setError('La contraseña debe tener al menos 14 caracteres y ambas entradas deben coincidir.');return}
  setBusy(true);
  try{
   const snapshot=validateDemoSnapshot(await loadDemoSnapshot());
   const encrypted=await encryptPortableBackup(snapshot,password);
   const name='DANPER-Respaldo-'+new Date().toISOString().slice(0,10)+'.danperbackup';
   const result=await Filesystem.writeFile({path:name,directory:Directory.Cache,data:base64Utf8(encrypted)});
   await Share.share({title:'Respaldo cifrado DANPER Salud Móvil',url:result.uri,dialogTitle:'Guardar respaldo cifrado fuera del iPhone'});
   setPassword('');setConfirmation('');
   setStatus('Respaldo cifrado preparado. Comprueba en Archivos que realmente quedó guardado en una ubicación recuperable.');
   feedback('success');
  }catch(err){
   setError(err instanceof Error?err.message:'No se pudo generar o compartir el respaldo.');
   feedback('error');
  }finally{setBusy(false)}
 }
 async function inspectBackup(file:File|undefined){
  setPreview(null);setSourceName('');setError('');setStatus('');
  if(!file||busy)return;
  if(!native){setError('La restauración privada está disponible únicamente en iPhone.');return}
  if(file.size>42*1024*1024||!file.name.toLowerCase().endsWith('.danperbackup')){
   setError('Selecciona un respaldo .danperbackup válido de hasta 42 MB.');return;
  }
  if(password.length<14){setError('Ingresa la contraseña del archivo antes de seleccionarlo.');return}
  setBusy(true);
  try{
   const current=validateDemoSnapshot(await loadDemoSnapshot());
   if(hasActiveRecords(current))throw Error('La base actual tiene registros. Por seguridad solo puede restaurarse en una instalación vacía; no se sobrescribirá.');
   const contents=await file.text();
   const decoded=await decryptPortableBackup(contents,password);
   const data=validateDemoSnapshot(decoded);
   if(!Array.isArray(data.workers)||data.workers.length>30000)throw Error('Padrón del respaldo inválido.');
   setPreview(data);setSourceName(file.name);
   setStatus('Respaldo descifrado y examinado; todavía NO se modificó la base de datos.');
  }catch(err){
   setError(err instanceof Error?err.message:'No se pudo verificar el respaldo.');
   feedback('error');
  }finally{setBusy(false)}
 }
 async function restoreBackup(){
  if(!native||!preview||busy)return;
  if(!window.confirm('Esta operación recuperará el padrón y todos los registros del respaldo en esta BASE VACÍA. ¿Confirmas la restauración?'))return;
  setBusy(true);setError('');setStatus('');
  try{
   await restoreEmptyDeviceFromBackup(preview);
   setPreview(null);setPassword('');setConfirmation('');
   setStatus('Restauración verificada. Reabriendo la aplicación.');
   feedback('success');
   window.location.reload();
  }catch(err){
   setError(err instanceof Error?err.message:'La restauración fue interrumpida. No elimines los datos; vuelve a abrir la aplicación.');
   feedback('error');
  }finally{setBusy(false)}
 }
 return <section className="panel backupPanel">
  <h3>Respaldo y recuperación</h3>
  <p className="hint">Copia cifrada con contraseña independiente de Keychain: incluye trabajadores, atenciones, alergias, inventario, entregas y conciliaciones. No se envía a GitHub ni a un servidor.</p>
  {!native&&<p className="hint" role="status">Solo disponible en la aplicación nativa de iPhone. El navegador continúa siendo un entorno de pruebas.</p>}
  <label className="backupLabel">Contraseña privada del respaldo
   <input type="password" autoComplete="off" value={password} onChange={e=>setPassword(e.target.value)} placeholder="Mínimo 14 caracteres" disabled={busy||!native}/>
  </label>
  <p className="hint">Guárdala fuera del iPhone: si la olvidas, ningún técnico podrá descifrar el respaldo.</p>
  <label className="backupLabel">Confirmar contraseña (para crear copia)
   <input type="password" autoComplete="off" value={confirmation} onChange={e=>setConfirmation(e.target.value)} placeholder="Repetir contraseña" disabled={busy||!native}/>
  </label>
  <button type="button" className="workerPrimary wide" disabled={!native||busy||password.length<14||password!==confirmation} onClick={()=>void makeBackup()}>
   {busy?'Procesando…':'Crear y compartir respaldo cifrado'}
  </button>
  <hr/>
  <h4>Restaurar desde un respaldo</h4>
  <p className="hint">Por seguridad no se mezclan ni sobrescriben bases existentes. Solo se permite recuperar en un iPhone con la base vacía y después de comprobar la contraseña.</p>
  <label className="backupLabel">Archivo de respaldo cifrado
   <input type="file" accept=".danperbackup" disabled={!native||busy} onChange={e=>{const file=e.currentTarget.files?.[0];void inspectBackup(file);e.currentTarget.value=''}}/>
  </label>
  {preview&&<div className="backupPreview">
   <strong>Respaldo verificado: {sourceName}</strong>
   <p>{preview.workers.length} trabajadores · {preview.attentions.length} atenciones · {preview.stockLots.length} lotes · {preview.stockMovements.length} movimientos</p>
   <button type="button" className="workerPrimary wide" disabled={!native||busy} onClick={()=>void restoreBackup()}>Confirmar recuperación en base vacía</button>
  </div>}
  {status&&<p className="hint" role="status">{status}</p>}
  {error&&<p className="importError" role="alert">{error}</p>}
 </section>;
