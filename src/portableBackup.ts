/** Portable on-device backup. A user-chosen passphrase is essential:
 * a Keychain encryption key alone cannot decrypt data on a replacement phone.
 * This module never stores the passphrase or puts plaintext data in the IPA.
 */
const BACKUP_FORMAT='DANPER-SALUD-PORTABLE-BACKUP';
const ITERATIONS=310000;
const MAX_TEXT=42*1024*1024;
const MAX_PLAIN=30*1024*1024;
const textEncoder=new TextEncoder();
function b64(bytes:Uint8Array):string{
 let out='';for(let pos=0;pos<bytes.length;pos+=8192)out+=String.fromCharCode(...bytes.subarray(pos,pos+8192));
 return btoa(out);
}
function unb64(value:string):Uint8Array{
 if(typeof value!=='string'||value.length>MAX_TEXT||value.length%4!==0||!/^[A-Za-z0-9+/]*={0,2}$/.test(value))throw Error('Codificación del respaldo inválida.');
 return Uint8Array.from(atob(value),s=>s.charCodeAt(0));
}
async function passphraseKey(passphrase:string,salt:Uint8Array):Promise<CryptoKey>{
 if(typeof passphrase!=='string'||passphrase.length<14||passphrase.length>200)throw Error('La contraseña debe tener entre 14 y 200 caracteres.');
 const secret=await crypto.subtle.importKey('raw',textEncoder.encode(passphrase).buffer as ArrayBuffer,'PBKDF2',false,['deriveKey']);
 return crypto.subtle.deriveKey({name:'PBKDF2',salt:salt.buffer as ArrayBuffer,iterations:ITERATIONS,hash:'SHA-256'},secret,{name:'AES-GCM',length:256},false,['encrypt','decrypt']);
}
export async function encryptPortableBackup(snapshot:unknown,passphrase:string):Promise<string>{
 if(!snapshot||typeof snapshot!=='object'||Array.isArray(snapshot))throw Error('Datos de respaldo incompatibles.');
 const plaintext=JSON.stringify({schema:1,exportedAt:new Date().toISOString(),snapshot});
 if(textEncoder.encode(plaintext).byteLength>MAX_PLAIN)throw Error('La base es demasiado grande para este tipo de respaldo.');
 const salt=crypto.getRandomValues(new Uint8Array(16));
 const iv=crypto.getRandomValues(new Uint8Array(12));
 const key=await passphraseKey(passphrase,salt);
 const encrypted=await crypto.subtle.encrypt({name:'AES-GCM',iv:iv.buffer as ArrayBuffer},key,textEncoder.encode(plaintext).buffer as ArrayBuffer);
 const result=JSON.stringify({format:BACKUP_FORMAT,version:1,kdf:'PBKDF2-SHA256',iterations:ITERATIONS,cipher:'AES-256-GCM',salt:b64(salt),nonce:b64(iv),data:b64(new Uint8Array(encrypted))});
 if(result.length>MAX_TEXT)throw Error('El archivo cifrado es demasiado grande.');
 return result;
}
export async function decryptPortableBackup(archive:string,passphrase:string):Promise<unknown>{
 if(typeof archive!=='string'||archive.length>MAX_TEXT||archive.length<100)throw Error('El archivo de respaldo es inválido o excede el tamaño permitido.');
 let parsed:unknown;
 try{parsed=JSON.parse(archive)}catch{throw Error('Archivo de respaldo ilegible.')}
 if(!parsed||typeof parsed!=='object'||Array.isArray(parsed))throw Error('Respaldo incompatible.');
 const record=parsed as Record<string,unknown>;
 if(record.format!==BACKUP_FORMAT||record.version!==1||record.kdf!=='PBKDF2-SHA256'||record.iterations!==ITERATIONS||record.cipher!=='AES-256-GCM')
  throw Error('Versión o parámetros del respaldo no compatibles.');
 if(typeof record.salt!=='string'||typeof record.nonce!=='string'||typeof record.data!=='string')throw Error('Contenido de respaldo incompleto.');
 const salt=unb64(record.salt),nonce=unb64(record.nonce),cipher=unb64(record.data);
 if(salt.length!==16||nonce.length!==12||cipher.length<16||cipher.length>MAX_TEXT)throw Error('Tamaños criptográficos inválidos.');
 const key=await passphraseKey(passphrase,salt);
 let plain:ArrayBuffer;
 try{plain=await crypto.subtle.decrypt({name:'AES-GCM',iv:nonce.buffer as ArrayBuffer},key,cipher.buffer as ArrayBuffer)}
 catch{throw Error('Contraseña incorrecta o respaldo alterado. No se ha cambiado ningún dato.')}
 if(plain.byteLength>MAX_PLAIN)throw Error('Contenido descifrado fuera de límite.');
 let payload:unknown;
 try{payload=JSON.parse(new TextDecoder().decode(plain))}catch{throw Error('El respaldo descifrado está dañado.')}
 if(!payload||typeof payload!=='object'||Array.isArray(payload))throw Error('Datos descifrados inválidos.');
 const data=payload as {schema?:unknown;snapshot?:unknown};
 if(data.schema!==1||!data.snapshot||typeof data.snapshot!=='object'||Array.isArray(data.snapshot))throw Error('Esquema de respaldo desconocido.');
 return data.snapshot;
}


