const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');
const {webcrypto,randomUUID}=require('node:crypto');
function runTs(path,dependencies={}){
 const input=fs.readFileSync(path,'utf8');
 const code=ts.transpileModule(input,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const mod={exports:{}};
 const localStorage=dependencies.localStorage;
 const context={module:mod,exports:mod.exports,require:name=>{
  if(Object.hasOwn(dependencies,name))return dependencies[name];
  throw Error('missing dependency '+name);
 },localStorage,JSON,Object,Array,Uint8Array,ArrayBuffer,Date,Promise,Error,TextEncoder,TextDecoder,
 crypto:{subtle:webcrypto.subtle,getRandomValues:a=>webcrypto.getRandomValues(a),randomUUID},
 btoa:s=>Buffer.from(s,'latin1').toString('base64'),atob:s=>Buffer.from(s,'base64').toString('latin1')};
 vm.runInNewContext(code,context,{filename:path});
 return mod.exports;
}
const codec=runTs('src/portableBackup.ts');
const keychain=new Map(),browser=new Map();
const old={
 attentions:[{id:'FICTICIA-100',diagnosis:'SIMULACION'}],workers:[],allergies:{},notifications:false,
 stockLots:[{id:'LOTE-FICTICIO',quantity:30}],stockMovements:[{id:'MOV-FICTICIO',quantity:2}],
 catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]
};
const roster=[{dni:'12345678',name:'PERSONA FICTICIA A',source:'imported'},{dni:'87654321',name:'PERSONA FICTICIA B',source:'manual'}];
const oldRaw=JSON.stringify(old);keychain.set('prototype-snapshot-v1',oldRaw);
let workers=JSON.parse(JSON.stringify(roster)),clinical=null,writes=0;
const SecureStorage={
 async setKeyPrefix(){},async setSynchronize(){},async setDefaultKeychainAccess(){},
 async getItem(k){return keychain.get(k)??null},
 async setItem(k,v){keychain.set(k,v)}
};
const store=runTs('src/secureDemoStore.ts',{
 localStorage:{getItem:k=>browser.get(k)??null,setItem:(k,v)=>browser.set(k,v),removeItem:k=>browser.delete(k)},
 '@capacitor/core':{Capacitor:{isNativePlatform:()=>true,getPlatform:()=> 'ios'}},
 '@aparajita/capacitor-secure-storage':{SecureStorage,KeychainAccess:{whenUnlockedThisDeviceOnly:1}},
 './portableBackup':codec,
 './privateClinicalVault':{
  loadClinicalVault:async()=>clinical,
  writeClinicalVault:async state=>{writes++;clinical=JSON.parse(JSON.stringify(state))}
 },
 './privateWorkerVault':{
  MissingWorkerVaultError:class MissingWorkerVaultError extends Error{},
  workerVaultRecoveryRequired:()=>false,
  loadWorkerVault:async()=>workers,
  writeWorkerVault:async value=>{workers=JSON.parse(JSON.stringify(value))}
 }
});
(async()=>{
 await assert.rejects(store.loadDemoSnapshot(),e=>e.name==='ClinicalMigrationRequiredError');
 assert.equal(writes,0,'opening app must never migrate automatically');
 assert.equal(keychain.get('prototype-snapshot-v1'),oldRaw,'old Keychain snapshot preserved');
 const expected={...old,workers:roster};
 const originalPassword='RespaldoOriginalSegur0_2026!';
 const backup=await codec.encryptPortableBackup(expected,originalPassword);
 await assert.rejects(store.migrateFromVerifiedPortableBackup(backup,'ContraseñaIncorrecta2026!'),/Contraseña incorrecta/);
 assert.equal(writes,0,'wrong password must never write');
 const stale=await codec.encryptPortableBackup({...expected,workers:roster.slice(0,1)},originalPassword);
 await assert.rejects(store.migrateFromVerifiedPortableBackup(stale,originalPassword),/no coincide/);
 assert.equal(writes,0,'a different roster must never be migrated');
 assert.equal(keychain.get('prototype-snapshot-v1'),oldRaw);
 const oldClinical=await store.migrateFromVerifiedPortableBackup(backup,originalPassword);
 assert.equal(oldClinical.workers.length,2);
 assert.equal(oldClinical.attentions.length,1);
 assert.equal(writes,1,'confirmed migration commits one encrypted clinical generation');
 assert.equal(clinical.workers.length,0,'clinical vault never duplicates the worker file');
 assert.equal(keychain.get('clinical-v1-legacy-verified-snapshot'),oldRaw,'original retained in Keychain');
 assert.equal(JSON.parse(keychain.get('prototype-snapshot-v1')).version,2,'marker after verified migration');
 assert.equal((await store.loadDemoSnapshot()).workers.length,2,'reopen must not require a second migration');
 await assert.rejects(store.migrateFromVerifiedPortableBackup(backup,originalPassword),/ya está migrado/,'do not rerun');
 console.log('PASS: no auto-migration; verified matching backup gate; bad password/stale roster no writes; preserve old Keychain; reopen clinical AES vault.');
})().catch(error=>{console.error(error);process.exitCode=1});
