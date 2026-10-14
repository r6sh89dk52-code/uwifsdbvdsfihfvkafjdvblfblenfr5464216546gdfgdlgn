import {Filesystem,Directory,Encoding} from '@capacitor/filesystem';
import {SecureStorage} from '@aparajita/capacitor-secure-storage';

/** Versioned, private AES-256-GCM encrypted clinical snapshot.
 * All changes are copy-on-write: previous file/key are never removed here.
 * Encryption key remains this-device-only in iOS Keychain.
 */
const KEY='clinical-v1-aes256-key',POINTER='clinical-v1-active-file';
const DIR='danper/clinical';
const MAX_CLEAR=35*1024*1024;
const MAX_CIPHER=48*1024*1024;
let knownContent:string|null=null,knownPath:string|null=null;
function b64(data:Uint8Array){
 let text='';for(let i=0;i<data.length;i+=8192)text+=String.fromCharCode(...data.subarray(i,i+8192));
 return btoa(text);
}
function fromB64(s:string):Uint8Array{
 if(typeof s!=='string'||!/^[A-Za-z0-9+/]*={0,2}$/.test(s))throw Error('Cifrado clínico incompatible.');
 return Uint8Array.from(atob(s),c=>c.charCodeAt(0));
}
function missing(error:unknown){
 return /does not exist|no such file|\bENOENT\b|file not found/i.test(error instanceof Error?error.message:String(error));
}
async function ensureFolder(){
 const location={path:DIR,directory:Directory.Data};
 try{
  const entry=await Filesystem.stat(location);
  if(entry.type!=='directory')throw Error('Existe una ruta clínica no compatible con una carpeta.');
  return;
 }catch(error){if(!missing(error))throw error}
 try{await Filesystem.mkdir({...location,recursive:true})}
 catch(error){
  let stat;try{stat=await Filesystem.stat(location)}catch{throw error}
  if(stat.type!=='directory')throw error;
 }
 const check=await Filesystem.stat(location);
 if(check.type!=='directory')throw Error('No se verificó el directorio clínico.');
}
async function key(){
 let raw=await SecureStorage.getItem(KEY);
 if(raw===null){
  raw=b64(crypto.getRandomValues(new Uint8Array(32)));
  await SecureStorage.setItem(KEY,raw);
  if(await SecureStorage.getItem(KEY)!==raw)throw Error('No se confirmó la clave clínica.');
 }
 const bytes=fromB64(raw);
 if(bytes.length!==32)throw Error('Clave clínica incorrecta. No se sobrescribirá.');
 return crypto.subtle.importKey('raw',bytes.buffer as ArrayBuffer,{name:'AES-GCM'},false,['encrypt','decrypt']);
}
function validPath(s:string){return /^danper\/clinical\/clinical-[a-f0-9-]+\.enc$/.test(s)}
async function decode(path:string,k:CryptoKey):Promise<unknown>{
 if(!validPath(path))throw Error('Ruta clínica inválida.');
 let entry;
 try{entry=await Filesystem.readFile({path,directory:Directory.Data,encoding:Encoding.UTF8})}
 catch(error){if(missing(error))throw Error('El archivo clínico cifrado no está disponible. No se reemplazarán registros.');throw error}
 if(typeof entry.data!=='string'||entry.data.length>MAX_CIPHER*1.5)throw Error('Archivo clínico cifrado ilegible.');
 const pack=JSON.parse(entry.data) as {v?:unknown;iv?:unknown;data?:unknown};
 if(pack.v!==1||typeof pack.iv!=='string'||typeof pack.data!=='string')throw Error('Formato clínico cifrado incompatible.');
 const iv=fromB64(pack.iv),cipher=fromB64(pack.data);
 if(iv.length!==12||cipher.length<16||cipher.length>MAX_CIPHER)throw Error('Longitud de archivo clínico incorrecta.');
 const clear=await crypto.subtle.decrypt({name:'AES-GCM',iv:iv.buffer as ArrayBuffer},k,cipher.buffer as ArrayBuffer);
 if(clear.byteLength>MAX_CLEAR)throw Error('El archivo clínico supera el límite seguro.');
 return JSON.parse(new TextDecoder().decode(clear)) as unknown;
}
export async function clinicalVaultPresent():Promise<boolean>{
 return (await SecureStorage.getItem(POINTER))!==null;
}
export async function loadClinicalVault():Promise<unknown|null>{
 const path=await SecureStorage.getItem(POINTER);
 if(path===null)return null;
 const record=await decode(path,await key());
 knownPath=path;knownContent=JSON.stringify(record);
 return record;
}
export async function writeClinicalVault(value:unknown):Promise<void>{
 if(!value||typeof value!=='object'||Array.isArray(value))throw Error('Estado clínico inválido.');
 const serialized=JSON.stringify(value);
 if(new TextEncoder().encode(serialized).length>MAX_CLEAR)throw Error('Estado clínico demasiado grande.');
 const current=await SecureStorage.getItem(POINTER);
 if(current&&current===knownPath&&serialized===knownContent)return;
 const k=await key(),iv=crypto.getRandomValues(new Uint8Array(12));
 const cipher=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv},k,new TextEncoder().encode(serialized)));
 const path=DIR+'/clinical-'+crypto.randomUUID()+'.enc';
 await ensureFolder();
 await Filesystem.writeFile({path,directory:Directory.Data,encoding:Encoding.UTF8,
   data:JSON.stringify({v:1,iv:b64(iv),data:b64(cipher)})});
 const verification=await decode(path,k);
 if(JSON.stringify(verification)!==serialized)throw Error('Falló la comprobación de la escritura clínica.');
 await SecureStorage.setItem(POINTER,path);
 if(await SecureStorage.getItem(POINTER)!==path)throw Error('No se confirmó la generación clínica.');
 knownPath=path;knownContent=serialized;
}
