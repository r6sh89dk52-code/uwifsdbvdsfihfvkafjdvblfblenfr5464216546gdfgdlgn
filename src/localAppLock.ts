/** Optional additional app screen lock for personal device use.
 * Strong passphrase-derived verifier in THIS DEVICE's iOS Keychain.
 * This is an application UI lock, NOT Face ID or database key protection.
 * Never silently disable when Keychain is inaccessible.
 */
import {Capacitor} from '@capacitor/core';
import {SecureStorage,KeychainAccess} from '@aparajita/capacitor-secure-storage';
const LOCK='local-ui-lock-v1',FAILED='local-ui-lock-attempts-v1';
const ITERATIONS=260000;
let ready:Promise<void>|null=null;
function native(){return Capacitor.isNativePlatform()&&Capacitor.getPlatform()==='ios'}
async function configure(){
 if(!native())return;
 if(!ready)ready=(async()=>{
  await SecureStorage.setKeyPrefix('danper-local-v08_');
  await SecureStorage.setSynchronize(false);
  await SecureStorage.setDefaultKeychainAccess(KeychainAccess.whenUnlockedThisDeviceOnly);
 })();
 return ready;
}
function encode(data:Uint8Array):string{
 let out='';for(let i=0;i<data.length;i+=8192)out+=String.fromCharCode(...data.subarray(i,i+8192));
 return btoa(out);
}
function decode(s:string){return Uint8Array.from(atob(s),c=>c.charCodeAt(0))}
async function verifier(passphrase:string,salt:Uint8Array):Promise<string>{
 const base=await crypto.subtle.importKey('raw',new TextEncoder().encode(passphrase).buffer as ArrayBuffer,'PBKDF2',false,['deriveBits']);
 const result=await crypto.subtle.deriveBits({name:'PBKDF2',salt:salt.buffer as ArrayBuffer,iterations:ITERATIONS,hash:'SHA-256'},base,256);
 return encode(new Uint8Array(result));
}
function secretValid(s:string){return s.length>=12&&s.length<=200}
export async function appLockEnabled():Promise<boolean>{
 if(!native())return false;
 await configure();
 const value=await SecureStorage.getItem(LOCK);
 if(value===null)return false;
 const record=JSON.parse(value) as {v?:number;s?:unknown;h?:unknown};
 if(record.v===0)return false;
 if(record.v!==1||typeof record.s!=='string'||typeof record.h!=='string')throw Error('El bloqueo de aplicación está dañado. No se desbloqueará automáticamente.');
 return true;
}
export async function enableAppLock(passphrase:string):Promise<void>{
 if(!native())throw Error('El bloqueo de acceso solo está disponible en iPhone.');
 if(!secretValid(passphrase))throw Error('La clave de acceso debe tener entre 12 y 200 caracteres.');
 await configure();
 if(await appLockEnabled())throw Error('Ya existe un bloqueo. Verifica primero tu clave anterior.');
 const salt=crypto.getRandomValues(new Uint8Array(16));
 const hash=await verifier(passphrase,salt);
 const saved=JSON.stringify({v:1,s:encode(salt),h:hash});
 await SecureStorage.setItem(LOCK,saved);
 if(await SecureStorage.getItem(LOCK)!==saved)throw Error('No se confirmó la clave de bloqueo.');
 await SecureStorage.setItem(FAILED,'0');
}
export async function unlockAppLock(passphrase:string):Promise<boolean>{
 if(!native())return true;
 await configure();
 const stored=await SecureStorage.getItem(LOCK);
 if(stored===null)return true;
 let record:{v:number;s:string;h:string};
 try{record=JSON.parse(stored)}catch{throw Error('Datos del bloqueo inaccesibles. No se abrirá automáticamente.')}
 if(record.v!==1||typeof record.s!=='string'||typeof record.h!=='string')throw Error('Formato de bloqueo no compatible.');
 const raw=await SecureStorage.getItem(FAILED)??'0:0';
 const [attemptText,untilText]=raw.split(':');
 let failures=Number(attemptText),until=Number(untilText??0);
 if(!Number.isSafeInteger(failures)||failures<0||!Number.isFinite(until)||until<0)
  throw Error('Registro de intentos dañado. No se desbloqueará.');
 if(until>Date.now())throw Error('Demasiados intentos. Espera 15 minutos para volver a intentarlo.');
 if(until>0&&until<=Date.now())failures=0;
 const candidate=await verifier(passphrase,decode(record.s));
 const a=decode(candidate),b=decode(record.h);
 let diff=a.length^b.length;
 for(let i=0;i<Math.max(a.length,b.length);i++)diff|=(a[i]??0)^(b[i]??0);
 if(diff!==0){
  await SecureStorage.setItem(FAILED,failures+1>=10?String(failures+1)+':'+String(Date.now()+15*60*1000):String(failures+1)+':0');
  return false;
 }
 await SecureStorage.setItem(FAILED,'0');
 return true;
}
export async function disableAppLock(passphrase:string):Promise<void>{
 if(!await appLockEnabled())throw Error('No hay un bloqueo activo.');
 if(!await unlockAppLock(passphrase))throw Error('Clave de acceso incorrecta.');
 // To avoid depending on undocumented remove API, use a verified disabled marker.
 // Keep the old verifier for forensics until it is replaced.
 await SecureStorage.setItem(LOCK,JSON.stringify({v:0}));
 if(await SecureStorage.getItem(LOCK)!==JSON.stringify({v:0}))throw Error('No se confirmó el cambio de bloqueo.');
}
