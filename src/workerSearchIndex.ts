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

/** Zero-based pagination of the entire search, preserving the exact roster order.
 * Counts matches but keeps only 25 records per page in React's rendered list.
 */
export type WorkerPage<W>={workers:W[];total:number;page:number;pageCount:number;first:number;last:number};
export function paginateIndexedWorkers<W extends {dni:string;name:string}>(
 index:readonly IndexedWorker<W>[],rawQuery:string,page=0,pageSize=25
):WorkerPage<W>{
 const size=Number.isFinite(pageSize)?Math.max(1,Math.floor(pageSize)):25;
 const requested=Number.isFinite(page)?Math.max(0,Math.floor(page)):0;
 const query=normalizeName(rawQuery),dni=rawQuery.trim();
 const start=requested*size;
 let total=0;
 const visible:W[]=[];
 for(const {worker,normalizedName} of index){
  if(normalizedName.includes(query)||worker.dni.includes(dni)){
   if(total>=start&&total<start+size)visible.push(worker);
   total++;
  }
 }
 const pageCount=Math.ceil(total/size);
 const safePage=Math.min(requested,Math.max(pageCount-1,0));
 // Shrinking the imported roster must not produce an empty phantom page.
 if(safePage!==requested){
  let position=0;
  const fallback:W[]=[];
  for(const {worker,normalizedName} of index){
   if(normalizedName.includes(query)||worker.dni.includes(dni)){
    if(position>=safePage*size&&position<(safePage+1)*size)fallback.push(worker);
    position++;
   }
  }
  return {workers:fallback,total,page:safePage,pageCount,first:total?safePage*size+1:0,last:Math.min(total,(safePage+1)*size)};
 }
 return {workers:visible,total,page:safePage,pageCount,first:total?start+1:0,last:Math.min(total,start+size)};
}
