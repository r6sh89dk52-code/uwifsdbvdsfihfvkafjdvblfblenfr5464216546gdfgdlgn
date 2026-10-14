import {Capacitor,registerPlugin} from '@capacitor/core';

type DeviceKeyPlugin={getKey(options:{create:boolean}):Promise<{key:string}>};
const nativeKey=registerPlugin<DeviceKeyPlugin>('DanperBackupKey');
/** Access is performed in native iOS with LocalAuthentication + Keychain
 * userPresence, not by checking a JS-only flag. No key is stored in web storage.
 */
export async function obtainDeviceBackupKey(create:boolean):Promise<Uint8Array>{
 if(!Capacitor.isNativePlatform()||Capacitor.getPlatform()!=='ios')
  throw Error('El respaldo protegido por Face ID requiere iPhone.');
 const response=await nativeKey.getKey({create});
 const encoded=response?.key;
 if(typeof encoded!=='string'||encoded.length!==44||!/^[A-Za-z0-9+/]{43}=$/.test(encoded))
  throw Error('No se pudo obtener una clave de respaldo válida.');
 const raw=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0));
 if(raw.length!==32)throw Error('La clave del respaldo tiene una longitud inválida.');
 return raw;
}
