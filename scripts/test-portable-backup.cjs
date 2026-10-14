const assert=require('node:assert/strict');
const vm=require('node:vm'),fs=require('node:fs'),ts=require('typescript');
const {webcrypto,randomUUID}=require('node:crypto');
const source=fs.readFileSync('src/portableBackup.ts','utf8');
const compiled=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
const exports={},module={exports};
vm.runInNewContext(compiled,{module,exports,crypto:{subtle:webcrypto.subtle,getRandomValues:a=>webcrypto.getRandomValues(a),randomUUID},TextEncoder,TextDecoder,Uint8Array,Promise,Date,Error,JSON,Object,Array,String,Number,ArrayBuffer,atob:s=>Buffer.from(s,'base64').toString('latin1'),btoa:s=>Buffer.from(s,'latin1').toString('base64')},{filename:'portableBackup.js'});
const {encryptPortableBackup,decryptPortableBackup}=module.exports;
(async()=>{
 const snapshot={
  attentions:Array.from({length:250},(_,i)=>({id:'A'+i,diagnosis:'DIAGNOSTICO DE PRUEBA'})),
  workers:Array.from({length:400},(_,i)=>({dni:String(10000000+i),name:'TRABAJADOR FICTICIO '+i})),
  allergies:{},notifications:false,stockLots:[{id:'TESTLOT',quantity:50}],stockMovements:[{id:'TESTMOVE',quantity:1}],
  catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]
 };
 const password='UnRespaldoFicticioSeguro2026!';
 const archive=await encryptPortableBackup(snapshot,password);
 assert.equal(JSON.parse(archive).version,1);
 assert.ok(!archive.includes('TRABAJADOR FICTICIO'),'backup must never leak names in plaintext');
 assert.ok(!archive.includes('DIAGNOSTICO DE PRUEBA'),'backup must never leak clinical data');
 const restored=await decryptPortableBackup(archive,password);
 assert.equal(JSON.stringify(restored),JSON.stringify(snapshot));
 await assert.rejects(decryptPortableBackup(archive,'ContraseñaEquivocada123'),/Contraseña incorrecta/);
 const obj=JSON.parse(archive);obj.data=obj.data.slice(0,10)+(obj.data[10]==='A'?'B':'A')+obj.data.slice(11);
 await assert.rejects(decryptPortableBackup(JSON.stringify(obj),password),/respaldo alterado/);
 const downgrade=JSON.parse(archive);downgrade.iterations=1;
 await assert.rejects(decryptPortableBackup(JSON.stringify(downgrade),password),/parámetros/);
 await assert.rejects(encryptPortableBackup(snapshot,'short'),/14/);
 console.log('PASS: AES-256-GCM portable backup round-trip, 400 synthetic workers, 250 visits, wrong password, tamper and KDF downgrade protection.');
})().catch(error=>{console.error(error);process.exitCode=1});
