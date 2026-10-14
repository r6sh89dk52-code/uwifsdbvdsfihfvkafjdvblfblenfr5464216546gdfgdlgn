/** iPhone-only local clinical data with AES-GCM encrypted snapshots. */
import {SecureStorage,KeychainAccess} from '@aparajita/capacitor-secure-storage';
import {Capacitor} from '@capacitor/core';
import {Filesystem,Directory} from '@capacitor/filesystem';
import {decryptPortableBackup} from './portableBackup';
import {loadClinicalVault,writeClinicalVault,stageClinicalRestore,verifyStagedClinicalRestore,activateClinicalRestore} from './privateClinicalVault';
import {loadWorkerVault,writeWorkerVault,stageWorkerRestore,verifyStagedWorkerRestore,activateWorkerRestore,MissingWorkerVaultError,workerVaultRecoveryRequired} from './privateWorkerVault';
export {workerVaultRecoveryRequired} from './privateWorkerVault';

export type DemoSnapshot<A=unknown,W=unknown,R=unknown>={
  attentions:A[];
  workers:W[];
  allergies:Record<string,R>;
  notifications:boolean;
  stockLots:unknown[];
  stockMovements:unknown[];
  catalogMappings:unknown[];
  deliveryIncidents:unknown[];
  ambulatoryReconciliation:unknown[];
};
const ATT='danper-etapa-a-demo-v1';
const WORK='danper-etapa-a-demo-workers-v2';
const ALLERGY='danper-etapa-a-demo-allergies-v05';
const REMINDERS='danper-reminders-enabled-v06';
const INVENTORY='danper-etapa-b0-stock-v010';
const MOVEMENTS='danper-etapa-b1-movements-v011';
const MAPPINGS='danper-etapa-b3-mappings-v013';
const INCIDENTS='danper-etapa-b3-incidents-v013';
const AMBULATORY_RECON='danper-v016-ambulatory-reconciliation';
const SECURE_KEY='prototype-snapshot-v1';
const CLINICAL_MARKER=JSON.stringify({format:'encrypted-clinical-v1',version:2});
/** A pending migration MUST NOT silently write on app startup. */
export class ClinicalMigrationRequiredError extends Error{
 constructor(){super('Antes de migrar tus datos clínicos, selecciona y verifica un respaldo cifrado externo.');this.name='ClinicalMigrationRequiredError'}
}
let migrationInProgress=false;
let intentionalResetInProgress=false;
const LEGACY_CLINICAL_BACKUP='clinical-v1-legacy-verified-snapshot';
const RESTORE_JOURNAL='clinical-v1-portable-restore-pending';
const RESTORE_DONE='finished';
type RestoreJournal={v:1;workerPath:string;clinicalPath:string};
/** Recovery journal is replayed on launch before any state becomes visible.
 * Two staged files are verified before changing either Keychain pointer.
 */
async function finishPendingRestore():Promise<void>{
 const raw=await SecureStorage.getItem(RESTORE_JOURNAL);
 if(raw===null||raw===RESTORE_DONE)return;
 let state:RestoreJournal;
 try{state=JSON.parse(raw) as RestoreJournal}
 catch{throw Error('Registro de restauración dañado. No se modifican datos.')}
 if(state?.v!==1||typeof state.workerPath!=='string'||typeof state.clinicalPath!=='string')
  throw Error('Registro de restauración incompatible. No se modifican datos.');
 await verifyStagedWorkerRestore(state.workerPath);
 await verifyStagedClinicalRestore(state.clinicalPath);
 await activateWorkerRestore(state.workerPath);
 await activateClinicalRestore(state.clinicalPath);
 await SecureStorage.setItem(SECURE_KEY,CLINICAL_MARKER);
 if(await SecureStorage.getItem(SECURE_KEY)!==CLINICAL_MARKER)throw Error('No se confirmó la restauración clínica.');
 await SecureStorage.setItem(RESTORE_JOURNAL,RESTORE_DONE);
 if(await SecureStorage.getItem(RESTORE_JOURNAL)!==RESTORE_DONE)
  throw Error('No se pudo finalizar la restauración. Se reintentará al abrir la aplicación.');
}
/** Retain the verified v0.19 Keychain snapshot for manual recovery if iOS loses its file container. */
async function preserveLegacySnapshot(raw:string):Promise<void>{
 const previous=await SecureStorage.getItem(LEGACY_CLINICAL_BACKUP);
 if(previous!==null)return; // never replace the original migration backup
 await SecureStorage.setItem(LEGACY_CLINICAL_BACKUP,raw);
 if(await SecureStorage.getItem(LEGACY_CLINICAL_BACKUP)!==raw)
  throw Error('No se pudo conservar el respaldo previo a la migración clínica.');
}
let configured:Promise<void>|undefined;
let writeQueue:Promise<void>=Promise.resolve();

