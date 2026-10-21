/** Pure, read-only worker search index. No worker records are changed or stored here.
 * Normalization intentionally matches the pre-index Build 222 search semantics.
 */
export type IndexedWorker<W extends {dni:string;name:string}>={worker:W;normalizedName:string};
const normalizeName=(value:string)=>value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('es').trim();
export function buildWorkerSearchIndex<W extends {dni:string;name:string}>(workers:readonly W[]):IndexedWorker<W>[]{
 return workers.map(worker=>({worker,normalizedName:normalizeName(worker.name)}));
}
export function findIndexedWorkers<W extends {dni:string;name:string}>(
 index:readonly IndexedWorker<W>[],rawQuery:string,limit=25
):W[]{
 if(limit<=0)return [];
 const query=normalizeName(rawQuery),dni=rawQuery.trim();
 const found:W[]=[];
 for(const {worker,normalizedName} of index){
  if(normalizedName.includes(query)||worker.dni.includes(dni)){
   found.push(worker);
   if(found.length>=limit)break;
  }
 }
 return found;
}
