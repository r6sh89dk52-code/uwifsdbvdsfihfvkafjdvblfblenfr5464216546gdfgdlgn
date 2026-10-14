const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');
const source=fs.readFileSync('src/SafeExportPanel.tsx','utf8');
const transformed=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX},reportDiagnostics:true});
assert.equal(transformed.diagnostics.filter(x=>x.category===ts.DiagnosticCategory.Error).length,0);
const states=[];let cursor=0,decodeCount=0,modified=false,feedbackCount=0;
const useState=init=>{
 const index=cursor++;if(!(index in states))states[index]=init;
 return [states[index],next=>{states[index]=typeof next==='function'?next(states[index]):next}];
};
const jsx=(type,props)=>({type,props:props||{}});
const virtualExports={};const mod={exports:virtualExports};
const environment={
 module:mod,exports:virtualExports,
 require(name){
  if(name==='react')return{useState};
  if(name==='react/jsx-runtime')return{jsx,jsxs:jsx};
  if(name==='@capacitor/core')return{Capacitor:{isNativePlatform:()=>true,getPlatform:()=> 'ios'}};
  if(name==='@capacitor/share')return{Share:{async share(){throw Error('not used')}}};
  if(name==='./secureDemoStore')return{validateDemoSnapshot:x=>x};
  if(name==='./portableBackup')return{decryptPortableBackup:async(file,password)=>{
   decodeCount++;
   if(password!=='ClavePrivadaConfirmada2026')throw Error('Contraseña incorrecta o respaldo alterado.');
   assert.equal(file,'ARCHIVE-CIPHERTEXT');
   return {workers:[{dni:'00000001'}],attentions:[{id:'FICTICIA'}]};
  }};
  if(name==='./safeBackupFile')return{prepareEncryptedBackup:async()=>{modified=true;throw Error('must not prepare another backup')}};
  if(name==='./nativeHaptics')return{feedback:()=>feedbackCount++};
  throw Error('Unknown dependency: '+name);
 },JSON,Object,String,Promise,Date,Error,File:class {}
};
vm.runInNewContext(transformed.outputText,environment,{filename:'SafeExportPanel.js'});
const Panel=mod.exports.default;
function render(){cursor=0;return Panel()}
function findNodes(node,predicate){
 const result=[];
 function walk(current){
  if(Array.isArray(current)){current.forEach(walk);return}
  if(!current||typeof current!=='object')return;
  if('type'in current&&'props'in current){
   if(predicate(current))result.push(current);
   walk(current.props.children);
  }
 }
 walk(node);return result;
}
const nextTick=()=>new Promise(resolve=>setImmediate(resolve));
(async()=>{
 let v=render();
 const input=findNodes(v,n=>n.type==='input'&&n.props.type==='file');
 assert.equal(input.length,1,'one file input only in verify section');
 const payload={name:'DANPER-Respaldo-2026.danperbackup',size:625,text:async()=>'ARCHIVE-CIPHERTEXT'};
 input[0].props.onChange({currentTarget:{files:[payload],value:'selected'}});
 v=render();
 assert.ok(findNodes(v,n=>n.type==='p'&&JSON.stringify(n.props.children).includes('Seleccionado:')).length,'archive remains selected');
 const verifyButton=findNodes(v,n=>n.type==='button'&&n.props.children==='Verificar respaldo seleccionado')[0];
 verifyButton.props.onClick();
 await nextTick();
 v=render();
 assert.equal(decodeCount,0,'not decrypted without a password');
 assert.ok(findNodes(v,n=>n.props?.role==='alert').some(x=>String(x.props.children).includes('Introduce aquí')),'clear error next to action');
 let passInput=findNodes(v,n=>n.type==='input'&&n.props.placeholder==='Escribe la contraseña original del respaldo')[0];
 assert.ok(passInput,'independent password field is always visible');
 passInput.props.onChange({target:{value:'ClaveMalIngresada2026'}});
 v=render();
 findNodes(v,n=>n.type==='button'&&n.props.children==='Verificar respaldo seleccionado')[0].props.onClick();
 await nextTick();
 v=render();
 assert.equal(decodeCount,1);
 assert.ok(findNodes(v,n=>n.props?.role==='alert').some(x=>String(x.props.children).includes('Contraseña incorrecta')),'wrong password displayed');
 assert.ok(findNodes(v,n=>n.type==='p'&&JSON.stringify(n.props.children).includes('Seleccionado:')).length,'wrong password preserves selected archive');
 passInput=findNodes(v,n=>n.type==='input'&&n.props.placeholder==='Escribe la contraseña original del respaldo')[0];
 passInput.props.onChange({target:{value:'ClavePrivadaConfirmada2026'}});
 v=render();
 findNodes(v,n=>n.type==='button'&&n.props.children==='Verificar respaldo seleccionado')[0].props.onClick();
 await nextTick();
 v=render();
 assert.equal(decodeCount,2);
 assert.ok(findNodes(v,n=>n.props?.role==='status').some(x=>typeof x.props.children==='string'&&x.props.children.includes('Ningún dato fue restaurado')),'verify only');
 assert.equal(findNodes(v,n=>n.type==='input'&&n.props.placeholder==='Escribe la contraseña original del respaldo')[0].props.value,'','secret cleared on success');
 assert.equal(modified,false,'verify must never write/restore data');
 console.log('PASS: separate visible verification password; file-first selection; wrong password retry; valid verification; no restore or data writes.');
})().catch(e=>{console.error(e);process.exitCode=1});