export function isNativeSecureStore(){return Capacitor.isNativePlatform()&&Capacitor.getPlatform()==='ios'}
export function emptyDemoSnapshot():DemoSnapshot{return{attentions:[],workers:[],allergies:{},notifications:false,stockLots:[],stockMovements:[],catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]}}
function object(value:unknown):value is Record<string,unknown>{return value!==null&&typeof value==='object'&&!Array.isArray(value)}
export function validateDemoSnapshot(value:unknown):DemoSnapshot{
  if(!object(value)||!Array.isArray(value.attentions)||!Array.isArray(value.workers)||!object(value.allergies)||typeof value.notifications!=='boolean'){
    throw new Error('Los datos guardados no tienen la estructura esperada. No se sobrescribirán.');
  }
  if(value.stockLots!==undefined&&!Array.isArray(value.stockLots))throw new Error('Inventario incompatible. No se sobrescribirá.');
  if(Array.isArray(value.stockLots)&&value.stockLots.length>500)throw new Error('Inventario fuera de límites para este prototipo.');
  if(value.stockMovements!==undefined&&(!Array.isArray(value.stockMovements)||value.stockMovements.length>1000))throw new Error('Historial de movimientos incompatible. No se sobrescribirá.');
  if(value.catalogMappings!==undefined&&(!Array.isArray(value.catalogMappings)||value.catalogMappings.length>500))throw Error('Equivalencias incompatibles.');
  if(value.deliveryIncidents!==undefined&&(!Array.isArray(value.deliveryIncidents)||value.deliveryIncidents.length>500))throw Error('Incidencias incompatibles.');
  if(value.ambulatoryReconciliation!==undefined&&(!Array.isArray(value.ambulatoryReconciliation)||value.ambulatoryReconciliation.length>1200))throw Error('Conciliaciones incompatibles. Los datos existentes no se sobrescribirán.');
  return {attentions:value.attentions,workers:value.workers,allergies:value.allergies,notifications:value.notifications,stockLots:value.stockLots??[],stockMovements:value.stockMovements??[],catalogMappings:value.catalogMappings??[],deliveryIncidents:value.deliveryIncidents??[],ambulatoryReconciliation:value.ambulatoryReconciliation??[]};
}
export function readLegacyDemoSnapshot():DemoSnapshot{
  const parse=(key:string,fallback:unknown)=>{
    const raw=localStorage.getItem(key);
    if(raw===null)return fallback;
    try{return JSON.parse(raw)}catch{throw new Error(`Datos de prueba dañados: ${key}. No se sobrescribirán.`)}
  };
  return validateDemoSnapshot({attentions:parse(ATT,[]),workers:parse(WORK,[]),allergies:parse(ALLERGY,{}),notifications:localStorage.getItem(REMINDERS)==='yes',stockLots:parse(INVENTORY,[]),stockMovements:parse(MOVEMENTS,[]),catalogMappings:parse(MAPPINGS,[]),deliveryIncidents:parse(INCIDENTS,[]),ambulatoryReconciliation:parse(AMBULATORY_RECON,[])});
}
export function clearLegacyDemoSnapshot(){
  for(const key of [ATT,WORK,ALLERGY,REMINDERS,INVENTORY,MOVEMENTS,MAPPINGS,INCIDENTS,AMBULATORY_RECON])localStorage.removeItem(key);
}
function containsData(s:DemoSnapshot){return s.attentions.length>0||s.workers.length>0||Object.keys(s.allergies).length>0||s.notifications||s.stockLots.length>0||s.stockMovements.length>0||s.catalogMappings.length>0||s.deliveryIncidents.length>0||s.ambulatoryReconciliation.length>0}
async function configureKeychain(){
  if(!configured)configured=(async()=>{
    // Never sync prototype clinical data via iCloud Keychain.
    await SecureStorage.setKeyPrefix('danper-local-v08_');
    await SecureStorage.setSynchronize(false);
    await SecureStorage.setDefaultKeychainAccess(KeychainAccess.whenUnlockedThisDeviceOnly);
  })();
  return configured;
}
/** On iOS the active clinical vault always wins over the legacy snapshot.
 * Legacy data is overwritten by a small marker ONLY after encrypted migration
 * and worker-vault validation; never auto-reset on missing/corrupt files.
 */
