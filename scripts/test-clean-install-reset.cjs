const assert=require('node:assert/strict');
const fs=require('node:fs');
const ts=require('typescript'),vm=require('node:vm');

const source=fs.readFileSync('src/secureDemoStore.ts','utf8');
const compiled=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
function mock(){
 let native=true,folder=true,deny=false,clears=0,deleted=0;
 const secure=new Map([['prototype-snapshot-v1','old'],['workers-v1-file','old'],['workers-v1-aes-key','old']]);
 const legacy=new Map([['danper-etapa-a-demo-v1','[]'],['danper-etapa-a-demo-workers-v2','[]'],['danper-etapa-b0-stock-v010','[]']]);
 const localStorage={getItem:k=>legacy.get(k)??null,setItem:(k,v)=>legacy.set(k,v),removeItem:k=>legacy.delete(k)};
 const SecureStorage={
  async setKeyPrefix(prefix){assert.equal(prefix,'danper-local-v08_')},
  async setSynchronize(sync){assert.equal(sync,false)},
  async setDefaultKeychainAccess(){},
  async getItem(k){return secure.get(k)??null},
  async setItem(k,v){secure.set(k,v)},
  async clear(sync){assert.equal(sync,false);clears++;secure.clear()},
  async keys(sync){assert.equal(sync,false);return [...secure.keys()]}
 };
 const Filesystem={
  async stat({path,directory}){assert.equal(path,'danper');assert.equal(directory,'Data');if(deny)throw Error('Permission denied');if(!folder)throw Error('File does not exist');return {type:'directory'}},
  async rmdir({path,directory,recursive}){assert.equal(path,'danper');assert.equal(directory,'Data');assert.equal(recursive,true);if(deny)throw Error('Permission denied');deleted++;folder=false}
 };
 const module={exports:{}};
 const imported={
  '@aparajita/capacitor-secure-storage':{SecureStorage,KeychainAccess:{whenUnlockedThisDeviceOnly:1}},
  '@capacitor/core':{Capacitor:{isNativePlatform:()=>native,getPlatform:()=>native?'ios':'web'}},
  '@capacitor/filesystem':{Filesystem,Directory:{Data:'Data'}},
  './portableBackup':{decryptPortableBackup:async()=>{throw Error('Not expected')}},
  './privateClinicalVault':{loadClinicalVault:async()=>null,writeClinicalVault:async()=>{}},
  './privateWorkerVault':{workerVaultRecoveryRequired:()=>false,loadWorkerVault:async()=>null,writeWorkerVault:async()=>{},MissingWorkerVaultError:class extends Error{}}
 };
 vm.runInNewContext(compiled,{exports:module.exports,module,require:id=>{if(!(id in imported))throw Error(id);return imported[id]},localStorage,Error,JSON,Array,Object,Promise,Number,String},{filename:'secureDemoStore.js'});
 return{api:module.exports,secure,legacy,get folder(){return folder},get clears(){return clears},get deleted(){return deleted},set native(x){native=x},set deny(x){deny=x}};
}
(async()=>{
 const blocked=mock();blocked.native=false;
 await assert.rejects(blocked.api.resetDisposableLocalDatabase(),/solo está disponible/);
 assert.equal(blocked.clears,0);
 const denied=mock();denied.deny=true;
 await assert.rejects(denied.api.resetDisposableLocalDatabase(),/Permission denied/);
 assert.equal(denied.clears,0,'Keychain must not be cleared after an unsafe file deletion');
 const normal=mock();
 await normal.api.resetDisposableLocalDatabase();
 assert.equal(normal.folder,false);
 assert.equal(normal.deleted,1);
 assert.equal(normal.clears,1);
 assert.equal(normal.secure.size,0);
 assert.equal(normal.legacy.size,0);
 await assert.rejects(normal.api.writeDemoSnapshot(normal.api.emptyDemoSnapshot()),/Restablecimiento intencional/);
 const reinstalled=mock();reinstalled.secure.set('workers-v1-file','orphaned pointer');
 await reinstalled.api.resetDisposableLocalDatabase();
 assert.equal(reinstalled.secure.size,0,'stale Keychain pointers must not remain on a fresh install');
 // Product and official Excel assets are part of the package, not wiped snapshots.
 assert.equal(JSON.parse(fs.readFileSync('src/products.json','utf8')).length,432);
 assert.match(fs.readFileSync('src/kardexCatalog.ts','utf8'),/kardexMainCount=98/);
 assert.match(fs.readFileSync('src/reviewedKardexAssociations.ts','utf8'),/reviewedAssociations.length!==86/);
 assert.equal(JSON.parse(fs.readFileSync('src/ambulatoryTemplate.json','utf8')).sheets.length,10);
 assert.ok(fs.statSync('public/internal/kardex-template.bin').size>1500);
 console.log('PASS: limpieza local explícita, permiso denegado bloqueado, Keychain residual eliminado, escrituras inhibidas, 98/432/86 y plantillas de los 2 Excel preservados.');
})().catch(e=>{console.error(e);process.exitCode=1});
