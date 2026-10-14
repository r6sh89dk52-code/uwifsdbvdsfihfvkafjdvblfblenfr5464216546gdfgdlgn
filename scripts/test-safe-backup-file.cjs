const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');
const {webcrypto,randomUUID}=require('node:crypto');
function importedTs(file,imports){
 const src=fs.readFileSync(file,'utf8');
 const compiled=ts.transpileModule(src,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 const box={exports:{}};
 const scope={module:box,exports:box.exports,require:imports,Uint8Array,ArrayBuffer,TextEncoder,TextDecoder,JSON,Date,String,Array,Error,Promise,
  crypto:{subtle:webcrypto.subtle,getRandomValues:a=>webcrypto.getRandomValues(a),randomUUID},
  btoa:s=>Buffer.from(s,'latin1').toString('base64'),atob:s=>Buffer.from(s,'base64').toString('latin1')};
 vm.runInNewContext(compiled,scope,{filename:file});
 return box.exports;
}
const codec=importedTs('src/portableBackup.ts',name=>{throw Error(name)});
const snapshot={workers:[{dni:'12345678',name:'TRABAJADOR FICTICIO'}],attentions:[{id:'FICTICIA-1'}],allergies:{},notifications:false,
 stockLots:[],stockMovements:[],catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]};
const saved=new Map();let lookup=0,failStat=false,failUri=false;
const Filesystem={
 async writeFile({path,data,directory}){assert.equal(directory,'CACHE');saved.set(path,data);return {uri:'file:///cache/'+path}},
 async stat({path}){if(failStat)throw Error('stat inaccessible');return {type:'file',size:Buffer.from(saved.get(path),'base64').length}},
 async getUri({path}){if(failUri)return{uri:''};return{uri:'file:///cache/'+path}}
};
const unit=importedTs('src/safeBackupFile.ts',name=>{
 if(name==='@capacitor/filesystem')return {Filesystem,Directory:{Cache:'CACHE'}};
 if(name==='./secureDemoStore')return{readStableSnapshotForBackup:async()=>{lookup++;return snapshot},validateDemoSnapshot:x=>x};
 if(name==='./portableBackup')return codec;
 throw Error(name);
});
(async()=>{
 const steps=[];
 const one=await unit.prepareEncryptedBackup('ContraseñaDemoSegura2026!',x=>steps.push(x));
 assert.equal(steps.length,4);
 assert.equal(lookup,1);
 assert.ok(one.name.endsWith('.danperbackup'));
 assert.ok(one.uri.startsWith('file:///cache/'));
 const raw=Buffer.from(saved.get(one.name),'base64').toString('utf8');
 assert.ok(raw.includes('AES-256-GCM'));
 assert.ok(!raw.includes('TRABAJADOR FICTICIO'),'no plaintext in saved file');
 const restored=await codec.decryptPortableBackup(raw,'ContraseñaDemoSegura2026!');
 assert.equal(JSON.stringify(restored),JSON.stringify(snapshot));
 const two=await unit.prepareEncryptedBackup('ContraseñaDemoSegura2026!',()=>{});
 assert.notEqual(one.name,two.name,'two backups on one day must not overwrite');
 failStat=true;
 await assert.rejects(unit.prepareEncryptedBackup('ContraseñaDemoSegura2026!',()=>{}),/stat inaccessible/);
 failStat=false;failUri=true;
 await assert.rejects(unit.prepareEncryptedBackup('ContraseñaDemoSegura2026!',()=>{}),/ruta local válida/);
 const ui=fs.readFileSync('src/SafeExportPanel.tsx','utf8');
 assert.ok(ui.includes("onClick={()=>void sharePrepared()}"),'must share on a separate direct iOS tap');
 assert.ok(ui.includes("onClick={()=>void prepare()}"),'prepare tap visibly checks and reports password issues');
 assert.ok(ui.includes("role=\"alert\""),'errors must be visible');
 assert.ok(!ui.includes("disabled={!native||busy||secret.length<14"),'button must not silently disable on password length');
 console.log('PASS: iPhone backup prepared/verified, two separate direct taps, visible validation, unique files and failed stat/URI detected.');
})().catch(e=>{console.error(e);process.exitCode=1});
