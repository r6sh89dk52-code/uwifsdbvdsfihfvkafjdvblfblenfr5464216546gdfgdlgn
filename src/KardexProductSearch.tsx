import {useEffect,useId,useState} from 'react';
import {Search} from 'lucide-react';
import {findKardexProducts,type KardexSearchOption} from './kardexProductSearchRules';
type Props={label:string;value:string;onChange:(id:string)=>void;products:KardexSearchOption[];disabled?:boolean;placeholder?:string};
export default function KardexProductSearch({label,value,onChange,products,disabled=false,placeholder='Escribe el nombre del producto…'}:Props){
 const inputId=useId(),listId=useId();
 const current=products.find(p=>p.id===value);
 const [query,setQuery]=useState(current?.name||'');
 const [open,setOpen]=useState(false);
 const [active,setActive]=useState(0);
 useEffect(()=>{setQuery(current?.name||'')},[value,current?.name]);
 const matches=findKardexProducts(products,query,8);
 function choose(p:KardexSearchOption){onChange(p.id);setQuery(p.name);setOpen(false);setActive(0)}
 return <div className="kardexPicker">
  <label htmlFor={inputId}>{label}</label>
  <div className="kardexPickerInput"><Search size={19} aria-hidden="true"/>
   <input id={inputId} role="combobox" aria-autocomplete="list" aria-controls={listId} aria-expanded={open&&matches.length>0}
    autoComplete="off" disabled={disabled} value={query} placeholder={placeholder}
    onChange={e=>{setQuery(e.target.value);setOpen(true);setActive(0);if(value)onChange('')}}
    onFocus={()=>setOpen(true)}
    onBlur={()=>{window.setTimeout(()=>setOpen(false),120)}}
    onKeyDown={e=>{
      if(e.key==='Escape'){setOpen(false);return}
      if(e.key==='ArrowDown'){e.preventDefault();setOpen(true);setActive(i=>Math.min(i+1,matches.length-1))}
      if(e.key==='ArrowUp'){e.preventDefault();setOpen(true);setActive(i=>Math.max(0,i-1))}
      if(e.key==='Enter'&&open&&matches.length){e.preventDefault();choose(matches[active]||matches[0])}
    }}/>
  </div>
  {open&&matches.length>0&&<div className="kardexSuggestions" id={listId} role="listbox">
   {matches.map((p,i)=><button type="button" role="option" aria-selected={i===active} className={i===active?'selected':''}
      onPointerDown={e=>e.preventDefault()} onClick={()=>choose(p)} key={p.id}>
     <span>{p.name}</span><small>{p.group||'Kardex de Enfermería'}</small>
   </button>)}
  </div>}
  {open&&query.trim()&&matches.length===0&&<p className="hint">No existen coincidencias en el catálogo oficial.</p>}
 </div>;
}