export async function loadDemoSnapshot(allowVerifiedMigration=false):Promise<DemoSnapshot>{
 if(!isNativeSecureStore())return readLegacyDemoSnapshot();
 await configureKeychain();
 await finishPendingRestore();
 const raw=await SecureStorage.getItem(SECURE_KEY);
 const prior=raw!==null&&raw!==CLINICAL_MARKER?validateDemoSnapshot(JSON.parse(raw)):null;
 const encrypted=await loadClinicalVault();
 if(raw===CLINICAL_MARKER&&encrypted===null)
  throw Error('Se perdió la referencia al almacén clínico cifrado. No se crearán registros nuevos.');
 // Reject incompatible marker formats. Never silently discard a prior version.
 if(raw!==null&&raw!==CLINICAL_MARKER&&!prior)
  throw Error('Formato anterior del almacén clínico incompatible.');
 // Migration gate: a first launch only inspects the old snapshot and roster;
 // writes happen exclusively after authenticating a user-supplied external
 // .danperbackup that matches these exact current records.
 if(encrypted===null&&!allowVerifiedMigration){
  if(prior){
   let roster:unknown[]|null;
   try{roster=await loadWorkerVault()}
   catch(error){if(error instanceof MissingWorkerVaultError)return prior;throw error}
   if(roster!==null&&prior.workers.length&&JSON.stringify(roster)!==JSON.stringify(prior.workers))
    throw Error('Padrón duplicado divergente. No se migrará.');
   if(containsData({...prior,workers:roster??prior.workers}))throw new ClinicalMigrationRequiredError();
  }else{
   if(containsData(readLegacyDemoSnapshot()))throw new ClinicalMigrationRequiredError();
  }
 }
 if(encrypted!==null){
  const parsed=validateDemoSnapshot(encrypted);
  if(parsed.workers.length)throw Error('El almacén clínico contiene un padrón duplicado.');
  try{
   const workers=await loadWorkerVault();
   if(workers===null)throw Error('No existe una referencia al padrón cifrado. Se bloquea el arranque para proteger los registros.');
   // Clinical storage is verified; preserve old Keychain snapshot before switching.
   if(raw!==CLINICAL_MARKER){
    if(raw!==null)await preserveLegacySnapshot(raw);
    await SecureStorage.setItem(SECURE_KEY,CLINICAL_MARKER);
    if(await SecureStorage.getItem(SECURE_KEY)!==CLINICAL_MARKER)
     throw Error('No se confirmó la migración clínica en Keychain.');
   }
   clearLegacyDemoSnapshot();
   return {...parsed,workers};
  }catch(error){
   if(error instanceof MissingWorkerVaultError)return parsed;
   throw error;
  }
 }
 if(prior){
  let workers:unknown[]|null;
  try{workers=await loadWorkerVault()}
  catch(error){if(error instanceof MissingWorkerVaultError)return prior;throw error}
  if(workers!==null&&prior.workers.length&&JSON.stringify(workers)!==JSON.stringify(prior.workers))
   throw Error('Padrón duplicado divergente. No se migra automáticamente.');
  if(workers===null)await writeWorkerVault(prior.workers);
  const stripped={...prior,workers:[]};
  await writeClinicalVault(stripped);
  if(raw!==null)await preserveLegacySnapshot(raw);
  await SecureStorage.setItem(SECURE_KEY,CLINICAL_MARKER);
  if(await SecureStorage.getItem(SECURE_KEY)!==CLINICAL_MARKER)
   throw Error('No se verificó el marcador del almacén clínico.');
  clearLegacyDemoSnapshot();
  return {...prior,workers:workers??prior.workers};
 }
 const legacy=readLegacyDemoSnapshot();
 let separate:unknown[]|null;
 try{separate=await loadWorkerVault()}
 catch(error){if(error instanceof MissingWorkerVaultError)return legacy;throw error}
 if(separate!==null)throw Error('Existe un padrón sin estado clínico principal. No se puede reiniciar.');
 if(containsData(legacy)){
  await writeWorkerVault(legacy.workers);
  await writeClinicalVault({...legacy,workers:[]});
  await SecureStorage.setItem(SECURE_KEY,CLINICAL_MARKER);
  if(await SecureStorage.getItem(SECURE_KEY)!==CLINICAL_MARKER)
   throw Error('La migración a almacenamiento clínico cifrado no se verificó.');
  clearLegacyDemoSnapshot();
 }
 return legacy;
}
/** Native writes are serialized to avoid older writes overwriting newer snapshots. */
export function writeDemoSnapshot(snapshot:DemoSnapshot):Promise<void>{
  if(intentionalResetInProgress)return Promise.reject(Error('Restablecimiento intencional en curso; se bloquearon nuevos guardados.'));
  const safe=validateDemoSnapshot(snapshot);
  writeQueue=writeQueue.catch(()=>undefined).then(async()=>{
    if(intentionalResetInProgress)throw Error('Restablecimiento intencional en curso.');
    if(isNativeSecureStore()){
      await configureKeychain();
      const pending=await SecureStorage.getItem(RESTORE_JOURNAL);
      if(pending!==null&&pending!==RESTORE_DONE)throw Error('Restauración pendiente. No se permiten guardados.');
      if(workerVaultRecoveryRequired())throw new MissingWorkerVaultError();
      await writeWorkerVault(safe.workers);
      await writeClinicalVault({...safe,workers:[]});
      await SecureStorage.setItem(SECURE_KEY,CLINICAL_MARKER);
      if(await SecureStorage.getItem(SECURE_KEY)!==CLINICAL_MARKER)
        throw Error('Guardado clínico no confirmado en Keychain.');
    }else{
      localStorage.setItem(ATT,JSON.stringify(safe.attentions));
      localStorage.setItem(WORK,JSON.stringify(safe.workers));
      localStorage.setItem(ALLERGY,JSON.stringify(safe.allergies));
      localStorage.setItem(REMINDERS,safe.notifications?'yes':'no');
      localStorage.setItem(INVENTORY,JSON.stringify(safe.stockLots));
      localStorage.setItem(MOVEMENTS,JSON.stringify(safe.stockMovements));
      localStorage.setItem(MAPPINGS,JSON.stringify(safe.catalogMappings));
      localStorage.setItem(INCIDENTS,JSON.stringify(safe.deliveryIncidents));
      localStorage.setItem(AMBULATORY_RECON,JSON.stringify(safe.ambulatoryReconciliation));
    }
  });
  return writeQueue;
}
/** Destructive restore is disabled on populated databases. First stage both
 * encrypted files, then commit the replay journal, then change active refs.
 * A power loss is resolved by finishPendingRestore() on the next launch.
 */
