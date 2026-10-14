/** Search the 98 official nursing products without guessing clinical equivalences. */
export type KardexSearchOption={id:string;name:string;group?:string};
export function normalizeKardexQuery(s:string):string {
 return s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('es').trim().replace(/\s+/g,' ');
}
export function findKardexProducts<T extends KardexSearchOption>(options:T[],query:string,limit=8):T[]{
 const q=normalizeKardexQuery(query);
 if(!q)return options.slice(0,limit);
 const scored=options.map((p,i)=>({p,i,n:normalizeKardexQuery(p.name)}))
   .filter(x=>x.n.includes(q)||normalizeKardexQuery(x.p.id).includes(q))
   .sort((a,b)=>Number(b.n.startsWith(q))-Number(a.n.startsWith(q))||a.i-b.i);
 return scored.slice(0,limit).map(x=>x.p);
}
