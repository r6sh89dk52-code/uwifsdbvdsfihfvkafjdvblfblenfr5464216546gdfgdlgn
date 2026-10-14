import {normalizeDni,type WorkerRecord} from './workerRules';

/**
 * Read-only reconciliation: never delete employees from a live store.
 * A current official PERSONAL workbook is a reference, not proof that
 * somebody absent is fictitious. This comparison is a mandatory preview.
 */
export type OfficialRosterReview={
 currentCount:number;
 officialCount:number;
 matchingDni:number;
 absentFromOfficial:number;
 eligibleForFurtherReview:number;
 protectedAbsent:number;
 protectedManual:number;
 protectedLinked:number;
 nameDiscrepancies:number;
 sampleUnmatched:Array<{dni:string;name:string}>;
};
function canonicalName(name:string){
 return name.normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim().replace(/\s+/g,' ').toLocaleUpperCase('es');
}
function validDni(row:WorkerRecord){
 if(normalizeDni(row.dni)!==row.dni||!row.name.trim())
  throw Error('Hay fichas sin DNI válido o nombre. No se hará ninguna comparación destructiva.');
}
export function reviewOfficialRoster(existing:WorkerRecord[],official:WorkerRecord[],linkedDnis:readonly string[]=[]):OfficialRosterReview{
 if(official.length===0)throw Error('La referencia PERSONAL oficial está vacía. No se comparará.');
 if(existing.length>30000||official.length>30000)throw Error('El padrón supera el límite de revisión.');
 const source=new Map<string,WorkerRecord>(),currentDnis=new Set<string>();
 for(const row of official){
  validDni(row);
  if(source.has(row.dni))throw Error('El Excel de referencia contiene DNI repetidos.');
  source.set(row.dni,row);
 }
 for(const row of existing){
  validDni(row);
  if(currentDnis.has(row.dni))throw Error('El padrón local contiene DNI repetidos; no se realizará la revisión.');
  currentDnis.add(row.dni);
 }
 const linked=new Set(linkedDnis.filter(x=>normalizeDni(x)===x));
 let matchingDni=0,absentFromOfficial=0,eligibleForFurtherReview=0,protectedAbsent=0,protectedManual=0,protectedLinked=0,nameDiscrepancies=0;
 const sampleUnmatched:Array<{dni:string;name:string}>=[];
 for(const row of existing){
  const incoming=source.get(row.dni);
  if(incoming){
   matchingDni++;
   if(canonicalName(row.name)!==canonicalName(incoming.name))nameDiscrepancies++;
   continue;
  }
  absentFromOfficial++;
  const manual=row.source!=='imported';
  const hasClinicalReferences=linked.has(row.dni);
  if(manual)protectedManual++;
  if(hasClinicalReferences)protectedLinked++;
  if(manual||hasClinicalReferences)protectedAbsent++;
  else eligibleForFurtherReview++;
  if(sampleUnmatched.length<10)sampleUnmatched.push({dni:row.dni,name:row.name});
 }
 return {currentCount:existing.length,officialCount:official.length,matchingDni,
  absentFromOfficial,eligibleForFurtherReview,protectedAbsent,protectedManual,
  protectedLinked,nameDiscrepancies,sampleUnmatched};
}
