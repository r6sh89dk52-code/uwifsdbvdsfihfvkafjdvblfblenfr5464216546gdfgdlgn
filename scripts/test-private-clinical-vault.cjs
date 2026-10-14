const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');
const {webcrypto,randomUUID}=require('node:crypto');
const files=new Map(),directories=new Set(),keys=new Map();
let mkdirCount=0,writeFailure=false,corruptRead=false;
const SecureStorage={
 async getItem(key){return keys.get(key)??null},
 async setItem(key,value){keys.set(key,value)},
 async setKeyPrefix(){},async setSynchronize(){},async setDefaultKeychainAccess(){}
};
const Filesystem={
 async stat({path}){if(!directories.has(path))throw Error("Directory does not exist");return {type:'directory'}},
 async mkdir({path}){mkdirCount++;if(directories.has(path))throw Error("Directory already exists, cannot be overwritten");directories.add(path)},
 async writeFile({path,data}){if(writeFailure)throw Error('simulated disk full');files.set(path,data)},
 async readFile({path}){if(!files.has(path))throw Error("'readFile' failed because file does not exist");return {data:corruptRead?JSON.stringify({v:1,iv:'invalid',data:'invalid'}):files.get(path)}}
};
function moduleFrom(path,imports){
 const src=fs.readFileSync(path,'utf8');
 const compiled=ts.transpileModule(src,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},reportDiagnostics:true});
 assert.equal(compiled.diagnostics.filter(x=>x.category===ts.DiagnosticCategory.Error).length,0,'transpile diagnostics '+path);
 const exports={},module={exports};
 const context={module,exports,require:imports,localStorage,
  Uint8Array,ArrayBuffer,TextEncoder,TextDecoder,Promise,Error,Object,Array,String,JSON,
  crypto:{getRandomValues:a=>webcrypto.getRandomValues(a),subtle:webcrypto.subtle,randomUUID},
  btoa:s=>Buffer.from(s,'latin1').toString('base64'),
  atob:s=>Buffer.from(s,'base64').toString('latin1')
 };
 vm.runInNewContext(compiled.outputText,context,{filename:path});
 return module.exports;
}
const local=new Map();
const localStorage={getItem:k=>local.get(k)??null,setItem:(k,v)=>local.set(k,v),removeItem:k=>local.delete(k)};
const vault=moduleFrom('src/privateClinicalVault.ts',name=>{
 if(name==='@capacitor/filesystem')return {Filesystem,Directory:{Data:'DATA'},Encoding:{UTF8:'utf8'}};
 if(name==='@aparajita/capacitor-secure-storage')return{SecureStorage};
 throw Error(name);
});
(async()=>{
 const original={attentions:Array.from({length:1500},(_,i)=>({id:'FICTICIA-'+i,diagnosis:'TEST ONLY'})),workers:[],allergies:{},notifications:false,stockLots:[{product:'FICTICIO'}],stockMovements:[],catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]};
 assert.equal(await vault.clinicalVaultPresent(),false);
 assert.equal(await vault.loadClinicalVault(),null);
 await vault.writeClinicalVault(original);
 const first=keys.get('clinical-v1-active-file');
 assert.ok(first&&files.has(first));assert.equal(mkdirCount,1);
 assert.ok(!files.get(first).includes('FICTICIA-1'),'all clinical records must be encrypted');
 assert.equal((await vault.loadClinicalVault()).attentions.length,1500);
 const newer={...original,attentions:original.attentions.slice(0,12)};
 writeFailure=true;
 await assert.rejects(vault.writeClinicalVault(newer),/disk full/);
 writeFailure=false;
 assert.equal(keys.get('clinical-v1-active-file'),first,'failure does not advance active generation');
 assert.equal((await vault.loadClinicalVault()).attentions.length,1500);
 await vault.writeClinicalVault(newer);
 const second=keys.get('clinical-v1-active-file');
 assert.notEqual(second,first);assert.ok(files.has(first),'old encrypted file preserved');
 assert.equal(mkdirCount,1,'repeated saves cannot recreate folder');
 assert.equal((await vault.loadClinicalVault()).attentions.length,12);
 corruptRead=true;
 await assert.rejects(vault.loadClinicalVault());
 corruptRead=false;
 assert.equal(keys.get('clinical-v1-active-file'),second);
 files.delete(second);
 await assert.rejects(vault.loadClinicalVault(),/no está disponible/);
 assert.equal(keys.get('clinical-v1-active-file'),second,'missing clinical file does not reset pointer');
 keys.delete('clinical-v1-active-file');
 const workers=[{dni:'00000001',name:'PERSONA FICTICIA'}];
 let workerFile=workers,workerMissing=false,writeWorkerCalls=0;
 const secure=moduleFrom('src/secureDemoStore.ts',name=>{
  if(name==='@aparajita/capacitor-secure-storage')return{SecureStorage,KeychainAccess:{whenUnlockedThisDeviceOnly:1}};
  if(name==='@capacitor/core')return{Capacitor:{isNativePlatform:()=>true,getPlatform:()=> 'ios'}};
  if(name==='./privateClinicalVault')return {loadClinicalVault:vault.loadClinicalVault,writeClinicalVault:vault.writeClinicalVault};
  if(name==='./privateWorkerVault')return {
    MissingWorkerVaultError:class MissingWorkerVaultError extends Error {},
    workerVaultRecoveryRequired:()=>workerMissing,
    loadWorkerVault:async()=>{if(workerMissing)throw Error('missing worker file');return workerFile},
    writeWorkerVault:async x=>{workerFile=JSON.parse(JSON.stringify(x));writeWorkerCalls++}
  };
  throw Error(name);
 });
 const prior={...newer,workers:[]};
 const priorRaw=JSON.stringify(prior);
 keys.set('prototype-snapshot-v1',priorRaw);
 const merged=await secure.loadDemoSnapshot();
 assert.equal(merged.workers[0].dni,'00000001','existing encrypted roster stays intact');
 assert.equal(merged.attentions.length,12);
 assert.equal(keys.get('clinical-v1-legacy-verified-snapshot'),priorRaw,'original Keychain snapshot preserved');
 assert.equal(JSON.parse(keys.get('prototype-snapshot-v1')).version,2,'marker only after migration');
 assert.equal((await secure.loadDemoSnapshot()).attentions.length,12,'reopen encrypted clinical state');
 workerFile=null;
 await assert.rejects(secure.loadDemoSnapshot(),/No existe una referencia al padrón cifrado/,'missing roster pointer fails closed');
 assert.equal(keys.get('clinical-v1-legacy-verified-snapshot'),priorRaw,'missing workers cannot replace backup');
 workerFile=workers;
 const loaded=await secure.loadDemoSnapshot();assert.equal(loaded.workers.length,1);
 const changed={...loaded,attentions:[{id:'FICTICIA-NEW'}]};
 await secure.writeDemoSnapshot(changed);
 assert.equal((await secure.loadDemoSnapshot()).attentions[0].id,'FICTICIA-NEW');
 assert.equal(writeWorkerCalls,1,'clinical save keeps existing worker roster in the separate encrypted store');
 console.log('PASS: AES-GCM clinical storage, rollback, 1500 fake attentions, pre-migration backup, missing worker rejection, reopen and encrypted update.');
})().catch(error=>{console.error(error);process.exitCode=1});
