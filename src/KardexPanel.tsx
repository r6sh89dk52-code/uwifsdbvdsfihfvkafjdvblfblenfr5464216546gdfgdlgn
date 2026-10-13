import {useMemo,useState} from 'react';
import {Check,ClipboardList,Package,Plus,Search,Trash2,X} from 'lucide-react';
import {kardexCatalog,kardexMainCount,kardexDonatedCount} from './kardexCatalog';
import {countPhysicalUnits,inventoryTotals,validateStockLot,type StockLot,type ContainerKind} from './inventoryRules';
import {type StockLedger} from './kardexMovements';import KardexMovementsPanel from './KardexMovementsPanel';
type Props={ledger:StockLedger;onChange:(value:StockLedger)=>void};
const options:{value:ContainerKind;label:string}[]=[
 {value:'unidad',label:'Unidad individual'},{value:'caja',label:'Caja'},
 {value:'frasco',label:'Frasco'},{value:'paquete',label:'Paquete'},
 {value:'blister',label:'Blíster'},{value:'otro',label:'Otro envase'}
];
const clean=(v:string)=>v.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('es').trim();
const safeNumber=(v:string)=>Number(v.replace(',','.'));
const fmt=(v:number)=>new Intl.NumberFormat('es-PE',{maximumFractionDigits:3}).format(v);
export default function KardexPanel({ledger,onChange}:Props){
 const lots=ledger.lots;
 const[search,setSearch]=useState('');
 const[filter,setFilter]=useState<'all'|'normal'|'donated'>('all');
 const[selectedId,setSelectedId]=useState('');
 const[editId,setEditId]=useState<string|null>(null);
 const[lot,setLot]=useState('');
 const[expires,setExpires]=useState('');
 const[container,setContainer]=useState<ContainerKind>('unidad');
 const[unit,setUnit]=useState<'UND'|'mL'|'g'>('UND');
 const[capacity,setCapacity]=useState('1');
 const[sealed,setSealed]=useState('0');
 const[loose,setLoose]=useState('0');
 const[opened,setOpened]=useState('0');
 const[problem,setProblem]=useState('');
 const selected=kardexCatalog.find(p=>p.id===selectedId);
 const listed=useMemo(()=>lots.filter(l=>{
   const p=kardexCatalog.find(x=>x.id===l.code);
   return (filter==='all'||(filter==='donated'?p?.donated:!p?.donated)) &&
     (!search||clean(l.name+' '+l.lot).includes(clean(search)));
 }).sort((a,b)=>a.name.localeCompare(b.name,'es')),[lots,search,filter]);
 const totals=inventoryTotals(lots);
 const preview=Number.isFinite(safeNumber(capacity)*safeNumber(sealed)+safeNumber(loose)+safeNumber(opened))
   ?safeNumber(capacity)*safeNumber(sealed)+safeNumber(loose)+safeNumber(opened):null;
 function reset(){
   setEditId(null);setSelectedId('');setLot('');setExpires('');
   setContainer('unidad');setUnit('UND');setCapacity('1');setSealed('0');setLoose('0');setOpened('0');setProblem('');
 }
 function startEdit(l:StockLot){
   if(ledger.movements.some(x=>x.lotId===l.id)){setProblem('Este lote ya tiene movimientos. Usa Ajuste auditado en lugar de editar su saldo inicial.');return}
   setEditId(l.id);setSelectedId(l.code);setLot(l.lot);setExpires(l.expires);
   setContainer(l.container);setUnit(l.catalogUnit==='mL'?'mL':l.catalogUnit==='g'?'g':'UND');
   setCapacity(String(l.unitsPerContainer));setSealed(String(l.sealedContainers));
   setLoose(String(l.looseUnits));setOpened(String(l.openedRemaining));setProblem('');
   document.getElementById('kardex-entry')?.scrollIntoView({behavior:'smooth',block:'start'});
 }
 function save(){
   try{
     if(!selected)throw Error('Selecciona un producto del Kardex oficial.');
     const raw={
       id:editId||crypto.randomUUID(),code:selected.id,name:selected.name,catalogUnit:unit,lot:lot.trim(),
       expires,container,unitsPerContainer:safeNumber(capacity),sealedContainers:safeNumber(sealed),
       looseUnits:safeNumber(loose),openedRemaining:safeNumber(opened),updatedAt:Date.now()
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
   <h2>Kardex de enfermería</h2>
   <p>Etapa B0 · Inventario inicial por lote</p>
  </div></div>
  <div className="warning">SOLO DATOS FICTICIOS. Los saldos deben contarse físicamente; el Excel histórico no representa el stock actual. Aún no hay descuento por atenciones ni exportación del Kardex diario.</div>
  <div className="kardexStats">
   <div><strong>{kardexMainCount}</strong><span>Productos oficiales</span></div>
   <div><strong>{kardexDonatedCount}</strong><span>Donados</span></div>
   <div><strong>{totals.lots}</strong><span>Lotes registrados</span></div>
  </div>
  <section className="panel" id="kardex-entry">
   <h3><Plus size={18}/>{editId?'Modificar recuento':'Registrar inventario inicial'}</h3>
   <p className="hint">Los 98 productos y los 6 donados proceden del formato de octubre de 2026. No se cargan cantidades automáticamente.</p>
   <label>Producto oficial
    <select value={selectedId} onChange={e=>{setSelectedId(e.target.value);setProblem('')}} disabled={Boolean(editId)}>
     <option value="">Seleccionar medicamento o insumo…</option>
     {['TABLETAS','AMPOLLAS','JERINGAS','INSUMOS','DONADOS'].map(group=><optgroup label={group} key={group}>
      {kardexCatalog.filter(p=>p.group===group).map(p=><option value={p.id} key={p.id}>{p.name}</option>)}
     </optgroup>)}
    </select>
   </label>
   {selected&&<p className="hint">Formato oficial: {selected.donated?'Donados, Hoja1':'KARDEX ENFERMERAS'} · fila {selected.sheetRow}. El número correlativo no es código de almacén.</p>}
   <div className="fields two">
    <label>Lote (opcional)<input value={lot} onChange={e=>setLot(e.target.value)} placeholder="Si no existe, dejar vacío" maxLength={48}/></label>
    <label>Vencimiento (si corresponde)<input type="date" value={expires} onChange={e=>setExpires(e.target.value)}/></label>
    <label>Presentación<select value={container} onChange={e=>setContainer(e.target.value as ContainerKind)}>{options.map(x=><option key={x.value} value={x.value}>{x.label}</option>)}</select></label>
    <label>Unidad de conteo<select value={unit} onChange={e=>setUnit(e.target.value as 'UND'|'mL'|'g')}><option>UND</option><option>mL</option><option>g</option></select></label>
    <label>Capacidad por envase<input inputMode="numeric" type="number" min="1" step="1" value={capacity} onChange={e=>setCapacity(e.target.value)}/></label>
    <label>Envases cerrados<input inputMode="numeric" type="number" min="0" step="1" value={sealed} onChange={e=>setSealed(e.target.value)}/></label>
    <label>Unidades sueltas<input inputMode="decimal" type="number" min="0" step="any" value={loose} onChange={e=>setLoose(e.target.value)}/></label>
    <label>Contenido abierto restante<input inputMode="decimal" type="number" min="0" step="any" value={opened} onChange={e=>setOpened(e.target.value)}/></label>
   </div>
   <p className="kardexPreview">Existencia física calculada: <strong>{preview===null?'—':fmt(preview)} {unit}</strong></p>
   <p className="hint">Ejemplo ficticio: frasco de 120 mL, 2 cerrados, 60 mL en uno abierto → 300 mL. El envase abierto no se cuenta también como cerrado.</p>
   {problem&&<p className="kardexError" role="alert">{problem}</p>}
   <div className="kardexActions"><button type="button" className="workerPrimary" onClick={save}><Check size={18}/>{editId?'Guardar cambio':'Agregar al inventario'}</button>{editId&&<button type="button" className="workerSecondary" onClick={reset}><X size={18}/>Cancelar</button>}</div>
  </section>
  <KardexMovementsPanel ledger={ledger} onChange={onChange}/>
  <section className="panel">
   <h3><ClipboardList size={18}/>Inventario registrado</h3>
   <div className="kardexFilter"><label className="kardexSearch"><Search size={18}/><input value={search} onChange={e=>setSearch(e.target.value)} placeholder="Buscar por nombre o lote…"/></label>
    <select value={filter} onChange={e=>setFilter(e.target.value as typeof filter)} aria-label="Tipo de inventario"><option value="all">Todos</option><option value="normal">Kardex enfermeras</option><option value="donated">Donados</option></select>
   </div>
   <p className="hint">{listed.length} registros · {totals.products} productos con recuento · {totals.expiring} lotes vencidos o próximos a vencer.</p>
   {listed.length===0?<p className="kardexEmpty">Aún no hay lotes registrados que coincidan con la búsqueda.</p>:<div className="kardexLots">
    {listed.map(l=><article key={l.id} className="kardexLot">
      <div className="kardexLotHeader"><strong>{l.name}</strong><span>{kardexCatalog.find(p=>p.id===l.code)?.donated?'Donado':'General'}</span></div>
      <p>{l.lot?'Lote '+l.lot:'Sin lote registrado'} · {l.expires?'Vence '+l.expires:'Vencimiento pendiente'}</p>
      <strong className="kardexBalance">{fmt(countPhysicalUnits(l))} {l.catalogUnit}</strong>
      <p>{l.sealedContainers} cerrados · {l.looseUnits} sueltos · {l.openedRemaining} abiertos restantes · capacidad {l.unitsPerContainer}</p>
      <div className="kardexActions">{ledger.movements.some(m=>m.lotId===l.id)?<span className="hint">Saldo bloqueado: modificar mediante ajuste auditado</span>:<><button className="workerSecondary" onClick={()=>startEdit(l)}>Editar</button><button className="workerSecondary" onClick={()=>remove(l)}><Trash2 size={16}/>Eliminar</button></>}</div>
    </article>)}
   </div>}
  </section>
 </div>
}
