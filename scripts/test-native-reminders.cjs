const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');

let platform='web',permission='denied';
const pending=new Map(),actions={cancel:[],schedule:[],check:0,request:0};
const LocalNotifications={
 async getPending(){return {notifications:[...pending.values()]};},
 async cancel({notifications}){actions.cancel.push(notifications.map(n=>n.id));for(const n of notifications)pending.delete(n.id);},
 async checkPermissions(){actions.check++;return {display:permission};},
 async requestPermissions(){actions.request++;return {display:permission};},
 async schedule({notifications}){actions.schedule.push(notifications);for(const n of notifications)pending.set(n.id,n);return {notifications};}
};
const Capacitor={getPlatform:()=>platform,isNativePlatform:()=>platform==='ios'};
const modules={};
function load(path){
 if(modules[path])return modules[path];
 const module={exports:{}};modules[path]=module.exports;
 const code=ts.transpileModule(fs.readFileSync(path,'utf8'),{
  fileName:path,reportDiagnostics:true,
  compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}
 });
 assert.equal((code.diagnostics||[]).filter(x=>x.category===ts.DiagnosticCategory.Error).length,0);
 vm.runInNewContext(code.outputText,{
  exports:module.exports,module,require:name=>{
   if(name==='@capacitor/core')return {Capacitor};
   if(name==='@capacitor/local-notifications')return {LocalNotifications};
   if(name==='./draftRules')return load('src/draftRules.ts');
   throw Error('unexpected module '+name);
  },Map,Number,String,Date,Promise
 },{filename:path});
 return module.exports;
}
const {syncNativeDraftNotifications,enableNativeNotifications,isNativeIOS}=load('src/nativeReminders.ts');
const {notificationId,reminderDueAt}=load('src/draftRules.ts');
const privacy=n=>{
 assert.equal(n.title,'DANPER Salud');
 assert.equal(n.body,'Tienes una atención pendiente por completar.');
 assert.equal(n.extra.kind,'danper-draft-reminder');
 assert(!/\b\d{8}\b/.test(JSON.stringify(n)),'no worker DNI in reminder payload');
};
(async()=>{
 const start=Date.now();
 assert.equal(isNativeIOS(),false);
 assert.equal(await enableNativeNotifications(),'not-native');
 await syncNativeDraftNotifications([{id:'unbilled',updatedAt:start}],true);
 assert.equal(actions.check,0);
 platform='ios';
 assert.equal(isNativeIOS(),true);
 assert.equal(await enableNativeNotifications(),'denied');
 assert.equal(actions.request,1);
 pending.set(800000001,{id:800000001});
 pending.set(75,{id:75,extra:{kind:'another-app-feature'}});
 await syncNativeDraftNotifications([{id:'draft-A',updatedAt:start}],true);
 assert.equal(pending.has(800000001),false);
 assert.equal(pending.has(75),true,'do not cancel other notifications');
 assert.equal(actions.schedule.length,0,'permission denial prevents scheduling');
 permission='granted';
 assert.equal(await enableNativeNotifications(),'granted');
 const a={id:'draft-A',updatedAt:start-12*60000};
 const b={id:'draft-B',updatedAt:start-36*60000};
 await syncNativeDraftNotifications([
  a,b,b,{id:'',updatedAt:start},{id:'bad-date',updatedAt:Number.NaN},
  {id:'old',updatedAt:start-7200000}
 ],true);
 assert.equal(actions.schedule.length,1);
 let planned=actions.schedule.at(-1);
 assert.equal(planned.length,2,'discard duplicate and expired items');
 assert.equal(planned[0].id,notificationId(b.id),'earliest reminder first');
 assert.equal(planned[1].id,notificationId(a.id));
 for(const n of planned){
  privacy(n);
  assert.equal(n.schedule.at.getTime(),reminderDueAt(n.id===notificationId(b.id)?b.updatedAt:a.updatedAt));
 }
 assert.equal(pending.has(75),true,'unrelated notification survives scheduling');
 const many=Array.from({length:90},(_,i)=>({id:'unique-draft-'+i,updatedAt:start-(90-i)*30000}));
 await syncNativeDraftNotifications(many,true);
 planned=actions.schedule.at(-1);
 assert.equal(planned.length,50,'iOS-friendly bound on pending notifications');
 assert(planned.every((n,i)=>i===0||planned[i-1].schedule.at<=n.schedule.at));
 assert.equal(new Set(planned.map(n=>n.id)).size,50);
 for(const n of planned)privacy(n);
 await Promise.all([
  syncNativeDraftNotifications([{id:'old-concurrent',updatedAt:start}],true),
  syncNativeDraftNotifications([{id:'latest-concurrent',updatedAt:start}],true)
 ]);
 assert.equal(pending.has(notificationId('latest-concurrent')),true);
 assert.equal(pending.has(notificationId('old-concurrent')),false,'serialization favors latest state');
 await syncNativeDraftNotifications([],false);
 assert.equal(pending.has(notificationId('latest-concurrent')),false);
 assert.equal(pending.has(75),true,'disable only cancels DANPER draft reminders');
 const app=fs.readFileSync('src/main.tsx','utf8');
 assert(app.includes("a.status==='draft'&&draftIsMeaningful(a)"),'never schedule empty drafts');
 assert(!app.includes('solo funcionarán en una futura compilación'),'iPhone help must describe current native reminders');
 console.log('PASS: native iOS reminder permission, privacy, 60min, latest-only queue, stale cleanup, 50 cap, empty draft exclusion, disable without touching others.');
})().catch(e=>{console.error(e);process.exitCode=1});