export function hasActiveRecords(snapshot:DemoSnapshot):boolean{return containsData(snapshot)}
export async function restoreEmptyDeviceFromBackup(backup:unknown):Promise<void>{
 if(!isNativeSecureStore())throw Error('La restauración requiere la aplicación nativa de iPhone.');
 const requested=validateDemoSnapshot(backup);
 const stable=JSON.parse(JSON.stringify(requested)) as DemoSnapshot;
 writeQueue=writeQueue.catch(()=>undefined).then(async()=>{
  await configureKeychain();
  if(workerVaultRecoveryRequired())throw new MissingWorkerVaultError();
  await finishPendingRestore();
  const current=await loadDemoSnapshot();
  if(containsData(current))
   throw Error('Ya existen trabajadores, atenciones o inventario. No se restaurará encima de una base con registros.');
  const workerPath=await stageWorkerRestore(stable.workers);
  const clinicalPath=await stageClinicalRestore({...stable,workers:[]});
  const record:RestoreJournal={v:1,workerPath,clinicalPath};
  const journal=JSON.stringify(record);
  await SecureStorage.setItem(RESTORE_JOURNAL,journal);
  if(await SecureStorage.getItem(RESTORE_JOURNAL)!==journal)
   throw Error('No se confirmó la preparación del respaldo.');
  await finishPendingRestore();
  const restored=await loadDemoSnapshot();
  if(JSON.stringify(restored)!==JSON.stringify(stable))
   throw Error('La restauración no coincide con el respaldo verificado.');
 });
 return writeQueue;
}

/** Wait for all previously queued native writes before exporting a backup.
 * A failed write blocks export rather than silently archiving stale data.
 */
export async function readStableSnapshotForBackup():Promise<DemoSnapshot>{
 if(!isNativeSecureStore())throw Error('Respaldo privado disponible solo en iPhone.');
 await writeQueue;
 return loadDemoSnapshot();
}

/** Read original iPhone data without changing any pointer, clinical file or
 * localStorage. Used to compare with the authenticated external backup.
 */
