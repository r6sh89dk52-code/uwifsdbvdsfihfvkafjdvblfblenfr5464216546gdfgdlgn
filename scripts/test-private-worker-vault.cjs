const assert=require('node:assert/strict');
const {webcrypto,randomUUID}=require('node:crypto');
const fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');
const original=fs.readFileSync('src/privateWorkerVault.ts','utf8');
const result=ts.transpileModule(original,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
const keychain=new Map(),files=new Map();
let failFile=false,mkdirCount=0,statCount=0;
const dirs=new Set();
let pretendDirectoryIsFile=false;
const SecureStorage={async getItem(k){return keychain.get(k)??null},async setItem(k,v){keychain.set(k,v)}};
const Filesystem={
 async stat({path}){statCount++;if(pretendDirectoryIsFile&&path==='danper/private')return{type:'file'};if(!dirs.has(path))throw Error('Directory does not exist');return {type:'directory'};},
 async mkdir({path}){mkdirCount++;if(dirs.has(path))throw Error('Directory already exists, cannot be overwritten');dirs.add(path);},
 async readFile({path}){if(!files.has(path))throw Error("'readFile' failed because file does not exist.");return{data:files.get(path)}},
 async writeFile({path,data}){if(failFile)throw Error('disk full');files.set(path,data)}
};
const context={module:{exports:{}},require(name){
 if(name==='@capacitor/filesystem')return {Filesystem,Directory:{Data:'data'},Encoding:{UTF8:'utf8'}};
 if(name==='@aparajita/capacitor-secure-storage')return{SecureStorage};
 throw Error(name)
},crypto:{subtle:webcrypto.subtle,getRandomValues:(a)=>webcrypto.getRandomValues(a),randomUUID},atob:s=>Buffer.from(s,'base64').toString('latin1'),btoa:s=>Buffer.from(s,'latin1').toString('base64'),TextEncoder,TextDecoder,Uint8Array,JSON,Error,Array,Promise,String,Number};
context.exports=context.module.exports;
vm.runInNewContext(result.outputText,context,{filename:'privateWorkerVault.js'});
const {loadWorkerVault,writeWorkerVault,restoreMissingWorkerVault,workerVaultRecoveryRequired}=context.module.exports;
(async()=>{
 assert.equal(await loadWorkerVault(),null);
 const rows=Array.from({length:9635},(_,i)=>({dni:String(10000000+i),name:'TRABAJADOR FICTICIO '+i,sex:i%2?'M':'F'}));
 await writeWorkerVault(rows);
 let path=keychain.get('workers-v1-file');
 assert.ok(path?.endsWith('.enc'));
 assert.equal(mkdirCount,1,'first import creates directory exactly once');
 assert.ok(!files.get(path).includes('TRABAJADOR FICTICIO'));
 assert.ok(!files.get(path).includes('10000000'));
 assert.equal((await loadWorkerVault()).length,9635);
 assert.equal(keychain.get('workers-v1-aes-key').length,44);
 const previous=path;
 failFile=true;
 await assert.rejects(writeWorkerVault(rows.slice(0,100)),/disk full/);
 failFile=false;
 assert.equal(keychain.get('workers-v1-file'),previous,'failed update cannot advance active pointer');
 assert.equal((await loadWorkerVault()).length,9635,'failed update retains old encrypted data');
 await writeWorkerVault(rows.slice(0,100));
 assert.equal(mkdirCount,1,'updating existing directory must not invoke mkdir');
 path=keychain.get('workers-v1-file');
 assert.notEqual(path,previous);
 assert.equal((await loadWorkerVault()).length,100);
 const saved=files.get(path),parsed=JSON.parse(saved);
 parsed.payload=parsed.payload.replace(/^./,parsed.payload[0]==='A'?'B':'A');
 files.set(path,JSON.stringify(parsed));
 await assert.rejects(loadWorkerVault(),'corruption must fail, never reset to empty');
 files.set(path,saved);
 assert.equal((await loadWorkerVault()).length,100);
 // Real iPhone regression: old Keychain reference still exists after
 // an upgrade but the referenced Documents directory was not preserved.
 const originalPointer=keychain.get('workers-v1-file');
 files.delete(originalPointer);
 await assert.rejects(loadWorkerVault(),error=>error.name==='MissingWorkerVaultError');
 assert.equal(workerVaultRecoveryRequired(),true);
 await assert.rejects(writeWorkerVault([]),/no está disponible/);
 assert.equal(keychain.get('workers-v1-file'),originalPointer,'the missing pointer is never automatically overwritten');
 failFile=true;
 await assert.rejects(restoreMissingWorkerVault([]),/disk full/);
 failFile=false;
 assert.equal(keychain.get('workers-v1-file'),originalPointer,'failed explicit restore retains missing pointer');
 await restoreMissingWorkerVault([]);
 const recoveredPointer=keychain.get('workers-v1-file');
 assert.notEqual(recoveredPointer,originalPointer);
 assert.equal(mkdirCount,1,'explicit recovery uses the existing directory');
 assert.equal(workerVaultRecoveryRequired(),false);
 assert.equal((await loadWorkerVault()).length,0);
 assert.ok(JSON.parse(keychain.get('workers-v1-missing-file-references')).includes(originalPointer),'old reference kept for forensics');
 // Regression from physical iPhone: user first restored an empty directory,
 // then imported 9635 workers. The directory already exists at that point.
 await writeWorkerVault(rows);
 assert.equal((await loadWorkerVault()).length,9635);
 assert.equal(mkdirCount,1,'import after empty recovery must not attempt mkdir again');
 await writeWorkerVault(rows);
 assert.equal(mkdirCount,1,'re-import of identical workers never recreates folder');
 assert.equal((await loadWorkerVault()).length,9635);
 pretendDirectoryIsFile=true;
 await assert.rejects(writeWorkerVault(rows.slice(0,5)),/no es una carpeta/);
 pretendDirectoryIsFile=false;
 assert.equal((await loadWorkerVault()).length,9635,'unsafe directory state must never advance active vault');
 assert.ok(statCount>1,'directory existence was checked using native stat');
 console.log('PASS: on-device AES-GCM encryption of 9635 fictitious workers, Keychain pointer, rollback and fail-closed tamper detection.');
})().catch(error=>{console.error(error);process.exitCode=1});
