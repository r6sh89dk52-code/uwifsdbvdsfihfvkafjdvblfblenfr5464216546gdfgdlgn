/** Etapa A: small prototype dataset only. Large clinical databases require SQLCipher. */
import {SecureStorage,KeychainAccess} from '@aparajita/capacitor-secure-storage';
import {Capacitor} from '@capacitor/core';

export type DemoSnapshot<A=unknown,W=unknown,R=unknown>={
  attentions:A[];
  workers:W[];
  allergies:Record<string,R>;
  notifications:boolean;
  stockLots:unknown[];
  stockMovements:unknown[];
  catalogMappings:unknown[];
  deliveryIncidents:unknown[];
};
const ATT='danper-etapa-a-demo-v1';
const WORK='danper-etapa-a-demo-workers-v2';
const ALLERGY='danper-etapa-a-demo-allergies-v05';
const REMINDERS='danper-reminders-enabled-v06';
const INVENTORY='danper-etapa-b0-stock-v010';
const MOVEMENTS='danper-etapa-b1-movements-v011';
const MAPPINGS='danper-etapa-b3-mappings-v013';
const INCIDENTS='danper-etapa-b3-incidents-v013';
const SECURE_KEY='prototype-snapshot-v1';
let configured:Promise<void>|undefined;
let writeQueue:Promise<void>=Promise.resolve();

export function isNativeSecureStore(){return Capacitor.isNativePlatform()&&Capacitor.getPlatform()==='ios'}
export function emptyDemoSnapshot():DemoSnapshot{return{attentions:[],workers:[],allergies:{},notifications:false,stockLots:[],stockMovements:[],catalogMappings:[],deliveryIncidents:[]}}
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
  return {attentions:value.attentions,workers:value.workers,allergies:value.allergies,notifications:value.notifications,stockLots:value.stockLots??[],stockMovements:value.stockMovements??[],catalogMappings:value.catalogMappings??[],deliveryIncidents:value.deliveryIncidents??[]};
}
export function readLegacyDemoSnapshot():DemoSnapshot{
  const parse=(key:string,fallback:unknown)=>{
    const raw=localStorage.getItem(key);
    if(raw===null)return fallback;
    try{return JSON.parse(raw)}catch{throw new Error(`Datos de prueba dañados: ${key}. No se sobrescribirán.`)}
  };
  return validateDemoSnapshot({attentions:parse(ATT,[]),workers:parse(WORK,[]),allergies:parse(ALLERGY,{}),notifications:localStorage.getItem(REMINDERS)==='yes',stockLots:parse(INVENTORY,[]),stockMovements:parse(MOVEMENTS,[]),catalogMappings:parse(MAPPINGS,[]),deliveryIncidents:parse(INCIDENTS,[])});
}
export function clearLegacyDemoSnapshot(){
  for(const key of [ATT,WORK,ALLERGY,REMINDERS,INVENTORY,MOVEMENTS,MAPPINGS,INCIDENTS])localStorage.removeItem(key);
}
function containsData(s:DemoSnapshot){return s.attentions.length>0||s.workers.length>0||Object.keys(s.allergies).length>0||s.notifications||s.stockLots.length>0||s.stockMovements.length>0||s.catalogMappings.length>0||s.deliveryIncidents.length>0}
async function configureKeychain(){
  if(!configured)configured=(async()=>{
    // Never sync prototype clinical data via iCloud Keychain.
    await SecureStorage.setKeyPrefix('danper-local-v08_');
    await SecureStorage.setSynchronize(false);
    await SecureStorage.setDefaultKeychainAccess(KeychainAccess.whenUnlockedThisDeviceOnly);
  })();
  return configured;
}
/** On iOS, fails closed. Migration happens only after verified Keychain persistence. */
export async function loadDemoSnapshot():Promise<DemoSnapshot>{
  if(!isNativeSecureStore())return readLegacyDemoSnapshot();
  await configureKeychain();
  const raw=await SecureStorage.getItem(SECURE_KEY);
  if(raw!==null){
    const parsed=validateDemoSnapshot(JSON.parse(raw));
    clearLegacyDemoSnapshot();
    return parsed;
  }
  const legacy=readLegacyDemoSnapshot();
  if(containsData(legacy)){
    await SecureStorage.setItem(SECURE_KEY,JSON.stringify(legacy));
    const verify=await SecureStorage.getItem(SECURE_KEY);
    if(verify!==JSON.stringify(legacy))throw new Error('No se pudo verificar la migración al llavero seguro. No se borraron los datos anteriores.');
    clearLegacyDemoSnapshot();
  }
  return legacy;
}
/** Native writes are serialized to avoid older writes overwriting newer snapshots. */
export function writeDemoSnapshot(snapshot:DemoSnapshot):Promise<void>{
  const safe=validateDemoSnapshot(snapshot);
  const serialized=JSON.stringify(safe);
  writeQueue=writeQueue.catch(()=>undefined).then(async()=>{
    if(isNativeSecureStore()){
      await configureKeychain();
      await SecureStorage.setItem(SECURE_KEY,serialized);
    }else{
      localStorage.setItem(ATT,JSON.stringify(safe.attentions));
      localStorage.setItem(WORK,JSON.stringify(safe.workers));
      localStorage.setItem(ALLERGY,JSON.stringify(safe.allergies));
      localStorage.setItem(REMINDERS,safe.notifications?'yes':'no');
      localStorage.setItem(INVENTORY,JSON.stringify(safe.stockLots));
      localStorage.setItem(MOVEMENTS,JSON.stringify(safe.stockMovements));
      localStorage.setItem(MAPPINGS,JSON.stringify(safe.catalogMappings));
      localStorage.setItem(INCIDENTS,JSON.stringify(safe.deliveryIncidents));
    }
  });
  return writeQueue;
}