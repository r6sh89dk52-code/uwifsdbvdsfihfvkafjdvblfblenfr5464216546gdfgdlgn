import {useMemo,useState} from 'react';
import {Check,ClipboardList,Package,Plus,Search,Trash2,X} from 'lucide-react';
import {kardexCatalog,kardexMainCount} from './kardexCatalog';
import {countPhysicalUnits,inventoryTotals,validateStockLot,type StockLot,type ContainerKind} from './inventoryRules';
import {isIndividualNursingProduct,formatDateInput,parseDateInput,isoToDateInput} from './kardexEntryRules';
import {type StockLedger} from './kardexMovements';import {type CatalogMappingEvent} from './reconciliationRules';import KardexProductSearch from './KardexProductSearch';import './stockReconciliationInfo.css';
type Props={ledger:StockLedger;mappings:CatalogMappingEvent[];onChange:(value:StockLedger)=>void;responsible:string;onOpenIndicator:()=>void};
const options:{value:ContainerKind;label:string}[]=[
 {value:'unidad',label:'Unidad individual'},{value:'caja',label:'Caja'},
 {value:'frasco',label:'Frasco'},{value:'paquete',label:'Paquete'},
 {value:'blister',label:'Blíster'},{value:'otro',label:'Otro envase'}
];
const clean=(v:string)=>v.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('es').trim();
const safeNumber=(v:string)=>Number(v.replace(',','.'));
const fmt=(v:number)=>new Intl.NumberFormat('es-PE',{maximumFractionDigits:3}).format(v);
export default function KardexPanel({ledger,onChange,onOpenIndicator}:Props){
 const lots=ledger.lots;
 const[search,setSearch]=useState('');
 const[entryOpen,setEntryOpen]=useState(lots.length===0);
 const[selectedId,setSelectedId]=useState('');
 const[editId,setEditId]=useState<string|null>(null);
 const[lot,setLot]=useState('');
 const[expires,setExpires]=useState(''); // digits are displayed DD/MM/AAAA; storage remains ISO
 const[entryMode,setEntryMode]=useState<'individual'|'packed'>('individual');
 const[quantity,setQuantity]=useState('0');
 const[container,setContainer]=useState<ContainerKind>('unidad');
 const[unit,setUnit]=useState<'UND'|'mL'|'g'>('UND');
 const[capacity,setCapacity]=useState('1');
 const[sealed,setSealed]=useState('0');
 const[loose,setLoose]=useState('0');
 const[opened,setOpened]=useState('0');
 const[problem,setProblem]=useState('');
 const selected=kardexCatalog.find(p=>p.id===selectedId);
 const legacyPack=Boolean(editId&&selected&&(container!=='unidad'||unit!=='UND'||capacity!=='1'||sealed!=='0'||opened!=='0'));
 const packed=Boolean(selected&&entryMode==='packed');
 const forcedIndividual=Boolean(selected&&isIndividualNursingProduct(selected)&&!legacyPack);
 const listed=useMemo(()=>lots.filter(l=>{
   const p=kardexCatalog.find(x=>x.id===l.code);
   return Boolean(p) &&
     (!search||clean(l.name+' '+l.lot).includes(clean(search)));
 }).sort((a,b)=>a.name.localeCompare(b.name,'es')),[lots,search]);
 const totals=inventoryTotals(lots.filter(x=>kardexCatalog.some(p=>p.id===x.code)));
 const preview=packed
   ?(Number.isFinite(safeNumber(capacity)*safeNumber(sealed)+safeNumber(loose)+safeNumber(opened))?safeNumber(capacity)*safeNumber(sealed)+safeNumber(loose)+safeNumber(opened):null)
   :(quantity.trim()!==''&&Number.isFinite(safeNumber(quantity))?safeNumber(quantity):null);
 function chooseProduct(id:string){
   setSelectedId(id);setProblem('');
   if(!editId){setEntryMode('individual');setQuantity('0');setContainer('unidad');setUnit('UND');setCapacity('1');setSealed('0');setLoose('0');setOpened('0');setExpires('');setLot('')}
 }
 function reset(){
   setEditId(null);setSelectedId('');setLot('');setExpires('');
   setContainer('unidad');setUnit('UND');setCapacity('1');setSealed('0');setLoose('0');setOpened('0');setEntryMode('individual');setQuantity('0');setProblem('');
 }
 function startEdit(l:StockLot){
   if(ledger.movements.some(x=>x.lotId===l.id)){setProblem('Este lote ya tiene movimientos. Usa Ajuste auditado en lugar de editar su saldo inicial.');return}
   setEntryOpen(true);
   setEditId(l.id);setSelectedId(l.code);setLot(l.lot);setExpires(isoToDateInput(l.expires));
   const hasPackaging=l.container!=='unidad'||l.catalogUnit!=='UND'||l.unitsPerContainer!==1||l.sealedContainers>0||l.openedRemaining>0;
   setEntryMode(hasPackaging?'packed':'individual');setQuantity(String(countPhysicalUnits(l)));
   setContainer(l.container);setUnit(l.catalogUnit==='mL'?'mL':l.catalogUnit==='g'?'g':'UND');
   setCapacity(String(l.unitsPerContainer));setSealed(String(l.sealedContainers));
   setLoose(String(l.looseUnits));setOpened(String(l.openedRemaining));setProblem('');
   window.requestAnimationFrame(()=>document.getElementById('kardex-entry')?.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'}));
 }
 function save(){
   try{
     if(!selected)throw Error('Selecciona un producto del Kardex oficial.');
     if(expires.trim()&&!parseDateInput(expires))throw Error('Vencimiento inválido. Escribe DD/MM/AAAA, por ejemplo 12102026.');
     if(!packed&&(!Number.isInteger(safeNumber(quantity))||safeNumber(quantity)<0))throw Error('La cantidad de unidades debe ser un entero no negativo.');
     const raw={
       id:editId||crypto.randomUUID(),code:selected.id,name:selected.name,catalogUnit:packed?unit:'UND',lot:lot.trim(),
       expires:expires.trim()?parseDateInput(expires):'',container:packed?container:'unidad',unitsPerContainer:packed?safeNumber(capacity):1,sealedContainers:packed?safeNumber(sealed):0,
       looseUnits:packed?safeNumber(loose):safeNumber(quantity),openedRemaining:packed?safeNumber(opened):0,updatedAt:Date.now()
     };
     const entry=validateStockLot(raw);
     if(lots.some(x=>x.id!==entry.id&&x.code===entry.code&&x.lot.toLowerCase()===entry.lot.toLowerCase()&&x.expires===entry.expires))
       throw Error('Este producto, lote y vencimiento ya están registrados. Edita ese registro para ajustar el recuento.');
     if(editId&&ledger.movements.some(m=>m.lotId===editId))throw Error('Lote con movimientos: registra un ajuste auditado.');
     onChange({...ledger,lots:editId?lots.map(x=>x.id===editId?entry:x):[...lots,entry]});reset();
   }catch(error){setProblem(error instanceof Error?error.message:'No fue posible validar el inventario.')}
 }
 function remove(l:StockLot){
   if(ledger.movements.some(m=>m.lotId===l.id)){setProblem('No se puede eliminar un lote con movimientos auditados.');return}
   if(!window.confirm('¿Eliminar el registro ficticio de '+l.name+'?'))return;
   onChange({...ledger,lots:lots.filter(x=>x.id!==l.id)});
   if(editId===l.id)reset();
 }
 return <div className="kardexPage">
  <div className="kardexIntro"><Package/><div>
   <h2>Inventario de enfermería</h2>
   <p>Registro de existencias físicas por producto y lote</p>
  </div></div>
  <div className="warning">SOLO DATOS FICTICIOS. Aquí se registra la existencia física del Kardex. El Indicador Ambulatorio tiene además un corte por fecha y subdivisión: se debe conciliar con estos productos, sin duplicar ni inventar saldos.</div>
  <div className="kardexLinkingInfo"><strong>Dos libros, un stock físico para conciliar</strong><p>El Kardex refleja existencias reales por lote. El Indicador Ambulatorio exige stocks iniciales por fecha, subdivisión y unidad oficial para 432 materiales. En las 86 correspondencias aprobadas, verifica la igualdad del mismo material y fecha de corte; por seguridad no se copian cantidades entre ambos libros sin esa conciliación.</p><button type="button" className="workerSecondary" onClick={onOpenIndicator}>Abrir conciliación del Indicador</button></div>
  <div className="kardexStats">
   <div><strong>{kardexMainCount}</strong><span>Productos oficiales</span></div>
   <div><strong>{totals.lots}</strong><span>Lotes registrados</span></div>
  </div>
  <section className="panel kardexEntryCard" id="kardex-entry">
   <div className="kardexEntryHeading"><h3><Plus size={18}/>{editId?'Modificar recuento':'Registrar existencias'}</h3><button type="button" className="kardexEntryToggle" aria-expanded={entryOpen} aria-controls="kardex-entry-form" onClick={()=>setEntryOpen(v=>!v)}>{entryOpen?'Ocultar formulario':'Abrir formulario'}</button></div>
   {!entryOpen&&<p className="hint">Elige «Abrir formulario» para registrar o modificar existencias, conservando los datos que ya escribiste.</p>}
   <div id="kardex-entry-form" className="kardexEntryBody" hidden={!entryOpen}>
   <p className="hint">Los 98 materiales de Enfermería se conservan sin donados; el saldo inicial no informado queda pendiente.</p>
   <KardexProductSearch label="Producto oficial" value={selectedId} onChange={chooseProduct} products={kardexCatalog} disabled={Boolean(editId)}/>
   {selected&&<p className="hint">Formato oficial: {'KARDEX ENFERMERAS'} · fila {selected.sheetRow}. El número correlativo no es código de almacén.</p>}
   {selected&&<>
    <div className="kardexEntryBasics">
     <label>Lote (opcional)<input value={lot} onChange={e=>setLot(e.target.value)} placeholder="Si no existe, dejar vacío" maxLength={48}/></label>
     <label>Vencimiento (si corresponde)
      <input type="text" inputMode="numeric" pattern="[0-9/]*" maxLength={10} autoComplete="off" value={expires}
       onChange={e=>setExpires(formatDateInput(e.target.value))} placeholder="DD/MM/AAAA · escribe 12102026" aria-label="Vencimiento, día mes y año, solo números"/>
     </label>
     {!forcedIndividual&&!legacyPack&&<div className="kardexModeChoice" role="group" aria-label="Forma de control">
      <button type="button" className={!packed?'selected':''} onClick={()=>setEntryMode('individual')}>Unidades individuales</button>
      <button type="button" className={packed?'selected':''} onClick={()=>setEntryMode('packed')}>Envase / contenido</button>
     </div>}
     {forcedIndividual&&!legacyPack&&<p className="hint">Se cuenta por unidad individual. No necesitas configurar presentación, mililitros, cajas ni envases.</p>}
     {legacyPack&&<p className="hint">Este lote ya utiliza control por envases. Se conserva su forma de conteo para no modificar las existencias guardadas.</p>}
     {!packed?<label>Cantidad disponible (unidades)
        <input type="number" inputMode="numeric" step="1" min="0" value={quantity} onChange={e=>setQuantity(e.target.value)}/>
       </label>:<div className="kardexPackaging">
       <label>Presentación<select value={container} onChange={e=>setContainer(e.target.value as ContainerKind)}>{options.map(x=><option key={x.value} value={x.value}>{x.label}</option>)}</select></label>
       <label>Unidad de contenido<select value={unit} onChange={e=>setUnit(e.target.value as 'UND'|'mL'|'g')}><option>UND</option><option>mL</option><option>g</option></select></label>
       <label>Capacidad por envase<input inputMode="numeric" type="number" min="1" step="1" value={capacity} onChange={e=>setCapacity(e.target.value)}/></label>
       <label>Envases cerrados<input inputMode="numeric" type="number" min="0" step="1" value={sealed} onChange={e=>setSealed(e.target.value)}/></label>
       <label>Contenido adicional suelto<input inputMode="decimal" type="number" min="0" step="any" value={loose} onChange={e=>setLoose(e.target.value)}/></label>
       <label>Contenido abierto restante<input inputMode="decimal" type="number" min="0" step="any" value={opened} onChange={e=>setOpened(e.target.value)}/></label>
      </div>}
    </div>
    <p className="kardexPreview">Existencia física calculada: <strong>{preview===null?'—':fmt(preview)} {packed?unit:'UND'}</strong></p>
    {packed&&<p className="hint">Ejemplo ficticio: frasco de 120 mL, 2 cerrados y 60 mL abiertos = 300 mL. No cuentes el mismo envase dos veces.</p>}
   </>}
   {problem&&<p className="kardexError" role="alert">{problem}</p>}
   <div className="kardexActions"><button type="button" className="workerPrimary" onClick={save}><Check size={18}/>{editId?'Guardar cambio':'Agregar al inventario'}</button>{editId&&<button type="button" className="workerSecondary" onClick={reset}><X size={18}/>Cancelar</button>}</div>
   </div>
  </section>
  <section className="panel kardexInventoryList">
   <h3><ClipboardList size={18}/>Inventario registrado</h3>
   <div className="kardexFilter"><label className="kardexSearch"><Search size={18}/><input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Buscar por nombre o lote…"/></label>
   </div>
   <p className="hint">{listed.length} registros · {totals.products} productos con recuento · {totals.expiring} lotes vencidos o próximos a vencer.</p>
   {listed.length===0?<p className="kardexEmpty">Aún no hay lotes registrados que coincidan con la búsqueda.</p>:<div className="kardexLots">
    {listed.map(l=><article key={l.id} className="kardexLot">
      <div className="kardexLotHeader"><strong>{l.name}</strong><span>{'Enfermería'}</span></div>
      <p>{l.lot?'Lote '+l.lot:'Sin lote registrado'} · {l.expires?'Vence '+l.expires:'Vencimiento pendiente'}</p>
      <strong className="kardexBalance">{fmt(countPhysicalUnits(l))} {l.catalogUnit}</strong>
      <p>{l.container==='unidad'&&l.unitsPerContainer===1&&l.sealedContainers===0&&l.openedRemaining===0?'Unidades individuales: '+fmt(l.looseUnits):l.sealedContainers+' cerrados · '+fmt(l.looseUnits)+' sueltos · '+fmt(l.openedRemaining)+' abiertos · capacidad '+l.unitsPerContainer}</p>
      <div className="kardexActions">{ledger.movements.some(m=>m.lotId===l.id)?<span className="hint">Saldo bloqueado: modificar mediante ajuste auditado</span>:<><button className="workerSecondary" onClick={()=>startEdit(l)}>Editar</button><button className="workerSecondary" onClick={()=>remove(l)}><Trash2 size={16}/>Eliminar</button></>}</div>
    </article>)}
   </div>}
  </section>
 </div>
}