/**
 * Version 2: passphrase-free same-device backup, authenticated by the native
 * iPhone keychain (.userPresence) on EVERY key retrieval. This is NOT a
 * portable recovery format: the key is ThisDeviceOnly and cannot be recovered
 * if the original device, passcode or app keychain access is lost. v1 remains
 * available for recoverable off-device backups.
 */
const DEVICE_FORMAT='DANPER-SALUD-DEVICE-LOCKED-BACKUP';
async function deviceCryptoKey(rawKey:Uint8Array,uses:KeyUsage[]):Promise<CryptoKey>{
 if(!(rawKey instanceof Uint8Array)||rawKey.length!==32)throw Error('Clave local del dispositivo inválida.');
 return crypto.subtle.importKey('raw',rawKey.buffer as ArrayBuffer,{name:'AES-GCM'},false,uses);
}
export async function encryptDeviceBackup(snapshot:unknown,rawKey:Uint8Array):Promise<string>{
 if(!snapshot||typeof snapshot!=='object'||Array.isArray(snapshot))throw Error('Datos de respaldo incompatibles.');
 const plaintext=JSON.stringify({schema:1,exportedAt:new Date().toISOString(),snapshot});
 const bytes=textEncoder.encode(plaintext);
 if(bytes.byteLength>MAX_PLAIN)throw Error('La base supera el límite de respaldo.');
 const nonce=crypto.getRandomValues(new Uint8Array(12));
 const key=await deviceCryptoKey(rawKey,['encrypt']);
 const ciphertext=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv:nonce.buffer as ArrayBuffer},key,bytes.buffer as ArrayBuffer));
 const serialized=JSON.stringify({format:DEVICE_FORMAT,version:2,keyStore:'iOS-this-device-only',cipher:'AES-256-GCM',nonce:b64(nonce),data:b64(ciphertext)});
 if(serialized.length>MAX_TEXT)throw Error('El respaldo supera el tamaño permitido.');
 return serialized;
}
export async function decryptDeviceBackup(archive:string,rawKey:Uint8Array):Promise<unknown>{
 if(typeof archive!=='string'||archive.length<100||archive.length>MAX_TEXT)throw Error('El archivo de respaldo local es inválido.');
 let obj:unknown;
 try{obj=JSON.parse(archive)}catch{throw Error('Respaldo local ilegible.')}
 if(!obj||typeof obj!=='object'||Array.isArray(obj))throw Error('Respaldo local incompatible.');
 const r=obj as Record<string,unknown>;
 if(r.format!==DEVICE_FORMAT||r.version!==2||r.keyStore!=='iOS-this-device-only'||r.cipher!=='AES-256-GCM')
  throw Error('El archivo no es un respaldo local v2 de este iPhone.');
 if(typeof r.nonce!=='string'||typeof r.data!=='string')throw Error('Respaldo local incompleto.');
 const nonce=unb64(r.nonce),cipher=unb64(r.data);
 if(nonce.length!==12||cipher.length<16||cipher.length>MAX_TEXT)throw Error('Respaldo cifrado fuera de límites.');
 const key=await deviceCryptoKey(rawKey,['decrypt']);
 let plain:ArrayBuffer;
 try{plain=await crypto.subtle.decrypt({name:'AES-GCM',iv:nonce.buffer as ArrayBuffer},key,cipher.buffer as ArrayBuffer)}
 catch{throw Error('No puede abrirse esta copia con la clave de este iPhone o el archivo fue alterado. La base no se modificó.')}
 if(plain.byteLength>MAX_PLAIN)throw Error('El respaldo descifrado supera el tamaño permitido.');
 let payload:unknown;
 try{payload=JSON.parse(new TextDecoder().decode(plain))}catch{throw Error('El respaldo cifrado está dañado.')}
 if(!payload||typeof payload!=='object'||Array.isArray(payload))throw Error('Estructura del respaldo no válida.');
 const data=payload as {schema?:unknown;snapshot?:unknown};
 if(data.schema!==1||!data.snapshot||typeof data.snapshot!=='object'||Array.isArray(data.snapshot))
  throw Error('Datos del respaldo incompatibles.');
 return data.snapshot;
}
