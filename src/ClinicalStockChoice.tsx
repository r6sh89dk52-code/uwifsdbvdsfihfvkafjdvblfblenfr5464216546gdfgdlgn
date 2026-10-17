import {useEffect,useState} from 'react';
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
 const choice=chosen||(allowed.length===1?autoVariant:undefined);
 const stockForChoice=choice?eligible.filter(l=>l.code===choice.code&&l.name===choice.name&&
   availableLots(eligible,l.code).some(x=>x.id===l.id)):[];
 const total=stockForChoice.reduce((n,l)=>n+countPhysicalUnits(l),0);
 const [remembered,setRemembered]=useState('');
 const packagedStock=stockForChoice.some(l=>l.sealedContainers>0&&(l.container!=='unidad'||l.unitsPerContainer>1));
 const preferenceKey=choice?'DANPER-CONSUMO-INTERNO-V1:'+item.code+':'+choice.code+':'+choice.name+':'+choice.catalogUnit+':'+choice.unitsPerContainer:'';
 // Only a user-confirmed, product/presentation/capacity-specific nonpatient
 // preference is remembered. Changing presentation/capacity never carries it over.
 useEffect(()=>{
  if(locked||unitCounted||!choice||item.physicalUse||!preferenceKey)return;
  try{
   const n=Number(window.localStorage.getItem(preferenceKey));
   if(Number.isFinite(n)&&n>0&&n<=choice.unitsPerContainer){
    onChange({lotId:choice.id,quantity:n,confirmNewContainer:false});
   }
  }catch{/* Storage unavailable; user enters actual physical consumption. */}
 },[locked,unitCounted,choice?.id,choice?.unitsPerContainer,item.physicalUse,preferenceKey,onChange]);
 const confirmOpening=(checked:boolean)=>{
  if(!choice)return;
  onChange({lotId:chosen?.id||choice.id,
   quantity:unitCounted?item.quantity:(item.physicalUse?.quantity||0),confirmNewContainer:checked});
 };
 if(locked)return <p className="hint" role="status">Salida física ya vinculada al Kardex: no puede cambiarse desde esta atención.</p>;
 if(!allowed.length)return <p className="hint" role="status">Sin equivalencia de Kardex autorizada. El uso clínico se conserva, sin movimiento físico ficticio.</p>;
 if(!manualNeeded)return <div className="clinicalPhysicalChoice">
  <p className="hint">FEFO automático: el medicamento individual se descuenta al guardar la atención, sin una segunda confirmación.</p>
  {packagedStock&&choice&&<label><input type="checkbox"
   checked={item.physicalUse?.confirmNewContainer===true}
   onChange={e=>confirmOpening(e.target.checked)}/>
   Autorizo abrir una caja nueva únicamente si no alcanza el contenido abierto (FEFO). De otro modo se conserva pendiente.</label>}
 </div>;
 if(!variants.length)return <p className="hint" role="status">No hay inventario compatible y disponible. La atención se guarda, con salida física pendiente.</p>;
 return <div className="clinicalPhysicalChoice" aria-label={'Presentación utilizada de '+item.name}>
  <p className="hint">DANPER selecciona automáticamente los lotes por FEFO. Aquí solo identificas la presentación y la cantidad física realmente utilizada cuando el catálogo no la determina.</p>
  {(variants.length>1||allowed.length>1)&&<label>Presentación física usada
   <select value={chosen?.code||''} onChange={e=>{
    const variant=variants.find(l=>l.code===e.target.value);
    onChange(variant?{lotId:variant.id,quantity:unitCounted?item.quantity:0,confirmNewContainer:false}:undefined);
   }}>
    <option value="">Presentación pendiente de identificar</option>
    {variants.map(l=><option key={l.code} value={l.code}>{l.name} · {l.code}</option>)}
   </select>
  </label>}
  {choice&&<><p className="hint">Existencia total disponible de esta presentación: {total} unidades físicas. El orden de salida se decidirá por vencimiento.</p>
   {!unitCounted&&<label>Cantidad física utilizada (unidades internas o mL según la ficha)
    <input type="number" inputMode="decimal" step="0.001" min="0" max="10000000"
     value={item.physicalUse?.quantity||''}
     onChange={e=>onChange({lotId:chosen?.id||autoVariant!.id,quantity:e.target.value===''?0:Number(e.target.value),confirmNewContainer:item.physicalUse?.confirmNewContainer===true})}
     aria-label={'Cantidad física utilizada de '+item.name}/>
   </label>}
   {!unitCounted&&<button type="button" disabled={!item.physicalUse||!(item.physicalUse.quantity>0)}
    onClick={()=>{
     if(!choice||!item.physicalUse||!(item.physicalUse.quantity>0))return;
     try{
      window.localStorage.setItem(preferenceKey,String(item.physicalUse.quantity));
      setRemembered('Cantidad interna guardada para esta presentación y capacidad. Podrás corregirla en cualquier atención.');
     }catch{setRemembered('No fue posible recordar la cantidad. Introduce el consumo en la próxima atención.')}
    }}>Recordar esta cantidad interna para futuras atenciones</button>}
   {remembered&&<p className="hint" role="status">{remembered}</p>}
   {packagedStock&&<label><input type="checkbox"
    checked={item.physicalUse?.confirmNewContainer===true}
    onChange={e=>confirmOpening(e.target.checked)}/>
    Autorizo abrir un nuevo frasco o caja si el contenido abierto no alcanza. La apertura solo se descuenta una vez; los usos siguientes marcan 0.</label>}
   <p className="hint">Introduce el consumo físico real por atención (p. ej., 1 mL solo si ese volumen es el utilizado y está verificado). Un frasco de 100 mL permite 100 usos únicamente a 1 mL por uso. Sin cantidad verificada o permiso de apertura, el consumo clínico se guarda pendiente, sin alterar existencias.</p>
  </>}
 </div>;
}
