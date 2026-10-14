const assert=require('node:assert/strict');
const {webcrypto,randomUUID}=require('node:crypto');
const fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');
const original=fs.readFileSync('src/privateWorkerVault.ts','utf8');
const result=ts.transpileModule(original,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
const keychain=new Map(),files=new Map();
let failFile=false;
const SecureStorage={async getItem(k){return keychain.get(k)??null},async setItem(k,v){keychain.set(k,v)}};
const Filesystem={
 async mkdir(){},
 async readFile({path}){if(!files.has(path))throw Error('file missing');return{data:files.get(path)}},
 async writeFile({path,data}){if(failFile)throw Error('disk full');files.set(path,data)}
};
const context={module:{exports:{}},require(name){
 if(name==='@capacitor/filesystem')return {Filesystem,Directory:{Data:'data'},Encoding:{UTF8:'utf8'}};
 if(name==='@aparajita/capacitor-secure-storage')return{SecureStorage};
 throw Error(name)
},crypto:{subtle:webcrypto.subtle,getRandomValues:(a)=>webcrypto.getRandomValues(a),randomUUID},atob:s=>Buffer.from(s,'base64').toString('latin1'),btoa:s=>Buffer.from(s,'latin1').toString('base64'),TextEncoder,TextDecoder,Uint8Array,JSON,Error,Array,Promise,String,Number};
context.exports=context.module.exports;
vm.runInNewContext(result.outputText,context,{filename:'privateWorkerVault.js'});
const {loadWorkerVault,writeWorkerVault}=context.module.exports;
(async()=>{
 assert.equal(await loadWorkerVault(),null);
 const rows=Array.from({length:9635},(_,i)=>({dni:String(10000000+i),name:'TRABAJADOR FICTICIO '+i,sex:i%2?'M':'F'}));
 await writeWorkerVault(rows);
 let path=keychain.get('workers-v1-file');
 assert.ok(path?.endsWith('.enc'));
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
 path=keychain.get('workers-v1-file');
 assert.notEqual(path,previous);
 assert.equal((await loadWorkerVault()).length,100);
 const saved=files.get(path),parsed=JSON.parse(saved);
 parsed.payload=parsed.payload.replace(/^./,parsed.payload[0]==='A'?'B':'A');
 files.set(path,JSON.stringify(parsed));
 await assert.rejects(loadWorkerVault(),'corruption must fail, never reset to empty');
 files.set(path,saved);
 assert.equal((await loadWorkerVault()).length,100);
 console.log('PASS: on-device AES-GCM encryption of 9635 fictitious workers, Keychain pointer, rollback and fail-closed tamper detection.');
})().catch(error=>{console.error(error);process.exitCode=1});
