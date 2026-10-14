/** DANPER v0.17: export from the reviewed sanitised, locally embedded ten-sheet
 * layout. Never include the historical workbook or any real patient data.
 */
import {strFromU8,strToU8,unzipSync,zipSync} from 'fflate';
import {type ExportPlan,type ExportValue,validExportDate} from './ambulatoryRows';
import template from './ambulatoryTemplate.json';
import products from './products.json';
import {readAmbulatoryArchive} from './ambulatoryArchive';
import {type ReconciliationPlan} from './ambulatoryReconciliation';
const M='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const PKG='http://schemas.openxmlformats.org/package/2006/relationships';
const EXPECTED=['BD MATERIALES','CONTEO','INGRESOS','RESU','CONSUMOS','JUSTIFICACIONES','GUIA','@subuo','BASE TRU','@uo'];
const utf8=(s:string)=>strToU8(s);
const decoded=(b:Uint8Array)=>strFromU8(b);
function parse(xml:string):Document{
 if(/<!DOCTYPE|<!ENTITY/i.test(xml))throw Error('XML con entidades no permitido.');
 const result=new DOMParser().parseFromString(xml,'application/xml');
 if(result.getElementsByTagName('parsererror').length)throw Error('XML original incompatible.');
 return result;
}
function all(element:Document|Element,name:string):Element[]{return Array.from(element.getElementsByTagNameNS(M,name))}
function direct(element:Element,name:string):Element[]{return Array.from(element.childNodes).filter((x):x is Element=>x.nodeType===1&&(x as Element).localName===name)}
function child(element:Element,name:string):Element|undefined{return direct(element,name)[0]}
function make(doc:Document,name:string){return doc.createElementNS(M,name)}
function write(doc:Document){return new XMLSerializer().serializeToString(doc)}
function clean(text:string){return text.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g,'')}
function col(i:number){let s='';for(let n=i+1;n;n=Math.floor((n-1)/26))s=String.fromCharCode(65+(n-1)%26)+s;return s}
function index(cell:string){let n=0;for(const x of cell.match(/^[A-Z]+/)?.[0]||'')n=n*26+x.charCodeAt(0)-64;return n-1}
function put(doc:Document,row:Element,i:number,value:ExportValue,style?:string){
 const c=make(doc,'c');c.setAttribute('r',col(i)+row.getAttribute('r'));
 if(style)c.setAttribute('s',style);
 if(typeof value==='number'){
  if(!Number.isFinite(value))throw Error('Cantidad o fecha Excel inválida.');
  const v=make(doc,'v');v.textContent=String(value);c.appendChild(v);
 }else if(value!==''){
  c.setAttribute('t','inlineStr');const is=make(doc,'is'),t=make(doc,'t');
  t.setAttribute('xml:space','preserve');t.textContent=clean(value);is.appendChild(t);c.appendChild(is);
 }
 row.appendChild(c);
}
function replaceData(root:Document,headerRows:number,records:ExportValue[][],colCount:number){
 const sheet=all(root,'sheetData')[0];if(!sheet)throw Error('No existe sheetData.');
 const old=direct(sheet,'row');const exemplar=old.find(x=>Number(x.getAttribute('r'))===headerRows+1)||old[old.length-1];
 const styles=new Map<number,string>();
 if(exemplar)for(const c of direct(exemplar,'c')){const s=c.getAttribute('s');if(s)styles.set(index(c.getAttribute('r')||''),s)}
 for(const row of old){if(Number(row.getAttribute('r'))>headerRows)sheet.removeChild(row)}
 const used=Math.max(1,records.length);
 for(let i=0;i<used;i++){
  const r=make(root,'row');r.setAttribute('r',String(headerRows+1+i));
  for(let c=0;c<colCount;c++)put(root,r,c,records[i]?.[c]??'',styles.get(c));
  sheet.appendChild(r);
 }
 const dim=all(root,'dimension')[0];if(dim)dim.setAttribute('ref','A1:'+col(colCount-1)+(headerRows+used));
}
function readValue(c:Element,shared:string[]):string{
 if(c.getAttribute('t')==='s')return shared[Number(child(c,'v')?.textContent||0)]||'';
 if(c.getAttribute('t')==='inlineStr')return all(c,'t').map(x=>x.textContent||'').join('');
 return child(c,'v')?.textContent||'';
}
function readCatalog(root:Document,shared:string[]){
 const result:{code:string;name:string;unit:string}[]=[];
 const rows=direct(all(root,'sheetData')[0],'row');
 for(const row of rows.slice(1)){
  const cells=direct(row,'c');
  const get=(i:number)=>{const c=cells.find(x=>index(x.getAttribute('r')||'')===i);return c?readValue(c,shared):''};
  const code=get(0),name=get(1),unit=get(2);
  if(/^\d+$/.test(code)&&name&&unit)result.push({code,name,unit});
 }
 const seen=new Set(result.map(p=>p.code));
 if(result.length!==432||seen.size!==432)throw Error('La plantilla no corresponde al catálogo oficial de 432 códigos numéricos.');
 return result;
}
function makeRowsForProducts(products:{code:string;name:string;unit:string}[],sheet:number):ExportValue[][]{
 return products.map(p=>{
  const cols=sheet===2?8:sheet===3?25:13;
  const v:ExportValue[]=Array(cols).fill('');v[0]=p.code;v[1]=p.name;v[2]=p.unit;return v;
 });
}
function setFormula(doc:Document,cell:Element,formula:string){
 if(!formula)return;
 const f=make(doc,'f');f.textContent=formula;cell.appendChild(f);
}
function applyFormulas(root:Document,sheet:number){
 const rows=direct(all(root,'sheetData')[0],'row');
 for(const r of rows){const n=Number(r.getAttribute('r'));
  if(n<3)continue;
  const cells=direct(r,'c');
  const fill=(index0:number,formula:string)=>{
   const c=cells.find(e=>index(e.getAttribute('r')||'')===index0);
   if(c)setFormula(root,c,formula);
  };
  if(sheet===2)fill(7,`IF(COUNTA(D${n}:G${n})=0,"",SUM(D${n}:G${n}))`);
  if(sheet===3){
   for(const [colIdx,letter] of [[3,'J'],[4,'N'],[5,'R'],[6,'V']] as const)
    fill(colIdx,`IF(${letter}${n}="","",IF(${letter}${n}-TODAY()<=90,1,0))`);
   fill(23,`IF(COUNTA(H${n},L${n},P${n},T${n})=0,"",SUM(H${n},L${n},P${n},T${n}))`);
  }
  if(sheet===4){
   fill(4,`IF(COUNT(INGRESOS!X${n})=0,"",INGRESOS!X${n})`);
   fill(5,`SUMIF(TB_CONSUMOS[CÓDIGO],A${n},TB_CONSUMOS[CANTIDAD])`);
   fill(6,`IF(OR(D${n}="",E${n}=""),"",SUM(D${n}:E${n})-F${n})`);
   fill(7,`IF(COUNT(CONTEO!D${n})=0,"",CONTEO!D${n})`);
   fill(8,`IF(OR(G${n}="",H${n}=""),"",G${n}-H${n})`);
   fill(9,`IF(I${n}="","",IF(I${n}<0,"SOBRANTE",IF(I${n}=0,"-","FALTANTE")))`);
   fill(11,`IF(OR(K${n}="",G${n}=""),"",K${n}-G${n})`);
  }
 }
}
function target(base:string,relative:string):string{
 if(relative.includes('\\')||/[?#\u0000]/.test(relative))throw Error('Referencia OOXML incompatible.');
 const path=relative.startsWith('/')?[]:base.split('/').slice(0,-1);
 for(const part of relative.split('/')){
  if(part==='..'){if(!path.length)throw Error('Referencia fuera del libro.');path.pop()}
  else if(part&&part!=='.')path.push(part);
 }
 return path.join('/');
}
function validateOriginal(entries:Record<string,Uint8Array>){
 for(const [name,bytes]of Object.entries(entries))if(name.endsWith('.xml')||name.endsWith('.rels'))parse(decoded(bytes));
 if(!entries['xl/workbook.xml']||!entries['xl/_rels/workbook.xml.rels'])throw Error('Libro Excel incompleto.');
 const book=parse(decoded(entries['xl/workbook.xml']));
 const sheets=all(book,'sheet');
 if(sheets.map(e=>e.getAttribute('name')).join('|')!==EXPECTED.join('|'))throw Error('Selecciona la plantilla oficial de DIEZ hojas.');
 if(all(book,'workbookPr').some(e=>['1','true'].includes(e.getAttribute('date1904')||'')))throw Error('Sistema de fechas Excel 1904 no compatible.');
 const rels=parse(decoded(entries['xl/_rels/workbook.xml.rels']));
 const mapped=new Map<string,string>();
 for(const rel of Array.from(rels.getElementsByTagNameNS(PKG,'Relationship'))){
  const id=rel.getAttribute('Id')||'';
  if(mapped.has(id))throw Error('Relación de libro duplicada.');
  if(rel.getAttribute('Type')?.endsWith('/worksheet')){
   if(rel.getAttribute('TargetMode')==='External')throw Error('Hoja externa no compatible.');
   mapped.set(id,target('xl/workbook.xml',rel.getAttribute('Target')||''));
  }
 }
 const docs=sheets.map(e=>{
  const id=e.getAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships','id')||'';
  const path=mapped.get(id);if(!path||!entries[path])throw Error('Relación de hoja incompleta.');
  return parse(decoded(entries[path]));
 });
 const shared=entries['xl/sharedStrings.xml']?all(parse(decoded(entries['xl/sharedStrings.xml'])),'si').map(e=>all(e,'t').map(t=>t.textContent||'').join('')):[];
 const catalog=readCatalog(docs[0],shared);
 const official=new Map(products.map(p=>[p.code,p]));
 for(const p of catalog){const verified=official.get(p.code);if(!verified||p.name.trim()!==verified.name.trim()||p.unit.trim()!==verified.unit.trim())throw Error('La plantilla no coincide con los 432 materiales oficiales.');}
 const first=direct(all(docs[4],'sheetData')[0],'row').find(e=>e.getAttribute('r')==='1');
 if(!first)throw Error('Faltan encabezados CONSUMOS.');
 const cells=direct(first,'c');
 const headers=Array.from({length:30},(_,i)=>{const c=cells.find(e=>index(e.getAttribute('r')||'')===i);return c?readValue(c,shared):''});
 if(headers.some((h,i)=>h!==template.headers[i])||cells.some(e=>index(e.getAttribute('r')||'')>=30))throw Error('Los 30 encabezados CONSUMOS no corresponden al libro original.');
 const tables=Object.entries(entries).filter(([n])=>/^xl\/tables\/[^/]+\.xml$/.test(n)).map(([,b])=>parse(decoded(b)).documentElement);
 if(tables.some(t=>t.getAttribute('name')!==t.getAttribute('displayName'))||new Set(tables.map(t=>t.getAttribute('name'))).size!==19)throw Error('Nombres de tablas originales incompatibles.');
 const consumption=tables.filter(e=>e.getAttribute('displayName')==='TB_CONSUMOS');
 if(tables.length!==19||consumption.length!==1||all(consumption[0],'tableColumn').length!==30)throw Error('Estructura de tablas original incompatible.');
 if(all(consumption[0],'tableColumn').some((c,i)=>c.getAttribute('name')!==template.tableHeaders[i]))throw Error('Columnas de la tabla CONSUMOS incompatibles.');
}
const cellCache=new WeakMap<Document,Map<string,Element>>();
function editCell(doc:Document,reference:string,value:ExportValue){
 let cache=cellCache.get(doc);
 if(!cache){cache=new Map(all(doc,'c').map(e=>[e.getAttribute('r')||'',e]));cellCache.set(doc,cache)}
 const cell=cache.get(reference);if(!cell)return;
 const row=cell.parentNode as Element;const i=index(reference),style=cell.getAttribute('s')||undefined;
 for(const c of Array.from(cell.childNodes))cell.removeChild(c);
 cell.removeAttribute('t');
 const holder=make(doc,'row');holder.setAttribute('r',row.getAttribute('r')||'1');put(doc,holder,i,value,style);
 const replacement=child(holder,'c')!;
 row.replaceChild(replacement,cell);cache.set(reference,replacement);
}
function resizeSheet(doc:Document,last:number,originalLast:number){
 for(const element of Array.from(doc.getElementsByTagName('*'))){
  for(const key of ['ref','sqref']){
   const ref=element.getAttribute(key);
   if(ref)element.setAttribute(key,ref.replace(new RegExp('([A-Z]\\$?)'+originalLast+'(?=\\s|$)','g'),'$1'+last));
  }
 }
}
function organizationFormula(column:number,row:number):string{
 if(column===2)return `IF(A${row}="","",IFERROR(VLOOKUP(A${row},'@subuo'!$A$3:$C$59,2,FALSE),""))`;
 return `IF(OR(A${row}="",B${row}=""),"",IFERROR(VLOOKUP(CONCATENATE(VLOOKUP(A${row},'@subuo'!$A$3:$C$59,3,FALSE),B${row}),'@uo'!$D$2:$E$234,2,FALSE),""))`;
}
export function exportAmbulatoryWorkbook(original:Uint8Array,plan:ExportPlan,material?:ReconciliationPlan):Uint8Array{
 if(plan.blockers.length)throw Error('Resuelve primero las entregas y datos pendientes de conciliación.');
 if(!validExportDate(plan.start)||!validExportDate(plan.end)||plan.start>plan.end||plan.lines.length>10000)throw Error('Plan de exportación inválido.');
 const ids=new Set<string>();
 for(const line of plan.lines){
  if(ids.has(line.id)||line.cells.length!==30)throw Error('Filas duplicadas o columnas incompatibles.');ids.add(line.id);
  const code=line.cells[15],qty=line.cells[17];
  if(code!==''&&(!products.some(p=>p.code===code&&p.name===line.cells[16])||typeof qty!=='number'||!Number.isFinite(qty)||qty<0))throw Error('Material o cantidad no verificados.');
  if(code===''&&(line.cells[16]!==''||qty!==''))throw Error('Cantidad sin material.');
  for(const v of line.cells)if((typeof v!=='number'&&typeof v!=='string')||(typeof v==='number'&&!Number.isFinite(v))||(typeof v==='string'&&(v.length>32767||/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(v))))throw Error('Valor Excel incompatible.');
 }
 validateOriginal(readAmbulatoryArchive(original,name=>!/^xl\/(externalLinks|pivotCache)\/|^docProps\/|^customXml\//.test(name)));
 // No selected XML is ever copied. Export only the empty audited layout and
 // the current plan. This also removes unknown cached/hidden future parts.
 const encoded=atob(template.zipBase64),bytes=Uint8Array.from(encoded,c=>c.charCodeAt(0));
 const entries=unzipSync(bytes),result:Record<string,Uint8Array>={};
 const styles=parse(decoded(entries['xl/styles.xml'])),formats=all(styles,'cellXfs')[0];
 const textStyles=new Map<string,string>();
 function asText(cell:Element){
  const style=cell.getAttribute('s')||'0';
  let mapped=textStyles.get(style);
  if(!mapped){
   const xfs=direct(formats,'xf'),source=xfs[Number(style)];if(!source)throw Error('Formato Excel incompatible.');
   const clone=source.cloneNode(true) as Element;clone.setAttribute('numFmtId','49');clone.setAttribute('applyNumberFormat','1');
   mapped=String(xfs.length);formats.appendChild(clone);formats.setAttribute('count',String(xfs.length+1));textStyles.set(style,mapped);
  }
  cell.setAttribute('s',mapped);
 }
 const documents=new Map<number,Document>();
 const last=Math.max(2,plan.lines.length+1);
 for(let i=1;i<=10;i++){
  const doc=parse(decoded(entries[`xl/worksheets/sheet${i}.xml`]));
  if(i===2||i===3||i===4){
   replaceData(doc,2,makeRowsForProducts(products,i),i===2?8:i===3?25:13);applyFormulas(doc,i);
   resizeSheet(doc,434,439);
   // The original 10-sheet layout has one row for each authorized material.
   // Undefined = not verified (blank); declared zero = measured 0.
   if(material){
    for(let p=0;p<products.length;p++){
     const row=p+3,data=material.byCode[products[p].code];
     if(!data)throw Error('No hay conciliación para el código oficial '+products[p].code);
     if(i===2&&data.count!==undefined)editCell(doc,'D'+row,data.count);
     if(i===3){
      const positions=[['H','I','J','K'],['L','M','N','O'],['P','Q','R','S'],['T','U','V','W']];
      if(data.receiptDetails.length>4)throw Error('La hoja original admite cuatro ingresos por material.');
      data.receiptDetails.forEach((receipt,j)=>{
       const[cQty,cDate,cExpiry,cDocument]=positions[j];
       editCell(doc,cQty+row,receipt.quantity);
       editCell(doc,cDate+row,(Date.parse(receipt.date+'T00:00:00Z')-Date.UTC(1899,11,30))/86400000);
       if(receipt.expires)editCell(doc,cExpiry+row,(Date.parse(receipt.expires+'T00:00:00Z')-Date.UTC(1899,11,30))/86400000);
       editCell(doc,cDocument+row,receipt.document);
      });
      if(data.receipts!==undefined){
       const x=all(doc,'c').find(e=>e.getAttribute('r')==='X'+row);
       if(!x)throw Error('La hoja INGRESOS perdió la celda de totales.');
       for(const c of Array.from(x.childNodes))x.removeChild(c);
       x.removeAttribute('t');
       setFormula(doc,x,`IF(COUNTA(H${row},L${row},P${row},T${row})=0,0,SUM(H${row},L${row},P${row},T${row}))`);
      }else editCell(doc,'X'+row,'');
     }
     if(i===4){
      if(data.opening!==undefined)editCell(doc,'D'+row,data.opening);
      const pending=[
       data.opening===undefined?'STOCK INICIAL PENDIENTE':'',
       data.receipts===undefined?'INGRESOS NO VERIFICADOS':'',
       data.count===undefined?'CONTEO PENDIENTE':'',
       data.difference!==undefined&&data.difference!==0?'DIFERENCIA POR REVISAR':''
      ].filter(Boolean);
      editCell(doc,'M'+row,pending.length?pending.join(' · '):'CONCILIADO');
     }
    }
   }
   if(i===2)editCell(doc,'D1',material?'CONTEO FÍSICO '+plan.end+' · '+material.countConfirmed+' DE 432 VERIFICADOS':'INVENTARIO PENDIENTE DE CONCILIACIÓN');

   if(i===3){
    editCell(doc,'H1','INGRESOS '+plan.start+' AL '+plan.end+(material?' · SEGÚN INVENTARIO':' · SIN VERIFICAR'));
    if(!material)for(const r of direct(all(doc,'sheetData')[0],'row'))if(Number(r.getAttribute('r'))>=3)editCell(doc,'Y'+r.getAttribute('r'),'PENDIENTE DE CONCILIACIÓN');
   }
   if(i===4){
    editCell(doc,'E1',plan.start+' AL '+plan.end);
    if(!material)for(const r of direct(all(doc,'sheetData')[0],'row'))if(Number(r.getAttribute('r'))>=3)editCell(doc,'M'+r.getAttribute('r'),'STOCK INICIAL, INGRESOS Y CONTEO PENDIENTES');
   }
  }
  if(i===5){
   replaceData(doc,1,plan.lines.map(x=>x.cells),30);resizeSheet(doc,last,2793);
   const formats=all(doc,'conditionalFormatting');
   if(last>2793&&formats.length){
    const extension=formats[0].cloneNode(true) as Element;
    extension.setAttribute('sqref','P2794:P'+last);
    const maxPriority=Math.max(0,...all(doc,'cfRule').map(e=>Number(e.getAttribute('priority'))||0));
    all(extension,'cfRule').forEach((e,n)=>e.setAttribute('priority',String(maxPriority+n+1)));
    doc.documentElement.insertBefore(extension,formats[formats.length-1].nextSibling);
   }
   for(const r of direct(all(doc,'sheetData')[0],'row')){
    const n=Number(r.getAttribute('r'));if(n<2)continue;
    for(const c of direct(r,'c')){const column=index(c.getAttribute('r')||'');if(column===2||column===3)setFormula(doc,c,organizationFormula(column,n))}
   }
  }
  if(i===6||i===9)replaceData(doc,1,[],i===6?13:6);
  for(const c of all(doc,'c')){
   const ref=c.getAttribute('r')||'';
   if(Number(ref.match(/\d+$/)?.[0])>1&&((i===1&&index(ref)===0)||(i===5&&[7,15,27].includes(index(ref)))))asText(c);
  }
  documents.set(i,doc);result[`xl/worksheets/sheet${i}.xml`]=utf8(write(doc));
 }
 for(const[name,data]of Object.entries(entries)){
  if(name.startsWith('xl/worksheets/sheet'))continue;
  if(name.startsWith('xl/tables/')&&name.endsWith('.xml')){
   const doc=parse(decoded(data)),table=doc.documentElement,tableName=table.getAttribute('displayName')||'';
   const bounds:Record<string,string>={Tabla21:'A1:C433',Tabla17:'A2:M434',TB_CONSUMOS:'A1:AD'+last,Tabla13:'A1:F2',Tabla14:'T1:U2'};
   if(bounds[tableName]){table.setAttribute('ref',bounds[tableName]);for(const filter of all(doc,'autoFilter'))filter.setAttribute('ref',bounds[tableName])}
   const columns=all(doc,'tableColumn');
   for(let i=0;i<columns.length;i++){
    let formula='';
    if(tableName==='TB_CONSUMOS'&&(i===2||i===3))formula=organizationFormula(i,2);
    if(tableName==='Tabla17'){
     const first=direct(all(documents.get(4)!,'sheetData')[0],'row').find(r=>r.getAttribute('r')==='3');
     formula=first?child(direct(first,'c')[i],'f')?.textContent||'':'';
    }
    if(formula){const f=make(doc,'calculatedColumnFormula');f.textContent=formula;columns[i].appendChild(f)}
   }
   result[name]=utf8(write(doc));
  }else if(name==='xl/workbook.xml'){
   const book=parse(decoded(data));
   for(const e of all(book,'definedName')){
    const old=e.textContent||'';
    if(e.getAttribute('name')==='_xlnm._FilterDatabase'){
     const id=e.getAttribute('localSheetId');
     if(id==='0')e.textContent="'BD MATERIALES'!$A$2:$C$433";
     if(id==='1')e.textContent='CONTEO!$A$1:$H$434';
     if(id==='2')e.textContent='INGRESOS!$A$2:$Y$434';
    }else e.textContent=old;
   }
   const calc=all(book,'calcPr')[0]||make(book,'calcPr');calc.setAttribute('calcMode','auto');calc.setAttribute('fullCalcOnLoad','1');calc.setAttribute('forceFullCalc','1');if(!calc.parentNode)book.documentElement.appendChild(calc);
   result[name]=utf8(write(book));
  }else if(name==='xl/styles.xml')result[name]=utf8(write(styles));
  else result[name]=data;
 }
 const output=zipSync(result,{level:6});
 if(output.length>20_000_000)throw Error('Exportación demasiado grande.');
 return output;
}
