/**
 * Simulates two fully separated iPhone sandboxes with REAL AES-GCM crypto:
 * different Keychains and encrypted private file containers. Never accesses
 * patient files, accounts, network, or a physical iPhone.
 */
const assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs'),ts=require('typescript');
const {webcrypto,randomUUID}=require('node:crypto');
function phone(){
 const keys=new Map(),files=new Map(),directories=new Set(),locals=new Map();
 let sabotageClinicalWrite=false;
 const SecureStorage={
  async setKeyPrefix(){},async setSynchronize(){},async setDefaultKeychainAccess(){},
  async getItem(key){return keys.get(key)??null},
  async setItem(key,value){keys.set(key,value)}
 };
 const Filesystem={
  async stat({path}){if(directories.has(path))return{type:'directory'};if(files.has(path))return{type:'file',size:files.get(path).length};throw Error('file does not exist')},
  async mkdir({path}){if(directories.has(path))throw Error('already exists, cannot be overwritten');directories.add(path)},
  async writeFile({path,data}){if(sabotageClinicalWrite&&path.startsWith('danper/clinical/'))throw Error('simulated disk failure');files.set(path,data)},
  async readFile({path}){if(!files.has(path))throw Error('file does not exist');return{data:files.get(path)}}
 };
 const localStorage={getItem:k=>locals.get(k)??null,setItem:(k,v)=>locals.set(k,v),removeItem:k=>locals.delete(k)};
 const cache=new Map();
 function imported(path){
  if(cache.has(path))return cache.get(path);
  const compiled=ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
  const box={exports:{}};cache.set(path,box.exports);
  const plugins={
   '@aparajita/capacitor-secure-storage':{SecureStorage,KeychainAccess:{whenUnlockedThisDeviceOnly:1}},
   '@capacitor/filesystem':{Filesystem,Directory:{Data:'DATA'},Encoding:{UTF8:'utf8'}},
   '@capacitor/core':{Capacitor:{isNativePlatform:()=>true,getPlatform:()=> 'ios'}}
  };
  const context={
   module:box,exports:box.exports,require:name=>{
    if(name in plugins)return plugins[name];
    if(name.startsWith('./'))return imported('src/'+name.slice(2)+'.ts');
    throw Error('missing dependency: '+name);
   },
   localStorage,JSON,Promise,Error,Array,Object,String,Number,Date,
   ArrayBuffer,Uint8Array,TextEncoder,TextDecoder,
   crypto:{subtle:webcrypto.subtle,getRandomValues:a=>webcrypto.getRandomValues(a),randomUUID},
   btoa:s=>Buffer.from(s,'latin1').toString('base64'),
   atob:s=>Buffer.from(s,'base64').toString('latin1')
  };
  vm.runInNewContext(compiled,context,{filename:path});
  return box.exports;
 }
 return {
  secure:imported('src/secureDemoStore.ts'),
  portable:imported('src/portableBackup.ts'),
  get keys(){return keys},
  get files(){return files},
  failClinicalWrites(value){sabotageClinicalWrite=value},
  simulateRestart(){cache.clear();return imported('src/secureDemoStore.ts')}
 };
}
(async()=>{
 const source=phone();
 const synthetic={
  workers:Array.from({length:350},(_,i)=>({dni:String(11000000+i),name:'EMPLEADO FICTICIO '+i,source:'imported',area:'SIMULADA'})),
  attentions:Array.from({length:120},(_,i)=>({id:'PRUEBA-'+i,worker:{dni:String(11000000+i%350)},diagnosis:'EJEMPLO DEMO'})),
  allergies:{'11000000':{status:'none',substances:'',updatedAt:100}},
  notifications:false,
  stockLots:[{id:'LOTE-PRUEBA',code:'E-01',quantity:33}],
  stockMovements:[{id:'MOV-PRUEBA',type:'OUT',quantity:2}],
  catalogMappings:[{product:'E-01',code:'AC-1'}],
  deliveryIncidents:[{id:'INC-PRUEBA'}],
  ambulatoryReconciliation:[{id:'RECON-PRUEBA'}]
 };
 await source.secure.writeDemoSnapshot(synthetic);
 const loaded=await source.secure.readStableSnapshotForBackup();
 assert.equal(JSON.stringify(loaded),JSON.stringify(synthetic),'source iPhone save and read');
 const password='ClaveFicticiaDemo2026%';
 const archive=await source.portable.encryptPortableBackup(loaded,password);
 assert(!archive.includes('EMPLEADO FICTICIO')&&!archive.includes('EJEMPLO DEMO'),'no plaintext in exported archive');
 const destination=phone();
 assert.equal(destination.keys.size,0,'other iPhone has no shared Keychain');
 assert.equal(destination.files.size,0,'other iPhone has no shared private files');
 await assert.rejects(destination.portable.decryptPortableBackup(archive,'ClaveIncorrectaDemo!'),/Contraseña incorrecta/);
 assert.equal(destination.keys.size,0,'wrong password cannot create keys or files');
 const restored=await destination.portable.decryptPortableBackup(archive,password);
 await destination.secure.restoreEmptyDeviceFromBackup(restored);
 const newData=await destination.secure.loadDemoSnapshot();
 assert.equal(JSON.stringify(newData),JSON.stringify(synthetic),'all clinical and inventory fields restored exactly');
 assert.notEqual(destination.keys.get('workers-v1-aes-key'),source.keys.get('workers-v1-aes-key'),'new device must generate different private worker key');
 assert.notEqual(destination.keys.get('clinical-v1-aes256-key'),source.keys.get('clinical-v1-aes256-key'),'new device must generate different clinical key');
 assert.equal(destination.keys.get('clinical-v1-portable-restore-pending'),'finished');
 const restarted=destination.simulateRestart();
 assert.equal(JSON.stringify(await restarted.loadDemoSnapshot()),JSON.stringify(synthetic),'restart re-opens restored snapshot');
 const beforePointer=destination.keys.get('clinical-v1-active-file');
 await assert.rejects(restarted.restoreEmptyDeviceFromBackup(restored),/Ya existen trabajadores/,'no replacing a populated iPhone');
 assert.equal(destination.keys.get('clinical-v1-active-file'),beforePointer);
 const anotherPhone=phone();
 anotherPhone.failClinicalWrites(true);
 await assert.rejects(anotherPhone.secure.restoreEmptyDeviceFromBackup(restored),/simulated disk failure/);
 assert.equal(anotherPhone.keys.get('workers-v1-file'),undefined,'do not activate roster on partial restore');
 assert.equal(anotherPhone.keys.get('clinical-v1-active-file'),undefined,'do not activate clinical state on partial restore');
 anotherPhone.failClinicalWrites(false);
 assert.equal((await anotherPhone.secure.loadDemoSnapshot()).workers.length,0);
 console.log('PASS: cross-iPhone REAL AES-GCM restore (350 fake staff,120 synthetic encounters,all inventory), different keys, reboot, incorrect password, no overwrite, interrupted write.');
})().catch(error=>{console.error(error);process.exitCode=1});
