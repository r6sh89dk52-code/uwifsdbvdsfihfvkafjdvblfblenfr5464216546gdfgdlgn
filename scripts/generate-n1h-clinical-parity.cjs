'use strict';
const path=require('node:path'),fs=require('node:fs'),assert=require('node:assert/strict');
const {load}=require('./ambulatory-test-helpers.cjs');
const ts=load('src/attentionStepValidation.ts');
const dir=process.env.DANPER_N1_FIXTURE_DIR;
if(!dir||!path.isAbsolute(dir))throw Error('Use RUNNER_TEMP for synthetic fixtures');
const original={
 worker:{dni:'00000001',name:'PERSONA FICTICIA UNO'},
 date:'2026-10-16',time:'08:25',category:'ENFERMEDAD',
 system:'RESPIRATORIO',segment:'',diagnosis:'CEFALEA FICTICIA',
 items:[{quantity:2,procedure:'OBSERVACION'}],
 permission:'NO',permissionTime:''
};
const context={
 validCategories:['ENFERMEDAD','ACCIDENTE COMUN','ACCIDENTE DE TRABAJO','MATERNIDAD'],
 validSystems:['RESPIRATORIO','OSTEOMUSCULAR','DIGESTIVO'],
 rosterRequired:true,workerInRoster:true,rosterException:false,
 allergiesReviewed:true,allergyStatus:'none',allergySubstances:''
};
const clone=x=>structuredClone(x),samples=[];
function add(label,make){
 const form=clone(original),ctx=clone(context);
 make(form,ctx);
 const fields=[0,1,2,3].map(step=>ts.validateClinicalStage(step,form,ctx).map(x=>x.field));
 const first=fields.findIndex(x=>x.length>0);
 samples.push({label,form,context:ctx,expected:fields,first:first<0?null:first});
}
add('valid',()=>{});
add('invalidDniAndNoRoster',(a,c)=>{a.worker.dni='123';a.worker.name=' ';c.workerInRoster=false});
add('rosterException',(a,c)=>{c.workerInRoster=false;c.rosterException=true});
add('leapInvalid',(a,c)=>{a.date='2026-02-29';a.time='24:00'});
add('badDateChars',(a,c)=>{a.date='2026-13-40';a.time='15:62'});
add('allergyNotReviewed',(a,c)=>{c.allergiesReviewed=false;c.allergyStatus='unknown'});
add('allergyKnownEmpty',(a,c)=>{c.allergyStatus='known';c.allergySubstances='  '});
add('allergyKnownDocumented',(a,c)=>{c.allergyStatus='known';c.allergySubstances='SUSTANCIA FICTICIA'});
add('osteoNoSegment',(a,c)=>{a.system='OSTEOMUSCULAR';a.segment=''});
add('osteoWithSegment',(a,c)=>{a.system='OSTEOMUSCULAR';a.segment='BRAZO FICTICIO'});
add('unknownCategory',(a,c)=>{a.category='DESCONOCIDA';a.system=''});
add('missingSystem',(a,c)=>{a.system='';a.diagnosis=' '});
add('invalidItems',(a,c)=>{a.items=[{quantity:0,procedure:''},{quantity:1.5,procedure:''}]});
add('emptyItemsAllowed',(a,c)=>{a.items=[]});
add('permissionTimeBad',(a,c)=>{a.permission='SI';a.permissionTime='25:00'});
add('permissionTimeValid',(a,c)=>{a.permission='SI';a.permissionTime='11:20'});
assert.equal(samples.length,16);
const dest=path.join(dir,'n1h-ts-stage-parity.json');
fs.writeFileSync(dest,JSON.stringify(samples));
console.log('PASS N1h: TypeScript source-of-truth stage checks on',samples.length,'fictional scenarios');
