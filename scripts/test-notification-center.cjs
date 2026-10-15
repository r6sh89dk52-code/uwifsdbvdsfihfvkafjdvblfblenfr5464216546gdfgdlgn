const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');
function load(path,imports){
 const module={exports:{}};
 const js=ts.transpileModule(fs.readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
 vm.runInNewContext(js,{module,exports:module.exports,require:id=>{if(!(id in imports))throw Error('unexpected dependency '+id);return imports[id]},Date,Math,Number,String,Set,Map,Object,Array,Error,Promise,JSON},{filename:path});
 return module.exports;
}
const rules=load('src/draftRules.ts',{});
const inventory=load('src/inventoryRules.ts',{});
const center=load('src/notificationCenterRules.ts',{'./draftRules':rules,'./inventoryRules':inventory});
const at=new Date(2026,9,14,12).getTime();
const exp=(days)=>{const v=new Date(2026,9,14+days);return [v.getFullYear(),String(v.getMonth()+1).padStart(2,'0'),String(v.getDate()).padStart(2,'0')].join('-')};
const lot=(id,expires,units=3)=>({id,code:'E-01',name:'Producto de prueba',catalogUnit:'UND',lot:id,expires,container:'unidad',unitsPerContainer:1,sealedContainers:units,looseUnits:0,openedRemaining:0,updatedAt:at});
assert.equal(center.daysUntilExpiry(exp(0),at),0);
assert.equal(center.daysUntilExpiry(exp(7),at),7);
assert.equal(center.daysUntilExpiry(exp(-1),at),-1);
assert.equal(center.daysUntilExpiry('2026-02-30',at),null);
assert.equal(center.daysUntilExpiry('',at),null);
const attentions=[{id:'draft-a',status:'draft',updatedAt:at-3600001},{id:'saved-a',status:'saved',updatedAt:at-7200000},{id:'draft-fresh',status:'draft',updatedAt:at-300000}];
const lots=[lot('expired',exp(-2)),lot('soon',exp(6)),lot('near',exp(22)),lot('later',exp(45)),lot('empty',exp(-1),0),lot('invalid','not-a-date')];
let n=center.buildAppNotices(attentions,lots,at);
assert.equal(n.length,4);
assert.equal(n.filter(x=>x.kind==='draft').length,1);
assert.equal(n.filter(x=>x.kind==='expired').length,1);
assert.equal(n.filter(x=>x.kind==='expiry').length,2);
assert.equal(n[0].severity,'urgent');
assert.equal(n.some(x=>x.id==='expiry:empty'),false);
assert.ok(n.every(x=>!x.description.includes('DNI')&&!x.description.includes('Diagnóstico')));
assert.equal(center.expiryReminderAt(exp(6),at),null,'only upcoming 7-day advance reminder');
assert.ok(center.expiryReminderAt(exp(10),at)>at,'future seven-day notice planned');
assert.equal(center.expiryReminderAt('bad',at),null);
assert.ok(center.expiryNotificationId('2026-11-01')>=1700000000);
assert.ok(center.expiryNotificationId('2026-11-01')<2000000000);
let native=true,permission='granted',scheduled=[],canceled=[],pending=[],requestCount=0;
const LocalNotifications={
 async requestPermissions(){requestCount++;return{display:permission}},
 async checkPermissions(){return{display:permission}},
 async getPending(){return{notifications:pending}},
 async cancel({notifications}){canceled.push(...notifications);pending=pending.filter(n=>!notifications.some(x=>x.id===n.id))},
 async schedule({notifications}){scheduled.push(...notifications);pending.push(...notifications)}
};
const nativeModule=load('src/nativeReminders.ts',{
 '@capacitor/core':{Capacitor:{getPlatform:()=>native?'ios':'web',isNativePlatform:()=>native}},
 '@capacitor/local-notifications':{LocalNotifications},
 './draftRules':rules,'./notificationCenterRules':center,'./inventoryRules':inventory
});
const draftInputs=Array.from({length:40},(_,i)=>({id:'worker-private-id-'+i,updatedAt:Date.now()-10000}));
const expiryDate=exp(20);
const plan=nativeModule.planLocalNotifications({drafts:draftInputs,lots:[lot('x',expiryDate),lot('y',expiryDate)]});
assert.equal(plan.length,41,'40 drafts and one grouped expiry date');
const capPlan=nativeModule.planLocalNotifications({drafts:Array.from({length:90},(_,i)=>({id:'large-'+i,updatedAt:Date.now()})),lots:[]});
assert.equal(capPlan.length,center.LOCAL_NOTICE_LIMIT,'iOS pending cap must be respected');
assert.equal(plan.filter(x=>x.extra.kind==='danper-stock-expiry').length,1,'same expiry date grouped');
assert.ok(plan.every(x=>!x.title.includes('private-id')&&!x.body.includes('private-id')&&!x.body.includes('Producto')));
(async()=>{
 assert.equal(await nativeModule.enableNativeNotifications(),'granted');
 assert.equal(requestCount,1);
 await nativeModule.syncNativeNotifications({drafts:[{id:'x',updatedAt:Date.now()}],lots:[]},true);
 assert.equal(scheduled.length,1);
 assert.equal(scheduled[0].extra.kind,'danper-draft-reminder');
 assert.ok(!scheduled[0].body.includes('x'));
 await nativeModule.syncNativeNotifications({drafts:[],lots:[]},false);
 assert.ok(canceled.some(x=>x.id===scheduled[0].id));
 assert.equal(pending.length,0);
 const scheduledBefore=scheduled.length;
 native=false;
 await nativeModule.syncNativeNotifications({drafts:[{id:'new',updatedAt:Date.now()}],lots:[]},true);
 assert.equal(scheduled.length,scheduledBefore,'web can never create OS notifications');
 const ui=fs.readFileSync('src/main.tsx','utf8');
 assert.match(ui,/NotificationCenterPanel/);
 assert.match(ui,/syncNativeNotifications/);
 assert.match(ui,/notificationEnabled\?setNotificationEnabled\(false\)/);
 assert.match(ui,/notifications'\&\&/);
 const workflow=fs.readFileSync('.github/workflows/ios-ipa.yml','utf8');
 assert.match(workflow,/workflow_dispatch/);
 assert.doesNotMatch(workflow,/pull_request:/,'no automatic macOS from this notification PR');
 assert.doesNotMatch(workflow,/\bpush:/,'no automatic macOS on commit');
 console.log('PASS: local in-app warnings, expiry calendar, iOS OS notification scheduling (generic content), 56-cap, cancellation, offline permissions and no macOS CI.');
})().catch(err=>{console.error(err);process.exitCode=1});
