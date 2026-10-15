/**
 * UI-only, deterministic step validation for the experimental clinical wizard.
 * Do not infer diagnoses or modify the Excel/stock business rules.
 */
export type ClinicalStage = 0|1|2|3;
export type ClinicalFieldIssue={step:ClinicalStage;field:string;message:string};
export type ClinicalValidationInput={
  worker:{dni:string;name:string};date:string;time:string;category:string;system:string;
  segment:string;diagnosis:string;items:ReadonlyArray<{quantity:number;procedure:string}>;
  permission:string;permissionTime:string;
};
export type ClinicalValidationContext={
  validCategories:ReadonlyArray<string>;validSystems:ReadonlyArray<string>;
  rosterRequired:boolean;workerInRoster:boolean;rosterException:boolean;
  allergiesReviewed:boolean;allergyStatus:'unknown'|'none'|'known';allergySubstances:string;
};
export const SYSTEM_REQUIRED_CATEGORIES=['ENFERMEDAD','ACCIDENTE COMUN','ACCIDENTE DE TRABAJO','MATERNIDAD'] as const;
export function validClinicalDate(value:string):boolean{
  if(!/^\d{4}-\d{2}-\d{2}$/.test(value))return false;
  const [y,m,d]=value.split('-').map(Number);
  if(y<1900||y>2100||m<1||m>12||d<1||d>31)return false;
  const dt=new Date(Date.UTC(y,m-1,d));
  return dt.getUTCFullYear()===y&&dt.getUTCMonth()===m-1&&dt.getUTCDate()===d;
}
export function validClinicalTime(value:string):boolean{return /^([01]\d|2[0-3]):[0-5]\d$/.test(value)}
export function validateClinicalStage(step:ClinicalStage,a:ClinicalValidationInput,ctx:ClinicalValidationContext):ClinicalFieldIssue[]{
 const issues:ClinicalFieldIssue[]=[];
 const add=(field:string,message:string)=>issues.push({step,field,message});
 if(step===0){
   if(!/^\d{8}$/.test(a.worker.dni))add('worker-dni','Introduce un DNI válido de 8 dígitos.');
   if(!a.worker.name.trim())add('worker-name','Completa el nombre y apellidos del trabajador.');
   if(ctx.rosterRequired&&!ctx.workerInRoster&&!ctx.rosterException)add('worker-dni','El DNI no figura en el padrón oficial confirmado. Revisa el trabajador.');
 }
 if(step===1){
   if(!validClinicalDate(a.date))add('clinical-date','Selecciona una fecha válida.');
   if(!validClinicalTime(a.time))add('clinical-time','Indica una hora válida.');
   if(!a.category||!ctx.validCategories.includes(a.category)){
     add('clinical-category','Selecciona una categoría de atención: enfermedad, accidente u otra.');
   }else if(SYSTEM_REQUIRED_CATEGORIES.some(c=>c===a.category)){
     if(!a.system||!ctx.validSystems.includes(a.system))add('clinical-system','Selecciona el sistema afectado del catálogo oficial.');
     if(a.system==='OSTEOMUSCULAR'&&!a.segment.trim())add('clinical-segment','Especifica el segmento osteomuscular afectado.');
   }
   if(!a.diagnosis.trim())add('clinical-diagnosis','Escribe el diagnóstico presuntivo o comentario clínico.');
   if(!ctx.allergiesReviewed)add('allergy-status','Revisa el estado de alergias y selecciona una opción.');
   else if(ctx.allergyStatus==='known'&&!ctx.allergySubstances.trim())add('allergy-substances','Indica las sustancias o medicamentos reportados como alergias.');
 }
 if(step===2){
   a.items.forEach((item,index)=>{
     if(!Number.isInteger(item.quantity)||item.quantity<=0)add('treatment-items','Indica una cantidad mayor que cero para el producto '+(index+1)+'.');
     if(!item.procedure.trim())add('treatment-items','Selecciona el procedimiento del producto '+(index+1)+'.');
   });
 }
 if(step===3&&a.permission==='SI'&&!validClinicalTime(a.permissionTime)){
   add('result-permission-time','Confirma una hora válida para el permiso.');
 }
 return issues;
}
export function findFirstIncompleteStage(current:ClinicalStage,target:ClinicalStage,a:ClinicalValidationInput,ctx:ClinicalValidationContext):ClinicalFieldIssue[]{
 if(target<=current)return[];
 for(let i=current;i<target;i++){const issues=validateClinicalStage(i as ClinicalStage,a,ctx);if(issues.length)return issues;}
 return[];
}
export function findFirstInvalidStage(a:ClinicalValidationInput,ctx:ClinicalValidationContext):ClinicalFieldIssue[]{
 for(const step of [0,1,2,3] as const){const issues=validateClinicalStage(step,a,ctx);if(issues.length)return issues;}
 return[];
}
