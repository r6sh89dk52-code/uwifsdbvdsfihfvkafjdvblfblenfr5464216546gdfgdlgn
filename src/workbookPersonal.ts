type ZipEntry={async(format:'string'):Promise<string>};
type ZipInstance={file(name:string):ZipEntry|null;files:Record<string,{_data?:{uncompressedSize?:number}}>};
const JSZip=(window as Window&{JSZip?:{loadAsync(file:Uint8Array):Promise<ZipInstance>}}).JSZip;
import {compileWorkers,type ImportResult} from './workerRules';
const RID='http://schemas.openxmlformats.org/officeDocument/2006/relationships';
function elements(parent:Element,local:string):Element[]{return Array.from(parent.getElementsByTagNameNS('*',local));}
/** Imported xlsx may contain a UTF-8 BOM before the XML declaration.
 * In WKWebView, DOMParser receives a JavaScript string, not a raw byte
 * stream: U+FEFF preceding <?xml can produce a parsererror.
 * Normalize only the leading BOM, preserving all worksheet content.
 */
function xml(text:string,part:string):Document{
 const normalized=text.replace(/^\uFEFF/,'');
 if(/<!DOCTYPE|<!ENTITY/i.test(normalized))throw Error('XML no permitido en '+part+'.');
 const doc=new DOMParser().parseFromString(normalized,'application/xml');
 if(doc.documentElement.localName==='parsererror'||doc.getElementsByTagName('parsererror').length||
    doc.getElementsByTagNameNS('*','parsererror').length)
   throw Error('No se pudo leer la estructura XML de '+part+'. Comprueba el archivo Excel.');
 return doc;
}
function excelColumn(ref:string):number{
 const match=/^[A-Z]+/i.exec(ref);
 if(!match)return -1;
 return [...match[0].toUpperCase()].reduce((n,c)=>n*26+c.charCodeAt(0)-64,0)-1;
}
/** Read PERSONAL only. Workbook never leaves the device; no history/CONSUMOS is imported. */
export async function readPersonal(file:File):Promise<ImportResult>{
 if(!/\.xlsx$/i.test(file.name))throw Error('Selecciona un archivo .xlsx.');
 if(file.size>20*1024*1024)throw Error('El Excel supera el tamaño permitido (20 MB).');
 if(!JSZip)throw Error('No se pudo cargar el lector local de Excel.');
 const zip=await JSZip.loadAsync(new Uint8Array(await file.arrayBuffer()));
 const extract=async(name:string,max=12*1024*1024):Promise<string>=>{
  const entry=zip.file(name);if(!entry)throw Error('No se encuentra '+name+' dentro del Excel.');
  const pre=zip.files[name]?._data?.uncompressedSize;
  if(pre!==undefined&&pre>max)throw Error('Una hoja del Excel supera el límite de seguridad.');
  const value=await entry.async('string');
  if(value.length>max)throw Error('Una hoja del Excel es demasiado grande.');
  return value;
 };
 const wb=xml(await extract('xl/workbook.xml',1024*1024),'xl/workbook.xml');
 const sheet=elements(wb.documentElement,'sheet').find(n=>n.getAttribute('name')?.trim().toUpperCase()==='PERSONAL');
 if(!sheet)throw Error('Este Excel no contiene la hoja PERSONAL.');
 const rid=sheet.getAttributeNS(RID,'id')||sheet.getAttribute('r:id');
 const rels=xml(await extract('xl/_rels/workbook.xml.rels',1024*1024),'xl/_rels/workbook.xml.rels');
 const target=elements(rels.documentElement,'Relationship').find(n=>n.getAttribute('Id')===rid)?.getAttribute('Target')||'';
 const normalized=target.startsWith('/xl/')?target.slice(1):`xl/${target.replace(/^\.\/|^xl\//,'')}`;
 if(!/^xl\/worksheets\/[a-zA-Z0-9_.-]+\.xml$/.test(normalized))throw Error('La referencia a PERSONAL no es válida.');
 const shared=zip.file('xl/sharedStrings.xml')?xml(await extract('xl/sharedStrings.xml',12*1024*1024),'xl/sharedStrings.xml'):null;
 const strings=shared?elements(shared.documentElement,'si').map(si=>elements(si,'t').map(t=>t.textContent||'').join('')):[];
 const ws=xml(await extract(normalized,16*1024*1024),normalized);
 const sheetRows=elements(ws.documentElement,'sheetData')[0];
 if(!sheetRows)throw Error('La hoja PERSONAL no tiene filas.');
 const rows:unknown[][]=[];
 for(const row of elements(sheetRows,'row')){
  const values:unknown[]=[];
  for(const cell of elements(row,'c')){
   const index=excelColumn(cell.getAttribute('r')||'');
   if(index<0||index>50)continue;
   const v=elements(cell,'v')[0]?.textContent||'';
   const kind=cell.getAttribute('t');
   values[index]=kind==='s'?strings[Number(v)]||'':kind==='inlineStr'?elements(cell,'t').map(t=>t.textContent||'').join(''):v;
  }
  rows.push(values);
  if(rows.length>31000)throw Error('La hoja PERSONAL contiene demasiadas filas.');
 }
 return compileWorkers(rows);
}
