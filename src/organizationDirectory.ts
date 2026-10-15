/** Lookup-only organizational directory from the verified, locally embedded
 * official XLSX. Never derive an organizational code from a job title.
 * Unknown/free-text areas remain valid for clinical registration.
 */
import source from './ambulatoryTemplate.json';
import {strFromU8} from 'fflate';
import {readAmbulatoryArchive} from './ambulatoryArchive';
import {DANPER_WORKSITES,validDanperWorksite} from './danperWorksites';

const NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
export type OfficialArea={area:string;code:string;group:string;management:string;society:string};
type OrganizationDirectory={areas:Record<string,OfficialArea[]>;societies:Record<string,string>};
let directory:OrganizationDirectory|null=null;
export function normalizeArea(input:string):string{
 return (input||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').trim().replace(/\s+/g,' ').toLocaleUpperCase('es');
}
function parse(xml:string):Document{
 if(/<!DOCTYPE|<!ENTITY/i.test(xml))throw Error('Catálogo organizativo con entidades incompatibles.');
 const doc=new DOMParser().parseFromString(xml,'application/xml');
 if(doc.getElementsByTagName('parsererror').length)throw Error('Catálogo organizativo XML inválido.');
 return doc;
}
function elements(parent:Document|Element,tag:string):Element[]{
 return Array.from(parent.getElementsByTagNameNS(NS,tag));
}
function columns(row:Element,shared:readonly string[]):Record<string,string>{
 const result:Record<string,string>={};
 for(const c of elements(row,'c')){
  const column=/^[A-Z]+/.exec(c.getAttribute('r')||'')?.[0]||'';
  if(!column)continue;
  const kind=c.getAttribute('t');
  const raw=elements(c,'v')[0]?.textContent||'';
  result[column]=kind==='s'?(shared[Number(raw)]||''):kind==='inlineStr'?
   elements(c,'t').map(t=>t.textContent||'').join(''):raw;
 }
 return result;
}
export function organizationDirectory():OrganizationDirectory{
 if(directory)return directory;
 const bytes=Uint8Array.from(atob(source.zipBase64),c=>c.charCodeAt(0));
 const parts=readAmbulatoryArchive(bytes,name=>[
  'xl/sharedStrings.xml','xl/worksheets/sheet8.xml','xl/worksheets/sheet10.xml'
 ].includes(name));
 const shared=parts['xl/sharedStrings.xml']?
  elements(parse(strFromU8(parts['xl/sharedStrings.xml'])),'si').map(si=>elements(si,'t').map(t=>t.textContent||'').join('')):[];
 const xml=(name:string)=>{const b=parts[name];if(!b)throw Error('La plantilla no conserva '+name);return parse(strFromU8(b))};
 const siteRows=elements(xml('xl/worksheets/sheet8.xml'),'row').map(row=>columns(row,shared));
 const unitRows=elements(xml('xl/worksheets/sheet10.xml'),'row').map(row=>columns(row,shared));
 const societies:Record<string,string>={},areas:Record<string,OfficialArea[]>={};
 for(const site of DANPER_WORKSITES){
  const matches=siteRows.filter(row=>row.A===site.id&&row.B===site.code);
  if(matches.length!==1||!/^\d{4}$/.test(matches[0].C||''))throw Error('Sociedad ambigua para sede '+site.id);
  societies[site.id]=matches[0].C;areas[site.id]=[];
  const seen=new Set<string>();
  for(const row of unitRows.filter(r=>r.A===societies[site.id]&&r.C&&/^\d{8}$/.test(r.E||''))){
   const normalized=normalizeArea(row.C);
   if(seen.has(normalized))throw Error('Unidad organizativa duplicada: '+normalized);
   seen.add(normalized);
   areas[site.id].push({society:row.A,area:row.C.trim(),code:row.E,
    group:(row.F||'').trim(),management:(row.G||'').trim()});
  }
  if(!areas[site.id].length)throw Error('No se encontró catálogo de áreas para '+site.id);
 }
 directory={areas,societies};
 return directory;
}
export function findOfficialArea(site:string|undefined,area:string):OfficialArea|undefined{
 if(!validDanperWorksite(site)||!normalizeArea(area))return undefined;
 return organizationDirectory().areas[site].find(row=>normalizeArea(row.area)===normalizeArea(area));
}
export function suggestOfficialAreas(site:string|undefined,term:string,limit=5):OfficialArea[]{
 if(!validDanperWorksite(site)||normalizeArea(term).length<2)return [];
 const query=normalizeArea(term);
 return organizationDirectory().areas[site].filter(row=>normalizeArea(row.area).includes(query))
  .sort((a,b)=>Number(!normalizeArea(a.area).startsWith(query))-Number(!normalizeArea(b.area).startsWith(query))
   ||a.area.localeCompare(b.area,'es')).slice(0,Math.max(0,Math.min(limit,6)));
}
