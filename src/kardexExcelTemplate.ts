/** Preserve the ORIGINAL 2026 nurse Kardex OOXML sheets, styles, merged cells,
 * borders, print configuration and printer settings. Replace data cells only.
 */
import {unzipSync,zipSync,strFromU8,strToU8} from 'fflate';
import {type DailyReport} from './dailyKardex';
const NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
function nodeName(n:Element){return n.localName}
function elements(node:Node):Element[]{return Array.from(node.childNodes).filter((x):x is Element=>x.nodeType===1)}
function cell(root:Document,address:string){
 const ref=address.match(/^([A-Z]+)(\d+)$/);
 if(!ref)throw Error('Celda del formato no reconocida.');
 const data=root.getElementsByTagNameNS(NS,'sheetData')[0];
 const index=Number(ref[2]);let row=elements(data).find(x=>nodeName(x)==='row'&&Number(x.getAttribute('r'))===index);
 if(!row){row=root.createElementNS(NS,'row');row.setAttribute('r',String(index));data.appendChild(row)}
 let c=elements(row).find(x=>nodeName(x)==='c'&&x.getAttribute('r')===address);
 if(!c){
  c=root.createElementNS(NS,'c');c.setAttribute('r',address);
  const colNum=(s:string)=>s.split('').reduce((n,k)=>n*26+k.charCodeAt(0)-64,0);
  const pos=colNum(ref[1]);
  const next=elements(row).find(x=>{
   const a=x.getAttribute('r')?.match(/^([A-Z]+)/);
   return a?colNum(a[1])>pos:false
  });
  if(next)row.insertBefore(c,next);else row.appendChild(c);
 }
 return c;
}
function clear(cell:Element){for(const n of elements(cell))if(['v','f','is'].includes(nodeName(n)))n.parentNode?.removeChild(n);cell.removeAttribute('t')}
function setNum(root:Document,addr:string,value:number|null,formula?:string){
 const c=cell(root,addr);clear(c);
 if(value===null)return;
 if(!Number.isFinite(value))throw Error('Cantidad inválida '+addr);
 if(formula){const f=root.createElementNS(NS,'f');f.textContent=formula;c.appendChild(f)}
 const v=root.createElementNS(NS,'v');v.textContent=String(value);c.appendChild(v);
}
function setText(root:Document,addr:string,value:string){
 const c=cell(root,addr);clear(c);
 c.setAttribute('t','inlineStr');
 const is=root.createElementNS(NS,'is'),t=root.createElementNS(NS,'t');
 t.setAttribute('xml:space','preserve');t.textContent=value;is.appendChild(t);c.appendChild(is);
}
function decode(bytes:Uint8Array){return new DOMParser().parseFromString(strFromU8(bytes), 'application/xml')}
function encode(doc:Document){return strToU8(new XMLSerializer().serializeToString(doc))}
function ensure(source:Document,tab:string){
 const values=Array.from(source.getElementsByTagNameNS(NS,'sheet')).map(x=>x.getAttribute('name'));
 if(!values.includes(tab))throw Error('La plantilla no contiene la hoja oficial '+tab+'.');
}
export function exportOfficialKardex(template:Uint8Array,report:DailyReport,shift:string,responsible:string):Uint8Array{
 if(!report.exportable)throw Error('El reporte contiene observaciones sin conciliar. Revísalas antes de exportar.');
 if(!['MAÑANA','TARDE','NOCHE'].includes(shift))throw Error('Elige un turno válido.');
 if(!responsible.trim())throw Error('Indica el responsable del registro.');
 let zip:Record<string,Uint8Array>;
 try{zip=unzipSync(template)}catch{throw Error('Selecciona un archivo .xlsx válido.')}
 const files=['xl/workbook.xml','xl/worksheets/sheet1.xml','xl/worksheets/sheet2.xml','xl/styles.xml','xl/sharedStrings.xml'];
 if(files.filter((_,i)=>i!==1).some(x=>!zip[x]))throw Error('La plantilla no contiene los componentes esperados.');
 const workbook=decode(zip[files[0]]),regular=decode(zip[files[2]]);
 const strings=decode(zip['xl/sharedStrings.xml']);
 const sharedStrings=Array.from(strings.getElementsByTagNameNS(NS,'si')).map(si=>si.textContent||'');
 const label=(doc:Document,ref:string)=>{
  const c=Array.from(doc.getElementsByTagNameNS(NS,'c')).find(x=>x.getAttribute('r')===ref);
  if(!c)return '';
  const value=c.getElementsByTagNameNS(NS,'v')[0]?.textContent||'';
  return c.getAttribute('t')==='s'?sharedStrings[Number(value)]||'':c.textContent||'';
 };
 // Avoid silently placing stock data in a different workbook with similar tab names.
 if(!label(regular,'C7').includes('AERO-OM')||!label(regular,'C104').includes('REPELENTE'))
  throw Error('La plantilla no coincide con el Kardex oficial de octubre de 2026.');
 // Only the original main sheet survives the export, preserving its XML
 // styles/merges/print layout/printer settings.
 ensure(workbook,'KARDEX ENFERMERAS');
 if(!report.rows||report.rows.length!==98||report.rows.some(r=>r.donated))
  throw Error('Reporte incompleto: deben figurar exactamente 98 productos generales sin donados.');
 // Verify original title and product cells before changing stock.
 const generalTitle=regular.getElementsByTagNameNS(NS,'sheetData')[0];
 if(!generalTitle||!regular.getElementsByTagNameNS(NS,'mergeCells').length)throw Error('No corresponde al formato original.');
 const dd=report.date.split('-').reverse().join('/');
 setText(regular,'A3','TURNO: '+shift);
 setText(regular,'A4','RESPONSABLE: '+responsible.trim());
 setText(regular,'I3','FECHA: '+dd);
 report.rows.filter(r=>!r.donated).forEach((r,i)=>{
  const row=i+7;
  setNum(regular,'D'+row,r.stockKnown?r.initial:null);
  setNum(regular,'E'+row,r.stockKnown?r.extraordinary:null);
  setNum(regular,'F'+row,r.stockKnown?r.total:null,r.stockKnown?'D'+row+'+E'+row:undefined);
  setNum(regular,'G'+row,r.stockKnown?r.consumed:null);
  setNum(regular,'H'+row,r.stockKnown?r.final:null,r.stockKnown?'F'+row+'-G'+row:undefined);
  if(r.expiry)setText(regular,'I'+row,r.expiry);else setNum(regular,'I'+row,null);
  setNum(regular,'J'+row,r.fs);
 });
 // Remove the donation worksheet and all its direct package references.
 const MAIN='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
 const RELS='http://schemas.openxmlformats.org/package/2006/relationships';
 const sheets=Array.from(workbook.getElementsByTagNameNS(MAIN,'sheet'));
 for(const item of sheets)if(item.getAttribute('name')==='Hoja1')item.parentNode?.removeChild(item);
 const views=workbook.getElementsByTagNameNS(MAIN,'workbookView');
 for(const view of Array.from(views))view.setAttribute('activeTab','0');
 if(workbook.getElementsByTagNameNS(MAIN,'sheet').length!==1)throw Error('La exportación debe contener solo la hoja KARDEX ENFERMERAS.');
 const relationships=decode(zip['xl/_rels/workbook.xml.rels']);
 for(const rel of Array.from(relationships.getElementsByTagNameNS(RELS,'Relationship'))){
  if(rel.getAttribute('Id')==='rId1')rel.parentNode?.removeChild(rel);
 }
 zip['xl/_rels/workbook.xml.rels']=encode(relationships);
 const types=decode(zip['[Content_Types].xml']);
 for(const node of elements(types.documentElement)){
  if(node.getAttribute('PartName')==='/xl/worksheets/sheet1.xml')node.parentNode?.removeChild(node);
 }
 zip['[Content_Types].xml']=encode(types);
 delete zip['xl/worksheets/sheet1.xml'];
 delete zip['xl/worksheets/_rels/sheet1.xml.rels'];
 delete zip['xl/printerSettings/printerSettings1.bin'];
 // Remove unused shared-string entries, including all donor-only names.
 const used=new Set<number>();
 for(const node of Array.from(regular.getElementsByTagNameNS(MAIN,'c'))){
  if(node.getAttribute('t')==='s'){
   const value=node.getElementsByTagNameNS(MAIN,'v')[0];
   if(value)used.add(Number(value.textContent));
  }
 }
 const retained=Array.from(used).sort((a,b)=>a-b);
 const sourceStrings=Array.from(strings.getElementsByTagNameNS(MAIN,'si'));
 const lookup=new Map(retained.map((value,index)=>[value,index]));
 for(const node of elements(strings.documentElement))if(node.localName==='si')strings.documentElement.removeChild(node);
 for(const originalIndex of retained){
  const token=sourceStrings[originalIndex];
  if(!token)throw Error('Índice de texto del Kardex fuera de rango.');
  strings.documentElement.appendChild(token.cloneNode(true));
 }
 for(const node of Array.from(regular.getElementsByTagNameNS(MAIN,'c'))){
  if(node.getAttribute('t')==='s'){
   const value=node.getElementsByTagNameNS(MAIN,'v')[0];
   if(value){const index=lookup.get(Number(value.textContent));if(index===undefined)throw Error('Índice de texto no encontrado.');value.textContent=String(index)}
  }
 }
 strings.documentElement.setAttribute('uniqueCount',String(retained.length));
 strings.documentElement.setAttribute('count',String(retained.length));
 zip['xl/sharedStrings.xml']=encode(strings);
 zip[files[2]]=encode(regular);
 // Remove stale workbook application metadata listing a second sheet.
 delete zip['docProps/app.xml'];
 const rootRels=decode(zip['_rels/.rels']);
 for(const rel of Array.from(rootRels.getElementsByTagNameNS(RELS,'Relationship')))
  if(rel.getAttribute('Type')?.endsWith('/extended-properties'))rel.parentNode?.removeChild(rel);
 zip['_rels/.rels']=encode(rootRels);
 const allTypes=decode(zip['[Content_Types].xml']);
 for(const node of elements(allTypes.documentElement))
  if(node.getAttribute('PartName')==='/docProps/app.xml')node.parentNode?.removeChild(node);
 zip['[Content_Types].xml']=encode(allTypes);
 // Force Excel to recalculate formulas while cached values remain available.
 const calc=workbook.getElementsByTagNameNS(NS,'calcPr')[0];
 if(calc){calc.setAttribute('fullCalcOnLoad','1');calc.setAttribute('forceFullCalc','1')}
 zip[files[0]]=encode(workbook);
 return zipSync(zip,{level:6});
}
export function reportFilename(date:string){return 'DANPER_KARDEX_DIARIO_'+date+'.xlsx'}
