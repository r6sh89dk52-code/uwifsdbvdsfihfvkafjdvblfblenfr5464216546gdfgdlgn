const assert=require('node:assert/strict'),fs=require('node:fs');
const view=fs.readFileSync('src/BackupSettingsPanel.tsx','utf8');
const secure=fs.readFileSync('src/secureDemoStore.ts','utf8');
const portable=fs.readFileSync('src/portableBackup.ts','utf8');

for(const text of [
 "const [password,setPassword]=useState('')",
 "const [restorePassword,setRestorePassword]=useState('')",
 'Nueva contraseña para crear respaldo',
 'Contraseña del archivo que vas a restaurar',
 'value={restorePassword}',
 'decryptPortableBackup(contents,restorePassword)',
 "restorePassword.length<14",
 "setRestorePassword('')",
 "setPreview(null);setSourceName('')",
 'hasActiveRecords(current)',
 'restoreEmptyDeviceFromBackup(preview)'
])assert(view.includes(text),'missing separate backup/restore protection: '+text);

assert(view.includes('encryptPortableBackup(snapshot,password)'),'new archive creation still uses creation password');
assert(!view.includes('decryptPortableBackup(contents,password)'),'existing create password must not be reused silently for restore');
assert(view.includes('disabled={!native||busy||restorePassword.length<14}'),'do not allow file picking without password');
assert(view.includes('setPreview(null);setSourceName(\'\');setError(\'\');setStatus(\'\')'),'changing password must clear verified preview');
assert(secure.includes("if(containsData(current))"),'never overwrite nonempty iPhone');
assert(secure.includes('await finishPendingRestore()'),'preserve interrupted restore recovery');
assert(portable.includes('crypto.subtle.decrypt'),'backup password must be authenticated cryptographically');
assert(portable.includes("Contraseña incorrecta o respaldo alterado"),'wrong password refuses restoration');
console.log('PASS: distinct create/restore passwords, mandatory 14-char restoration input, no leaked preview, no overwrite, encrypted archive verified.');
