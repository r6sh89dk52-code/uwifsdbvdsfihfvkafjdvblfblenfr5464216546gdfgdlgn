const assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),ts=require('typescript');
const original=fs.readFileSync('src/secureDemoStore.ts','utf8');
const code=ts.transpileModule(original,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
const keychain=new Map(),local=new Map(),preparedWorkers=new Map(),preparedClinical=new Map();
let activeWorkers=null,activeClinical=null,workerFails=false,clinicalCommitFail=false,verifiedFails=false,seq=0;
const keychainAPI={
 async setKeyPrefix(){},async setSynchronize(){},async setDefaultKeychainAccess(){},
 async getItem(k){return keychain.get(k)??null},
 async setItem(k,v){keychain.set(k,v)}
};
const localStorage={getItem:k=>local.get(k)??null,setItem:(k,v)=>local.set(k,v),removeItem:k=>local.delete(k)};
class MissingWorkerVaultError extends Error{}
const mock={
 clinical:{
  loadClinicalVault:async()=>activeClinical,
  writeClinicalVault:async snapshot=>{activeClinical=JSON.parse(JSON.stringify(snapshot))},
  stageClinicalRestore:async snapshot=>{if(verifiedFails)throw Error('clinical staging damaged');const path='clinical-'+(++seq);preparedClinical.set(path,JSON.parse(JSON.stringify(snapshot)));return path},
  verifyStagedClinicalRestore:async path=>{if(verifiedFails||!preparedClinical.has(path))throw Error('clinical staging damaged')},
  activateClinicalRestore:async path=>{if(clinicalCommitFail){clinicalCommitFail=false;throw Error('simulated iOS crash')}activeClinical=preparedClinical.get(path)}
 },
 worker:{
  MissingWorkerVaultError,
  workerVaultRecoveryRequired:()=>false,
  loadWorkerVault:async()=>activeWorkers,
  writeWorkerVault:async values=>{activeWorkers=JSON.parse(JSON.stringify(values))},
  stageWorkerRestore:async values=>{if(workerFails)throw Error('disk full');const path='workers-'+(++seq);preparedWorkers.set(path,JSON.parse(JSON.stringify(values)));return path},
  verifyStagedWorkerRestore:async path=>{if(!preparedWorkers.has(path))throw Error('worker staging missing')},
  activateWorkerRestore:async path=>{activeWorkers=preparedWorkers.get(path)}
 }
};
const module={exports:{}},context={module,exports:module.exports,localStorage,JSON,Object,Array,String,Error,Promise};
context.require=name=>{
 if(name==='@aparajita/capacitor-secure-storage')return {SecureStorage:keychainAPI,KeychainAccess:{whenUnlockedThisDeviceOnly:1}};
 if(name==='@capacitor/core')return {Capacitor:{isNativePlatform:()=>true,getPlatform:()=> 'ios'}};
 if(name==='./privateClinicalVault')return mock.clinical;
 if(name==='./privateWorkerVault')return mock.worker;
 throw Error(name);
};
vm.runInNewContext(code,context,{filename:'secureDemoStore.js'});
const store=module.exports;
(async()=>{
 const sample={attentions:[{id:'VISITA FICTICIA'}],workers:[{dni:'12345678',name:'TRABAJADOR DEMO'}],allergies:{},notifications:false,stockLots:[],stockMovements:[],catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]};
 workerFails=true;
 await assert.rejects(store.restoreEmptyDeviceFromBackup(sample),/disk full/);
 assert.equal(activeWorkers,null);assert.equal(activeClinical,null);
 assert.equal(keychain.has('clinical-v1-portable-restore-pending'),false,'no journal before both verified');
 workerFails=false;
 verifiedFails=true;
 await assert.rejects(store.restoreEmptyDeviceFromBackup(sample),/clinical staging damaged/);
 assert.equal(activeWorkers,null);
 verifiedFails=false;
 clinicalCommitFail=true;
 await assert.rejects(store.restoreEmptyDeviceFromBackup(sample),/simulated iOS crash/);
 assert.ok(keychain.get('clinical-v1-portable-restore-pending')?.includes('workerPath'),'recovery journal survives crash');
 const resumed=await store.loadDemoSnapshot();
 assert.equal(resumed.workers.length,1);assert.equal(resumed.attentions.length,1);
 assert.equal(keychain.get('clinical-v1-portable-restore-pending'),'finished');
 assert.equal(JSON.parse(keychain.get('prototype-snapshot-v1')).version,2);
 await assert.rejects(store.restoreEmptyDeviceFromBackup(sample),/Ya existen trabajadores/,'cannot overwrite populated database');
 console.log('PASS: staged clinical+roster restore, interrupted pointer swap recovered on next boot, write failure rollback and populated database protection.');
})().catch(error=>{console.error(error);process.exitCode=1});
