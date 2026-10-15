// Stage B: pure clinical step guards and user-visible modal behavior (fictitious data only).
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const ts=require('typescript');
const src=fs.readFileSync('src/attentionStepValidation.ts','utf8');
const code=ts.transpileModule(src,{fileName:'attentionStepValidation.ts',reportDiagnostics:true,compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}); 
assert.equal((code.diagnostics||[]).filter(x=>x.category===ts.DiagnosticCategory.Error).length,0);
const exports={};
vm.runInNewContext(code.outputText,{exports});
const {validateClinicalStage,validClinicalDate,validClinicalTime,findFirstIncompleteStage,findFirstInvalidStage}=exports;
const sample=()=>({
 worker:{dni:'12345678',name:'PERSONA FICTICIA'},
 date:'2026-10-14',time:'18:30',
 category:'ENFERMEDAD',system:'RESPIRATORIO',segment:'',
 diagnosis:'CEFALEA DE PRUEBA',
 items:[],permission:'NO',permissionTime:''
});
const context=()=>({
 validCategories:['ENFERMEDAD','ACCIDENTE COMUN','ACCIDENTE DE TRABAJO','TOMA DE PRESIÓN ARTERIAL','MATERNIDAD','OTROS'],
 validSystems:['RESPIRATORIO','OSTEOMUSCULAR','CEFALEA','OTROS'],
 rosterRequired:true,workerInRoster:true,rosterException:false,
 allergiesReviewed:true,allergyStatus:'none',allergySubstances:''
});
const fields=(issues)=>Array.from(issues,x=>x.field);
const has=(issues,field)=>fields(issues).includes(field);
assert.deepEqual(fields(validateClinicalStage(0,sample(),context())),[]);
assert.deepEqual(fields(validateClinicalStage(1,sample(),context())),[]);
assert.deepEqual(fields(validateClinicalStage(2,sample(),context())),[]);
assert.deepEqual(fields(validateClinicalStage(3,sample(),context())),[]);
assert.deepEqual(fields(findFirstInvalidStage(sample(),context())),[]);
assert.deepEqual(fields(findFirstIncompleteStage(3,1,sample(),context())),[],'backwards navigation never blocked');
assert(validClinicalDate('2024-02-29'));assert(!validClinicalDate('2025-02-29'));
assert(!validClinicalDate('2026-02-31'));assert(!validClinicalDate('2026-13-01'));
assert(validClinicalTime('23:59'));assert(!validClinicalTime('24:00'));assert(!validClinicalTime('25:75'));
{
 const a=sample();a.worker.dni='123';a.worker.name='';
 const issues=validateClinicalStage(0,a,context());
 assert(has(issues,'worker-dni')&&has(issues,'worker-name'),'worker incomplete');
 assert.equal(findFirstIncompleteStage(0,3,a,context())[0].step,0);
}
{
 const ctx=context();ctx.workerInRoster=false;
 assert(has(validateClinicalStage(0,sample(),ctx),'worker-dni'),'official roster enforced');
 ctx.rosterException=true;
 assert(!has(validateClinicalStage(0,sample(),ctx),'worker-dni'),'existing confirmed edits preserved');
}
{
 const a=sample();a.category='';
 assert(has(validateClinicalStage(1,a,context()),'clinical-category'),'user must explicitly choose category');
 a.category='ENFERMEDAD';a.system='';
 assert(has(validateClinicalStage(1,a,context()),'clinical-system'),'system required when relevant');
 a.system='NO APLICA';
 assert(!has(validateClinicalStage(1,a,context()),'clinical-system'),'express not-applicable is allowed');
 a.category='ACCIDENTE COMUN';a.system='';
 assert(has(validateClinicalStage(1,a,context()),'clinical-system'),'accident requires system selection');
 a.category='TOMA DE PRESIÓN ARTERIAL';
 assert(!has(validateClinicalStage(1,a,context()),'clinical-system'),'non-relevant category has no system requirement');
 a.category='MATERNIDAD';a.system='OSTEOMUSCULAR';a.segment='';
 assert(has(validateClinicalStage(1,a,context()),'clinical-segment'),'osteo segment required');
 a.segment='COLUMNA';
 assert(!has(validateClinicalStage(1,a,context()),'clinical-segment'));
}
{
 const a=sample();a.diagnosis='   ';
 assert(has(validateClinicalStage(1,a,context()),'clinical-diagnosis'),'diagnosis required');
 a.diagnosis='CEFALEA';a.date='2026-02-30';a.time='28:00';
 assert(has(validateClinicalStage(1,a,context()),'clinical-date'));
 assert(has(validateClinicalStage(1,a,context()),'clinical-time'));
 const first=findFirstIncompleteStage(0,3,a,context());
 assert.equal(first[0].step,1,'skip ahead must not ignore invalid intermediate step');
}
{
 const ctx=context();ctx.allergiesReviewed=false;
 assert(has(validateClinicalStage(1,sample(),ctx),'allergy-status'),'patient allergy verification is explicit');
 ctx.allergiesReviewed=true;ctx.allergyStatus='known';
 assert(has(validateClinicalStage(1,sample(),ctx),'allergy-substances'),'documented allergy needs substance');
 ctx.allergySubstances='PENICILINA';
 assert(!has(validateClinicalStage(1,sample(),ctx),'allergy-substances'));
 ctx.allergyStatus='unknown';ctx.allergySubstances='';
 assert(!has(validateClinicalStage(1,sample(),ctx),'allergy-status'),'explicit unknown remains acceptable without misrepresenting absence');
}
{
 const a=sample();a.items=[{quantity:0,procedure:''},{quantity:1,procedure:'TRATAMIENTO ORAL'}];
 const issues=validateClinicalStage(2,a,context());
 assert.equal(issues.length,2);assert(has(issues,'treatment-items'));
 assert.equal(findFirstInvalidStage(a,context())[0].step,2);
 a.items[0]={quantity:1,procedure:'CURACION DE HERIDA'};
 assert.deepEqual(fields(findFirstInvalidStage(a,context())),[]);
}
{
 const a=sample();a.permission='SI';a.permissionTime='';
 assert(has(validateClinicalStage(3,a,context()),'result-permission-time'));
 a.permissionTime='19:04';assert.deepEqual(fields(validateClinicalStage(3,a,context())),[]);
}
const main=fs.readFileSync('src/main.tsx','utf8');
const css=fs.readFileSync('src/stageB.css','utf8');
for(const s of [
 "category:'',system:''",
 '<option value="" disabled>Seleccionar categoría...</option>',
 '<option value="" disabled>Seleccionar sistema...</option>',
 '<option value="NO APLICA">No aplica (selección expresa)</option>',
 'findFirstIncompleteStage(registerStep,step,active,clinicalValidationContext())',
 'raiseStepIssues(findFirstInvalidStage(active,clinicalValidationContext()))',
 'role="alertdialog" aria-modal="true"',
 'clinicalAlertDialog',
 'Corregir ahora',
 'clinicalReview',
 'data-clinical-field="clinical-diagnosis"',
 'data-clinical-field="clinical-system"'
])assert(main.includes(s),'required Stage B UI behavior: '+s);
for(const s of ['position:fixed','align-items:center','max-height','safe-area-inset-bottom','prefers-reduced-motion:reduce'])assert(css.includes(s),'responsive modal requirement: '+s);
console.log('PASS: Stage B 4-step gates, category/system/diagnosis, roster, allergies, dates, medication, permission, modal and clinical review.');
