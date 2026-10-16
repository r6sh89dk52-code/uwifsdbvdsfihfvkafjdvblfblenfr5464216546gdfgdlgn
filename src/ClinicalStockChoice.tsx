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
 const candidates=eligible.filter(l=>availableLots(eligible,l.code).some(x=>x.id===l.id));
 const selected=candidates.find(x=>x.id===item.physicalUse?.lotId);
 if(locked)return <p className="hint" role="status">Salida física vinculada a Kardex: no puede cambiarse desde esta atención.</p>;
 if(!allowed.length)return <p className="hint" role="status">Sin equivalencia física autorizada. La atención se guarda, pero no se inventará un movimiento.</p>;
 if(!manualNeeded){
  return <p className="hint">Descuento automático desde el inventario disponible, según FEFO. Si falta saldo, la atención quedará registrada y se informará la diferencia.</p>;
 }
 if(!candidates.length)return <p className="hint" role="status">Sin existencias verificables para esta presentación. El consumo se guardará como pendiente, sin descontar saldos inexistentes.</p>;
 return <div className="clinicalPhysicalChoice" aria-label={'Existencia utilizada de '+item.name}>
  <p className="hint">Datos físicos de esta atención (opcional si todavía no se conocen). Al pulsar Guardar se descuenta directamente; no se vuelve a confirmar en Kardex.</p>
  <label>Existencia o presentación utilizada
   <select value={selected?.id||''} onChange={e=>{
    const id=e.target.value;
    if(!id){onChange(undefined);return}
    const lot=candidates.find(l=>l.id===id);
    if(!lot)return;
    onChange({lotId:id,quantity:unitCounted?item.quantity:0});
   }}>
    <option value="">Sin identificar (consumo clínico pendiente)</option>
    {candidates.map(l=><option key={l.id} value={l.id}>{l.name} · {l.lot?'lote '+l.lot:'lote no identificado'} · {countPhysicalUnits(l)} unidades internas disponibles</option>)}
   </select>
  </label>
  {selected&&<><label>Cantidad física utilizada {unitCounted?'(unidades)':'(unidades internas o mL, según la ficha del producto)'}
   <input type="number" inputMode="decimal" step={unitCounted?'1':'0.001'} min="0" max="10000000"
    value={item.physicalUse?.quantity||''} onChange={e=>onChange({lotId:selected.id,quantity:e.target.value===''?0:Number(e.target.value)})}
    aria-label={'Cantidad física utilizada de '+item.name} />
  </label>
  <p className="hint">Indica lo realmente utilizado, no la cantidad que contiene una caja o frasco completo. Las aperturas se calculan con el remanente registrado. Si el dato no es seguro, selecciona «Sin identificar».</p></>}
 </div>;
}
