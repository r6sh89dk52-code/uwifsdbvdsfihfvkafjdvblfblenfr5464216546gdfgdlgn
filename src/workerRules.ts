/** No clinical records or real employee names are bundled in this module. */
export type WorkerRecord={dni:string;name:string;area:string;labor:string;sex:string;age:string;ubigeo:string;source?:'manual'|'imported'};
export type ImportStats={total:number;valid:number;invalidDni:number;withoutName:number;duplicates:number};
export type ImportResult={workers:WorkerRecord[];stats:ImportStats};
export type MergeStats={added:number;merged:number;manualPreserved:number};
export function normalizeDni(value:unknown):string{
  const v=String(value??'').trim().replace(/\.0$/,'');
  // Reject hyphens, scientific notation, and malformed values rather than guessing.
  return /^\d{8}$/.test(v)?v:'';
}
function clean(value:unknown):string{return String(value??'').trim().replace(/\s+/g,' ').slice(0,220)}
function pick(a:string,b:string):string{return a.trim()||b.trim()}
export function compileWorkers(rows:unknown[][]):ImportResult{
  if(!rows.length)throw Error('La hoja PERSONAL no contiene datos.');
  const header=rows[0].map(v=>clean(v).normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase());
  const get=(...names:string[])=>header.findIndex(v=>names.some(n=>v===n));
  const index={dni:get('DNI'),name:get('NOMBRES','APELLIDOS Y NOMBRES','NOMBRE COMPLETO'),manual:get('EDAD MANUAL','EDAD'),auto:get('EDAD AUTOMATIZADA'),sex:get('SEXO'),ubi:get('UBIGEO'),area:get('AREA'),labor:get('CARGO','LABOR','PUESTO')};
  if(index.dni<0||index.name<0)throw Error('PERSONAL debe tener encabezados DNI y NOMBRES. No se importó ningún trabajador.');
  const cell=(r:unknown[],i:number)=>i>=0?clean(r[i]):'';
  const result=new Map<string,WorkerRecord>();
  const stats:ImportStats={total:0,valid:0,invalidDni:0,withoutName:0,duplicates:0};
  for(const r of rows.slice(1)){
    if(r.every(v=>!clean(v)))continue;
    stats.total++;
    const dni=normalizeDni(cell(r,index.dni));
    if(!dni){stats.invalidDni++;continue}
    const name=cell(r,index.name);
    if(!name){stats.withoutName++;continue}
    const sex=cell(r,index.sex).toUpperCase();
    const ageRaw=cell(r,index.manual)||cell(r,index.auto);
    const ageNum=Number(ageRaw);
    const age=/^\d{1,3}$/.test(ageRaw)&&Number.isInteger(ageNum)&&ageNum<=120?ageRaw:'';
    const w:WorkerRecord={dni,name,area:cell(r,index.area),labor:cell(r,index.labor),sex:['M','F'].includes(sex)?sex:'',age,ubigeo:cell(r,index.ubi),source:'imported'};
    const previous=result.get(dni);
    if(previous){stats.duplicates++;result.set(dni,{...previous,area:pick(previous.area,w.area),labor:pick(previous.labor,w.labor),sex:pick(previous.sex,w.sex),age:pick(previous.age,w.age),ubigeo:pick(previous.ubigeo,w.ubigeo)});}
    else result.set(dni,w);
  }
  stats.valid=result.size;
  if(!stats.valid)throw Error('No se encontraron trabajadores válidos en PERSONAL.');
  if(stats.valid>30000)throw Error('La importación excede el límite de 30 000 trabajadores.');
  return {workers:[...result.values()],stats};
}
export function reconcileWorkers(existing:WorkerRecord[],incoming:WorkerRecord[]):{workers:WorkerRecord[];stats:MergeStats}{
 const result=new Map(existing.filter(w=>normalizeDni(w.dni)).map(w=>[w.dni,w]));
 const stats:MergeStats={added:0,merged:0,manualPreserved:0};
 for(const w of incoming){
   const old=result.get(w.dni);
   if(!old){result.set(w.dni,{...w,source:'imported'});stats.added++;continue}
   stats.merged++;
   if(old.source!=='imported'){
     stats.manualPreserved++;
     result.set(w.dni,{...w,...old,area:pick(old.area,w.area),labor:pick(old.labor,w.labor),sex:pick(old.sex,w.sex),age:pick(old.age,w.age),ubigeo:pick(old.ubigeo,w.ubigeo),source:'manual'});
   }else{
     result.set(w.dni,{...old,...w,name:pick(w.name,old.name),area:pick(w.area,old.area),labor:pick(w.labor,old.labor),sex:pick(w.sex,old.sex),age:pick(w.age,old.age),ubigeo:pick(w.ubigeo,old.ubigeo),source:'imported'});
   }
 }
 return {workers:[...result.values()],stats};
}
