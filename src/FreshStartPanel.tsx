import {useState} from 'react';
import {isNativeSecureStore,resetDisposableLocalDatabase} from './secureDemoStore';

/** Explicit administrative action for a wholly disposable local test dataset. */
export default function FreshStartPanel(){
 const [confirmedNoRealRecords,setConfirmedNoRealRecords]=useState(false);
 const [phrase,setPhrase]=useState('');
 const [busy,setBusy]=useState(false);
 const [error,setError]=useState('');
 const [status,setStatus]=useState('');
 if(!isNativeSecureStore())return null;
 const valid=confirmedNoRealRecords&&phrase==='BORRAR DATOS DE PRUEBA'&&!busy;
 async function execute(){
  if(!valid)return;
  if(!window.confirm('BORRADO IRREVERSIBLE: se eliminarán TODOS los trabajadores importados, atenciones, alergias, existencias, movimientos y referencias cifradas de esta instalación. NO se borrarán los catálogos oficiales incluidos en la aplicación ni su lógica de exportación. ¿Proceder?'))return;
  setBusy(true);setError('');setStatus('Eliminando exclusivamente datos locales de prueba…');
  try{
   await resetDisposableLocalDatabase();
   setStatus('Base de prueba eliminada y almacén seguro depurado. Reiniciando…');
   window.location.reload();
  }catch(e){
   setStatus('');
   setError(e instanceof Error?e.message:'No se pudo confirmar el reinicio. No importes datos nuevos todavía.');
   setBusy(false);
  }
 }
 return <section className="panel" aria-label="Inicio limpio de base local">
  <h3>Comenzar con base local vacía</h3>
  <p className="kardexError">Esta opción DESTRUYE los datos guardados en este dispositivo. Úsala exclusivamente cuando hayas confirmado que NO existen atenciones, alergias ni inventarios reales que quieras conservar. No es un mecanismo de actualización.</p>
  <p className="hint">Elimina los trabajadores de prueba (y los importados), lotes, cantidades, movimientos, atenciones y claves anteriores del almacenamiento seguro. NO elimina el catálogo fijo de 98 productos del Kardex, los 432 códigos del Indicador Ambulatorio, las 86 correspondencias revisadas, ni las dos exportaciones Excel.</p>
  <p className="hint">Antes de confirmar, guarda en un lugar autorizado el Excel PERSONAL real. Una vez reiniciada, impórtalo nuevamente como el único padrón inicial.</p>
  <label className="toggle"><input type="checkbox" checked={confirmedNoRealRecords} disabled={busy} onChange={e=>setConfirmedNoRealRecords(e.target.checked)}/>Confirmo que todos los datos registrados actualmente son descartables y que no necesito recuperar los registros anteriores.</label>
  <label>Escribe BORRAR DATOS DE PRUEBA
   <input value={phrase} autoComplete="off" disabled={busy} onChange={e=>setPhrase(e.target.value)} placeholder="BORRAR DATOS DE PRUEBA"/>
  </label>
  <button type="button" className="dangerButton" disabled={!valid} onClick={()=>void execute()}>{busy?'Reiniciando…':'Eliminar base local y comenzar desde cero'}</button>
  {status&&<p role="status" className="hint">{status}</p>}
  {error&&<p role="alert" className="importError">{error}</p>}
 </section>;
}
