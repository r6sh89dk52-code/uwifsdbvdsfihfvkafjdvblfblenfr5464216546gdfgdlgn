const assert=require('node:assert/strict');
const ts=require('typescript'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('src/nativeHaptics.ts','utf8');
const compiled=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
let native=true,platform='ios',fail=false;const calls=[],prefs=new Map();
const context={module:{exports:{}},exports:null,
 require(name){
  if(name==='@capacitor/core')return{Capacitor:{isNativePlatform:()=>native,getPlatform:()=>platform}};
  if(name==='@capacitor/haptics')return{
   ImpactStyle:{Light:'LIGHT'},NotificationType:{Success:'SUCCESS',Warning:'WARNING',Error:'ERROR'},
   Haptics:{
    async impact(v){if(fail)throw Error('unsupported');calls.push(['impact',v.style])},
    async selectionChanged(){if(fail)throw Error('unsupported');calls.push(['selection'])},
    async notification(v){if(fail)throw Error('unsupported');calls.push(['notification',v.type])}
   }
  };
  throw Error('unknown '+name);
 },
 localStorage:{getItem:k=>prefs.get(k)??null,setItem:(k,v)=>prefs.set(k,v)},
 Promise,Error,String
};
context.exports=context.module.exports;
vm.runInNewContext(compiled,context,{filename:'nativeHaptics.js'});
const h=context.module.exports;
(async()=>{
 await h.hapticFeedback('tap');await h.hapticFeedback('selection');
 await h.hapticFeedback('warning');await h.hapticFeedback('success');await h.hapticFeedback('error');
 assert.deepEqual(calls,[['impact','LIGHT'],['selection'],['notification','WARNING'],['notification','SUCCESS'],['notification','ERROR']]);
 h.setHapticsEnabled(false);await h.hapticFeedback('success');assert.equal(calls.length,5);
 h.setHapticsEnabled(true);native=false;await h.hapticFeedback('tap');assert.equal(calls.length,5);
 native=true;platform='android';await h.hapticFeedback('tap');assert.equal(calls.length,5);
 platform='ios';fail=true;await h.hapticFeedback('success');assert.equal(calls.length,5,'haptics failures cannot break persistence');
 console.log('PASS: iOS native haptics events, disabled preference, no web/android events, safe failure.');
})().catch(e=>{console.error(e);process.exitCode=1});
