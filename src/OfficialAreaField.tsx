import React,{useMemo,useState} from 'react';
import {findOfficialArea,suggestOfficialAreas} from './organizationDirectory';
import {validDanperWorksite} from './danperWorksites';

type Props={value:string;site?:string;onChange:(text:string)=>void;className?:string};
export default function OfficialAreaField({value,site,onChange,className=''}:Props){
 const[focused,setFocused]=useState(false);

 const data=useMemo(()=>{
  try{return {choices:suggestOfficialAreas(site,value,5),match:findOfficialArea(site,value),failed:false}}
  catch{return {choices:[],match:undefined,failed:true}}
 },[site,value]);
 const{choices,match,failed}=data;
 const term=value.trim();
 return <div className={'officialAreaField '+className}>
  <label>Área
   <textarea rows={2} value={value} onFocus={()=>setFocused(true)}
    onBlur={()=>setFocused(false)}
    onChange={e=>onChange(e.target.value)}
    autoComplete="off" placeholder={site?'Escribe o busca tu área…':'Primero elige sede…'}
    aria-autocomplete="list" aria-expanded={focused&&choices.length>0}
    aria-label="Área del colaborador, permite texto libre"/>
  </label>
  {focused&&choices.length>0&&<div className="officialAreaSuggestions" role="listbox" aria-label="Áreas oficiales sugeridas">
   {choices.map(item=><button type="button" role="option" aria-selected={false} key={item.code}
    onPointerDown={e=>e.preventDefault()}
    onClick={()=>{onChange(item.area);setFocused(false)}}>
    <strong>{item.area}</strong><small>{item.code} · {item.group||'Unidad organizativa'}</small>
   </button>)}
  </div>}
  {term&&validDanperWorksite(site)&&!failed&&<p className={match?'officialAreaKnown':'officialAreaCustom'}>
   {match?<>Unidad organizativa oficial: <strong>{match.code}</strong>{match.group?' · Grupo: '+match.group:''}</>:
    'Área libre: se guardará tal como la escribiste. No se inventará un código organizativo.'}
  </p>}
  {failed&&<p className="officialAreaCustom">No se pudo consultar el catálogo oficial. Puedes registrar el área en texto libre; se revisará el código al exportar.</p>}
 </div>
}
