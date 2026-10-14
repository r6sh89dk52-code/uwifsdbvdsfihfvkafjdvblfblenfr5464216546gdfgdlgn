import {Filesystem,Directory,Encoding} from '@capacitor/filesystem';
import {SecureStorage} from '@aparajita/capacitor-secure-storage';

/** iOS-only encrypted employee file. Pointer and secret remain in Keychain. */
const KEY='workers-v1-aes-key';
const POINTER='workers-v1-file';
let lastWrite='';
let missingFile=false;
const ORPHANS='workers-v1-missing-file-references';
export class MissingWorkerVaultError extends Error{
 constructor(){super('El archivo cifrado del padrón no está disponible. Su referencia original se conserva.');this.name='MissingWorkerVaultError'}
}
export function workerVaultRecoveryRequired(){return missingFile}
function isMissingFileError(error:unknown){
 const message=error instanceof Error?error.message:String(error);
 return /does not exist|no such file|\bENOENT\b|file not found/i.test(message);
}

/**
 * iOS Filesystem.mkdir({recursive:true}) is NOT idempotent: when the
 * directory already exists it can throw "already exists, cannot be overwritten".
 * Check its actual type first, and accept a concurrent creator only after
 * stat confirms the destination is a directory. Never delete a folder.
 */
async function ensurePrivateDirectory():Promise<void>{
 const path='danper/private';
 const location={path,directory:Directory.Data};
 try{
  const existing=await Filesystem.stat(location);
  if(existing.type!=='directory')throw Error('La ruta del padrón existe, pero no es una carpeta. No se modificará.');
  return;
 }catch(error){
  if(!isMissingFileError(error))throw error;
 }
 try{
  await Filesystem.mkdir({...location,recursive:true});
 }catch(error){
  // Another save may have created the directory between stat and mkdir.
  // Do not swallow permission errors or overwrite a file at this path.
  let found;
  try{found=await Filesystem.stat(location)}catch{throw error}
  if(found.type!=='directory')throw error;
 }
 const confirmed=await Filesystem.stat(location);
 if(confirmed.type!=='directory')throw Error('No se pudo confirmar la carpeta privada del padrón.');
}
function b64(data:Uint8Array){
 let s='';for(let n=0;n<data.length;n+=6000)s+=String.fromCharCode(...data.subarray(n,n+6000));
 return btoa(s);
}
function unb64(s:string){return Uint8Array.from(atob(s),x=>x.charCodeAt(0))}
async function secret(){
 let raw=await SecureStorage.getItem(KEY);
 if(raw===null){
  raw=b64(crypto.getRandomValues(new Uint8Array(32)));
  await SecureStorage.setItem(KEY,raw);
  if(await SecureStorage.getItem(KEY)!==raw)throw Error('Clave del padrón no verificable.');
 }
 const bytes=unb64(raw);
 if(bytes.length!==32)throw Error('Clave del padrón inválida.');
 return crypto.subtle.importKey('raw',bytes,{name:'AES-GCM'},false,['encrypt','decrypt']);
}
function verifyWorkers(v:unknown):asserts v is unknown[]{
 if(!Array.isArray(v)||v.length>30000)throw Error('Padrón no válido.');
 for(const row of v){
  const r=row as {dni?:unknown;name?:unknown};
  if(!r||typeof r!=='object'||typeof r.dni!=='string'||!/^\d{8}$/.test(r.dni)||typeof r.name!=='string'||!r.name.trim())
   throw Error('Registro incompleto de trabajador.');
 }
}
async function decode(file:string,key:CryptoKey):Promise<unknown[]>{
 if(!/^danper\/private\/workers-[a-z0-9-]+\.enc$/.test(file))throw Error('Ruta privada inválida.');
 let read;
 try{read=await Filesystem.readFile({path:file,directory:Directory.Data,encoding:Encoding.UTF8})}
 catch(error){if(isMissingFileError(error))throw new MissingWorkerVaultError();throw error}
 if(typeof read.data!=='string')throw Error('Padrón cifrado ilegible.');
 const e=JSON.parse(read.data) as {version:number;iv:string;payload:string};
 if(e.version!==1)throw Error('Versión de padrón no admitida.');
 const iv=unb64(e.iv),cipher=unb64(e.payload);
 if(iv.length!==12||cipher.length>12*1024*1024)throw Error('Datos cifrados inválidos.');
 const clear=await crypto.subtle.decrypt({name:'AES-GCM',iv},key,cipher);
 const rows=JSON.parse(new TextDecoder().decode(clear)) as unknown;
 verifyWorkers(rows);
 return rows;
}
export async function loadWorkerVault():Promise<unknown[]|null>{
 const path=await SecureStorage.getItem(POINTER);
 if(path===null){lastWrite='';missingFile=false;return null}
 try{
  const rows=await decode(path,await secret());
  lastWrite=JSON.stringify(rows);missingFile=false;
  return rows;
 }catch(error){
  if(error instanceof MissingWorkerVaultError)missingFile=true;
  throw error;
 }
}
async function commitWorkerVault(rows:unknown[],explicitRestore:boolean):Promise<void>{
 if(missingFile&&!explicitRestore)throw new MissingWorkerVaultError();
 verifyWorkers(rows);
 const data=JSON.stringify(rows);
 if(new TextEncoder().encode(data).length>10*1024*1024)throw Error('Padrón demasiado grande.');
 const active=await SecureStorage.getItem(POINTER);
 if(active&&lastWrite===data&&!explicitRestore)return;
 const key=await secret(),iv=crypto.getRandomValues(new Uint8Array(12));
 const cipher=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv},key,new TextEncoder().encode(data)));
 const path='danper/private/workers-'+crypto.randomUUID()+'.enc';
 await ensurePrivateDirectory();
 await Filesystem.writeFile({path,directory:Directory.Data,encoding:Encoding.UTF8,
  data:JSON.stringify({version:1,iv:b64(iv),payload:b64(cipher)})});
 const check=await decode(path,key);
 if(JSON.stringify(check)!==data)throw Error('Padrón cifrado no verificable.');
 await SecureStorage.setItem(POINTER,path);
 if(await SecureStorage.getItem(POINTER)!==path)throw Error('No se confirmó el guardado del padrón.');
 lastWrite=data;
}

/** Normal updates may never overwrite the missing employee directory. */
export async function writeWorkerVault(rows:unknown[]):Promise<void>{
 return commitWorkerVault(rows,false);
}
/** Explicit restoration preserves the previous Keychain file reference. */
export async function restoreMissingWorkerVault(rows:unknown[]):Promise<void>{
 if(!missingFile)throw Error('El padrón no requiere recuperación.');
 verifyWorkers(rows);
 const previous=await SecureStorage.getItem(POINTER);
 if(!previous)throw Error('No hay una referencia anterior que conservar.');
 const raw=await SecureStorage.getItem(ORPHANS);
 let refs:string[]=[];
 if(raw!==null){
  const parsed:unknown=JSON.parse(raw);
  if(!Array.isArray(parsed)||parsed.some(x=>typeof x!=='string'))throw Error('Referencias anteriores dañadas. No se sobrescribirán.');
  refs=parsed as string[];
 }
 if(!refs.includes(previous))refs.push(previous);
 const recorded=JSON.stringify(refs);
 await SecureStorage.setItem(ORPHANS,recorded);
 if(await SecureStorage.getItem(ORPHANS)!==recorded)throw Error('No se pudo verificar la referencia anterior.');
 await commitWorkerVault(rows,true);
 missingFile=false;
}
