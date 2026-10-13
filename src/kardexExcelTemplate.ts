/** Preserve the ORIGINAL 2026 nurse Kardex OOXML sheets, styles, merged cells,
 * borders, print configuration and printer settings. Replace data cells only.
 */
import {unzipSync,zipSync,strFromU8,strToU8} from 'fflate';
import {type DailyReport} from './dailyKardex';
const NS='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const sha='kardex official source: October 2026';
function nodeName(n:Element){return n.localName}
function child(parent:Element,name:string){return Array.from(parent.children).find(x=>nodeName(x)===name)}
function cell(root:Document,address:string){
 const ref=address.match(/^([A-Z]+)(\d+)$/);
 if(!ref)throw Error('Celda del formato no reconocida.');
 const data=root.getElementsByTagNameNS(NS,'sheetData')[0];
 const index=Number(ref[2]);let row=Array.from(data.children).find(x=>nodeName(x)==='row'&&Number(x.getAttribute('r'))===index);
 if(!row){row=root.createElementNS(NS,'row');row.setAttribute('r',String(index));data.append(row)}
 let c=Array.from(row.children).find(x=>nodeName(x)==='c'&&x.getAttribute('r')===address);
 if(!c){
  c=root.createElementNS(NS,'c');c.setAttribute('r',address);
  const colNum=(s:string)=>s.split('').reduce((n,k)=>n*26+k.charCodeAt(0)-64,0);
  const pos=colNum(ref[1]);
  const next=Array.from(row.children).find(x=>{
   const a=x.getAttribute('r')?.match(/^([A-Z]+)/);
   return a?colNum(a[1])>pos:false
  });
  if(next)row.insertBefore(c,next);else row.append(c);
 }
 return c;
}
function clear(cell:Element){for(const n of Array.from(cell.children))if(['v','f','is'].includes(nodeName(n)))n.remove();cell.removeAttribute('t')}
function setNum(root:Document,addr:string,value:number|null,formula?:string){
 const c=cell(root,addr);clear(c);
 if(value===null)return;
 if(!Number.isFinite(value))throw Error('Cantidad inválida '+addr);
 if(formula){const f=root.createElementNS(NS,'f');f.textContent=formula;c.append(f)}
 const v=root.createElementNS(NS,'v');v.textContent=String(value);c.append(v);
}
function setText(root:Document,addr:string,value:string){
 const c=cell(root,addr);clear(c);
 c.setAttribute('t','inlineStr');
 const is=root.createElementNS(NS,'is'),t=root.createElementNS(NS,'t');
 t.setAttribute('xml:space','preserve');t.textContent=value;is.append(t);c.append(is);
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
 const files=['xl/workbook.xml','xl/worksheets/sheet1.xml','xl/worksheets/sheet2.xml'];
 if(files.some(x=>!zip[x]))throw Error('La plantilla no contiene los componentes esperados.');
 const workbook=decode(zip[files[0]]),donations=decode(zip[files[1]]),regular=decode(zip[files[2]]);
 ensure(workbook,'KARDEX ENFERMERAS');ensure(workbook,'Hoja1');
 if(!report.rows||report.rows.filter(r=>!r.donated).length!==98||report.rows.filter(r=>r.donated).length!==6)
  throw Error('Reporte incompleto: se esperan 98 productos generales y 6 donados.');
 // Verify original title and product cells before changing stock.
 const generalTitle=regular.getElementsByTagNameNS(NS,'sheetData')[0];
 if(!generalTitle||!regular.getElementsByTagNameNS(NS,'mergeCells').length)throw Error('No corresponde al formato original.');
 const dd=report.date.split('-').reverse().join('/');
 setText(regular,'A3','TURNO: '+shift);
 setText(regular,'A4','RESPONSABLE: '+responsible.trim());
 setText(regular,'I3','FECHA: '+dd);
 report.rows.filter(r=>!r.donated).forEach((r,i)=>{
  const row=i+7;
  setNum(regular,'D'+row,r.initial);
  setNum(regular,'E'+row,r.extraordinary);
  setNum(regular,'F'+row,r.total,'D'+row+'+E'+row);
  setNum(regular,'G'+row,r.consumed);
  setNum(regular,'H'+row,r.final,'F'+row+'-G'+row);
  if(r.expiry)setText(regular,'I'+row,r.expiry);else setNum(regular,'I'+row,null);
  setNum(regular,'J'+row,r.fs);
 });
 setText(donations,'A3','RESPONSABLE: '+responsible.trim());
 setText(donations,'E2','FECHA: '+dd);
 for(const turn of ['MAÑANA','TARDE','NOCHE']){
  const col=turn==='MAÑANA'?'B2':turn==='TARDE'?'C2':'D2';
  setText(donations,col,turn+(turn===shift?' (X)':''));
 }
 report.rows.filter(r=>r.donated).forEach((r,i)=>{
  const row=i+6;
  setNum(donations,'B'+row,r.initial);
  setNum(donations,'C'+row,r.consumed);
  setNum(donations,'D'+row,r.final,'B'+row+'-C'+row);
  setNum(donations,'E'+row,r.fs);
 });
 zip[files[1]]=encode(donations);zip[files[2]]=encode(regular);
 // Force Excel to recalculate formulas while cached values remain available.
 const calc=workbook.getElementsByTagNameNS(NS,'calcPr')[0];
 if(calc){calc.setAttribute('fullCalcOnLoad','1');calc.setAttribute('forceFullCalc','1')}
 zip[files[0]]=encode(workbook);
 return zipSync(zip,{level:6});
}
export function reportFilename(date:string){return 'DANPER_KARDEX_DIARIO_'+date+'.xlsx'}
