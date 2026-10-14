/** Prepare an encrypted, device-local export in a separate step from iOS Share.
 * No database migration or writes. Only encrypted data is written to Cache.
 */
import {Filesystem,Directory} from '@capacitor/filesystem';
import {readStableSnapshotForBackup,validateDemoSnapshot} from './secureDemoStore';
import {encryptPortableBackup,decryptPortableBackup} from './portableBackup';

export type PreparedBackup={name:string;uri:string;size:number};
function asBase64(text:string):string{
 const bytes=new TextEncoder().encode(text);
 let binary='';
 for(let i=0;i<bytes.length;i+=8192)binary+=String.fromCharCode(...bytes.subarray(i,i+8192));
 return btoa(binary);
}
export async function prepareEncryptedBackup(password:string,onProgress:(status:string)=>void):Promise<PreparedBackup>{
 onProgress('1/4 · Leyendo los registros del iPhone…');
 const snapshot=validateDemoSnapshot(await readStableSnapshotForBackup());
 onProgress('2/4 · Protegiendo el respaldo con tu contraseña…');
 const encrypted=await encryptPortableBackup(snapshot,password);
 onProgress('3/4 · Verificando que pueda descifrarse…');
 const verified=validateDemoSnapshot(await decryptPortableBackup(encrypted,password));
 if(JSON.stringify(verified)!==JSON.stringify(snapshot))
  throw Error('La comprobación del respaldo no coincide con el padrón y los registros actuales.');
 onProgress('4/4 · Guardando el archivo cifrado para compartir…');
 const token=crypto.randomUUID().slice(0,8);
 const name='DANPER-Respaldo-'+new Date().toISOString().slice(0,10)+'-'+token+'.danperbackup';
 const contents=asBase64(encrypted);
 await Filesystem.writeFile({path:name,directory:Directory.Cache,data:contents});
 const stat=await Filesystem.stat({path:name,directory:Directory.Cache});
 if(stat.type!=='file'||(typeof stat.size==='number'&&stat.size===0))
  throw Error('No se pudo verificar el archivo cifrado creado en el iPhone.');
 const location=await Filesystem.getUri({path:name,directory:Directory.Cache});
 if(!location.uri||!location.uri.startsWith('file://'))
  throw Error('iOS no devolvió una ruta local válida para compartir el respaldo.');
 return{name,uri:location.uri,size:encrypted.length};
}
