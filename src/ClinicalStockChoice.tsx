import {type StockLedger} from './kardexMovements';
import {countPhysicalUnits} from './inventoryRules';
import {availableLots} from './attentionKardex';
import {reviewedAssociationsFor} from './reviewedKardexAssociations';
import {type InVisitPhysicalUse} from './automaticClinicalDispensing';
type Item={id:string;code:string;name:string;unit:string;quantity:number;physicalUse?:InVisitPhysicalUse};
type Props={item:Item;ledger:StockLedger;onChange:(v:InVisitPhysicalUse|undefined)=>void;locked?:boolean};

export function ClinicalStockChoice({item,ledger,onChange,locked=false}:Props){
 const associations=reviewedAssociationsFor(item.code).filter(x=>x.clinicalName===item.name&&x.clinicalUnit===item.unit);
 const allowed=[...new Set(associations.map(x=>x.kardexCode))];
 const unitCounted=['UND','TBL','PAR'].includes(item.unit.toUpperCase());
 const manualNeeded=!unitCounted||allowed.length>1;
 const eligible=ledger.lots.filter(l=>associations.some(a=>a.kardexCode===l.code&&a.kardexName===l.name)&&
   (!unitCounted||(item.unit.toUpperCase()==='PAR'?l.catalogUnit.toUpperCase()==='PAR':['UND','TBL'].includes(l.catalogUnit.toUpperCase()))));
 const groups=new Map<string,typeof eligible[number]>();
 // A dropdown entry represents a verified product *variant*, NOT a specific lot.
 for(const l of eligible){
  const best=availableLots(eligible,l.code).find(a=>a.name===l.name);
  if(best)groups.set(l.code+'|'+l.name,best);
 }
 const variants=[...groups.values()];
 const chosen=variants.find(l=>eligible.some(e=>e.id===item.physicalUse?.lotId&&e.code===l.code&&e.name===l.name));
 const autoVariant=variants.length===1?variants[0]:undefined;
 const choice=chosen||autoVariant;
 const stockForChoice=choice?eligible.filter(l=>l.code===choice.code&&l.name===choice.name):[];
 const total=stockForChoice.reduce((n,l)=>n+countPhysicalUnits(l),0);
 if(locked)return <p className="hint" role="status">Salida física ya vinculada al Kardex: no puede cambiarse desde esta atención.</p>;
 if(!allowed.length)return <p className="hint" role="status">Sin equivalencia de Kardex autorizada. El uso clínico se conserva, sin movimiento físico ficticio.</p>;
 if(!manualNeeded)return <p className="hint">FEFO automático: DANPER descontará primero el lote vigente más próximo a vencer y continuará con los siguientes. No necesitas elegir un lote.</p>;
 if(!variants.length)return <p className="hint" role="status">No hay inventario compatible y disponible. La atención se guarda, con salida física pendiente.</p>;
 return <div className="clinicalPhysicalChoice" aria-label={'Presentación utilizada de '+item.name}>
  <p className="hint">DANPER selecciona automáticamente los lotes por FEFO. Aquí solo identificas la presentación y la cantidad física realmente utilizada cuando el catálogo no la determina.</p>
  {variants.length>1&&<label>Presentación física usada
   <select value={chosen?.code||''} onChange={e=>{
    const variant=variants.find(l=>l.code===e.target.value);
    onChange(variant?{lotId:variant.id,quantity:unitCounted?item.quantity:0}:undefined);
   }}>
    <option value="">Presentación pendiente de identificar</option>
    {variants.map(l=><option key={l.code} value={l.code}>{l.name} · {l.code}</option>)}
   </select>
  </label>}
  {choice&&<><p className="hint">Existencia total disponible de esta presentación: {total} unidades físicas. El orden de salida se decidirá por vencimiento.</p>
   {!unitCounted&&<label>Cantidad física utilizada (unidades internas o mL según la ficha)
    <input type="number" inputMode="decimal" step="0.001" min="0" max="10000000"
     value={item.physicalUse?.quantity||''}
     onChange={e=>onChange({lotId:chosen?.id||autoVariant!.id,quantity:e.target.value===''?0:Number(e.target.value)})}
     aria-label={'Cantidad física utilizada de '+item.name}/>
   </label>}
   <p className="hint">No introduzcas el tamaño de toda la caja o frasco, sino la cantidad utilizada. Si no lo sabes, puedes guardar la atención con consumo pendiente y sin descuento.</p>
  </>}
 </div>;
}
