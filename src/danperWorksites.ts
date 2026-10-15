/** Official subdivisions included inside the 10-sheet DANPER workbook.
 * Site is an explicit verified choice; never infer it from a worker's job title.
 * UO and sub-UO codes require separate approved personnel-to-structure mapping.
 */
import workbook from './ambulatoryTemplate.json';
export const DANPER_WORKSITES = [
 {id:'LA VENTUROSA',label:'Fundo La Venturosa',code:'A071'},
 {id:'PLVENTUROSA',label:'Planta La Venturosa',code:'I031'}
] as const;
export type DanperWorksite=typeof DANPER_WORKSITES[number]['id'];
for(const site of DANPER_WORKSITES){
 const match=workbook.subdivisions.find(row=>row[0]===site.id&&row[1]===site.code);
 if(!match)throw Error('Sede no encontrada en plantilla oficial: '+site.id);
}
export function validDanperWorksite(v:unknown):v is DanperWorksite{
 return typeof v==='string'&&DANPER_WORKSITES.some(site=>site.id===v);
}
export function workerDetailsMissing(worker:{area:string;labor:string}):string[]{
 const missing:string[]=[];
 if(!worker.area?.trim())missing.push('Área');
 if(!worker.labor?.trim())missing.push('Labor o cargo');
 return missing;
}
