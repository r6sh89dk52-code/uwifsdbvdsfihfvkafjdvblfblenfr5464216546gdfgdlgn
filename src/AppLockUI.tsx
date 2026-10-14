import {useEffect,useState,type ReactNode} from 'react';
import {Capacitor} from '@capacitor/core';
import {appLockEnabled,enableAppLock,disableAppLock,unlockAppLock} from './localAppLock';
import {feedback} from './nativeHaptics';
function native(){return Capacitor.isNativePlatform()&&Capacitor.getPlatform()==='ios'}
/** Gate at the root prevents loading clinical records and running autosaves
 * until the user's additional app passphrase has been verified.
 */
export function AppLockShell({children}:{children:ReactNode}){
 const [state,setState]=useState<'checking'|'locked'|'unlocked'|'error'>('checking');
 const [pass,setPass]=useState(''),[error,setError]=useState(''),[busy,setBusy]=useState(false);
 useEffect(()=>{
  let live=true;
  void appLockEnabled().then(enabled=>{if(live)setState(enabled?'locked':'unlocked')})
   .catch(e=>{if(live){setError(e instanceof Error?e.message:'No se pudo leer la clave de acceso.');setState('error')}});
  return()=>{live=false};
 },[]);
 async function open(){
  if(busy||state!=='locked')return;
  setBusy(true);setError('');
  try{
   const ok=await unlockAppLock(pass);
   if(!ok){setError('La contraseña es incorrecta.');feedback('warning');return}
   setPass('');setState('unlocked');feedback('success');
  }catch(e){setError(e instanceof Error?e.message:'No fue posible verificar el acceso.');feedback('error')}
  finally{setBusy(false)}
 }
 if(state==='unlocked')return <>{children}</>;
 return <div className="app"><main className="secureLoading appLockScreen">
  <h1>Acceso protegido</h1>
  {state==='checking'&&<p>Comprobando la protección del iPhone…</p>}
  {state==='error'&&<p role="alert">{error} No se han borrado los registros.</p>}
  {state==='locked'&&<section className="panel">
   <h3>Desbloquear DANPER Salud Móvil</h3>
   <p className="hint">Introduce la contraseña de acceso configurada dentro de esta aplicación. No es la contraseña del respaldo ni el código de desbloqueo del iPhone.</p>
   <label>Contraseña de acceso
    <input type="password" autoComplete="off" value={pass} disabled={busy} onChange={e=>setPass(e.target.value)} placeholder="Contraseña de la aplicación"/>
   </label>
   <button type="button" className="workerPrimary wide" disabled={busy} onClick={()=>void open()}>{busy?'Verificando…':'Desbloquear aplicación'}</button>
   {error&&<p role="alert" className="importError">{error}</p>}
  </section>}
 </main></div>;
}
export function AppLockSettings(){
 const [enabled,setEnabled]=useState<boolean|null>(null);
 const [pass,setPass]=useState(''),[again,setAgain]=useState(''),[current,setCurrent]=useState('');
 const [busy,setBusy]=useState(false),[error,setError]=useState(''),[status,setStatus]=useState('');
 useEffect(()=>{let live=true;void appLockEnabled().then(v=>{if(live)setEnabled(v)}).catch(e=>{if(live)setError(e instanceof Error?e.message:String(e))});return()=>{live=false}},[]);
 async function configure(action:'enable'|'disable'){
  if(busy||enabled===null)return;
  setError('');setStatus('');
  if(action==='enable'&&(pass.length<12||pass!==again)){setError('La contraseña nueva debe tener al menos 12 caracteres y coincidir en ambos campos.');return}
  if(action==='disable'&&!current){setError('Ingresa la contraseña actual para desactivar el bloqueo.');return}
  setBusy(true);
  try{
   if(action==='enable'){await enableAppLock(pass);setEnabled(true);setStatus('Bloqueo configurado. Se solicitará la contraseña al volver a abrir la app.');feedback('success')}
   else{await disableAppLock(current);setEnabled(false);setStatus('Bloqueo desactivado. Los registros no se han borrado.');feedback('success')}
   setPass('');setAgain('');setCurrent('');
  }catch(e){setError(e instanceof Error?e.message:'No fue posible cambiar la protección.');feedback('error')}
  finally{setBusy(false)}
 }
 return <section className="panel appLockSettings">
  <h3>Protección de acceso</h3>
  <p className="hint">Contraseña adicional para abrir DANPER Salud Móvil. Está protegida mediante un verificador en Keychain; nunca se guarda en texto claro. Esta función no es Face ID ni sustituye el bloqueo del iPhone.</p>
  {!native()&&<p className="hint">Solo disponible en la app nativa para iPhone.</p>}
  {enabled===null&&<p>Comprobando el estado del bloqueo…</p>}
  {enabled===false&&<><label>Nueva contraseña de la aplicación (12 caracteres como mínimo)<input type="password" autoComplete="off" disabled={busy} value={pass} onChange={e=>setPass(e.target.value)}/></label>
  <label>Repetir contraseña<input type="password" autoComplete="off" disabled={busy} value={again} onChange={e=>setAgain(e.target.value)}/></label>
  <button type="button" className="workerPrimary wide" disabled={busy||!native()} onClick={()=>void configure('enable')}>Activar bloqueo al abrir</button></>}
  {enabled===true&&<><p className="hint">El bloqueo está activado. Tras 10 intentos incorrectos, aplica una espera de 15 minutos.</p>
   <label>Contraseña actual<input type="password" autoComplete="off" disabled={busy} value={current} onChange={e=>setCurrent(e.target.value)}/></label>
   <button type="button" className="secondary" disabled={busy} onClick={()=>void configure('disable')}>Desactivar con contraseña actual</button>
   <button type="button" className="workerPrimary wide" disabled={busy} onClick={()=>window.location.reload()}>Bloquear ahora</button>
  </>}
  {status&&<p role="status" className="hint">{status}</p>}
  {error&&<p role="alert" className="importError">{error}</p>}
 </section>;
}