async function readSourceBeforeMigration():Promise<DemoSnapshot>{
 await configureKeychain();
 if(await loadClinicalVault()!==null)throw Error('El almacenamiento clínico ya está migrado.');
 const raw=await SecureStorage.getItem(SECURE_KEY);
 if(raw===CLINICAL_MARKER)throw Error('El estado clínico ya utiliza el almacén cifrado.');
 if(raw!==null){
  const prior=validateDemoSnapshot(JSON.parse(raw));
  const roster=await loadWorkerVault();
  if(roster===null&&prior.workers.length)
   throw Error('No se encuentra el padrón cifrado anterior. No se realizará la migración.');
  if(roster!==null&&prior.workers.length&&JSON.stringify(roster)!==JSON.stringify(prior.workers))
   throw Error('Los trabajadores en Keychain y el padrón privado no coinciden.');
  return {...prior,workers:roster??prior.workers};
 }
 const legacy=readLegacyDemoSnapshot();
 const roster=await loadWorkerVault();
 if(roster!==null&&legacy.workers.length&&JSON.stringify(roster)!==JSON.stringify(legacy.workers))
  throw Error('Los trabajadores guardados no coinciden. No se realizará la migración.');
 return {...legacy,workers:roster??legacy.workers};
}
/** Explicit authorization from a backup verified with its original password.
 * Never modifies the device on a missing, stale, tampered or wrong-password
 * file. On success the existing migration uses copy-on-write generations and
 * preserves the original Keychain snapshot.
 */
export async function migrateFromVerifiedPortableBackup(archive:string,password:string):Promise<DemoSnapshot>{
 if(!isNativeSecureStore())throw Error('La migración cifrada solo está disponible en iPhone.');
 if(migrationInProgress)throw Error('Ya se está comprobando una migración.');
 migrationInProgress=true;
 try{
  await writeQueue;
  const actual=await readSourceBeforeMigration();
  const archiveSnapshot=validateDemoSnapshot(await decryptPortableBackup(archive,password));
  if(JSON.stringify(archiveSnapshot)!==JSON.stringify(actual))
   throw Error('Este respaldo no coincide con los registros actuales del iPhone. Crea y verifica una copia nueva antes de migrar.');
  if(!containsData(actual))throw Error('La base está vacía; no necesita migración.');
  const migrated=await loadDemoSnapshot(true);
  if(JSON.stringify(migrated)!==JSON.stringify(actual))
   throw Error('La comprobación final de la migración no coincide. No continúes registrando datos.');
  return migrated;
 }finally{migrationInProgress=false}
}

/**
 * EXPLICIT single-device reset for a known disposable test installation.
 * Never invoked automatically on startup, migrations, failures or reinstall.
 * This removes only app-private runtime files and its scoped Keychain entries;
 * packaged nursing catalogs, approved associations and Excel templates remain.
 * A successful reset permanently blocks queued writes until the page reloads.
 */
export async function resetDisposableLocalDatabase():Promise<void>{
 if(!isNativeSecureStore())throw Error('El reinicio completo solo está disponible en la aplicación iOS.');
 if(intentionalResetInProgress)throw Error('Ya se está reiniciando la base local.');
 intentionalResetInProgress=true;
 try{
  // Drain earlier writes, including failures; no new snapshot may be enqueued.
  await writeQueue.catch(()=>undefined);
  await configureKeychain();
  const location={path:'danper',directory:Directory.Data};
  let present=false;
  try{await Filesystem.stat(location);present=true}
  catch(error){
   const message=error instanceof Error?error.message:String(error);
   if(!/does not exist|no such file|\\bENOENT\\b|file not found/i.test(message))throw error;
  }
  if(present){
   await Filesystem.rmdir({...location,recursive:true});
   try{
    await Filesystem.stat(location);
    throw Error('Persisten archivos privados tras el intento de reinicio.');
   }catch(error){
    const message=error instanceof Error?error.message:String(error);
    if(!/does not exist|no such file|\\bENOENT\\b|file not found/i.test(message))throw error;
   }
  }
  // Clear only keys in the existing DANPER prefix. iOS Keychain may survive app uninstall.
  await SecureStorage.clear(false);
  if((await SecureStorage.keys(false)).length!==0)throw Error('Quedaron referencias en Keychain. No se confirmó el reinicio.');
  clearLegacyDemoSnapshot();
 }catch(error){intentionalResetInProgress=false;throw error}
}
