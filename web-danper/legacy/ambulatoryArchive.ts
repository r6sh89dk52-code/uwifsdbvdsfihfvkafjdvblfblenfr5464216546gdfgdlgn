/** Bounded ZIP decoding before XML parsing, including CRC and local headers. */
import {Unzip,UnzipInflate,strFromU8} from 'fflate';
export const ARCHIVE_LIMITS={compressed:20_000_000,expanded:40_000_000,part:24_000_000,entries:256};
function updateCRC(crc:number,bytes:Uint8Array):number{
 for(const byte of bytes){crc^=byte;for(let i=0;i<8;i++)crc=(crc>>>1)^((crc&1)?0xedb88320:0)}
 return crc>>>0;
}
export function readAmbulatoryArchive(bytes:Uint8Array,retain:(name:string)=>boolean=()=>true):Record<string,Uint8Array>{
 if(bytes.length>ARCHIVE_LIMITS.compressed||bytes.length<22)throw Error('ZIP inválido o supera 20 MB.');
 const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 let end=-1;
 for(let i=bytes.length-22;i>=Math.max(0,bytes.length-65557);i--){
  if(view.getUint32(i,true)===0x06054b50&&i+22+view.getUint16(i+20,true)===bytes.length){end=i;break}
 }
 if(end<0||view.getUint16(end+4,true)||view.getUint16(end+6,true))throw Error('Directorio ZIP inválido.');
 const count=view.getUint16(end+10,true),offset=view.getUint32(end+16,true),size=view.getUint32(end+12,true);
 if(!count||count>ARCHIVE_LIMITS.entries||view.getUint16(end+8,true)!==count||offset+size!==end)throw Error('ZIP multipartes/ZIP64 no compatible o demasiadas entradas.');
 const specs=new Map<string,{size:number;crc:number}>(),intervals:{start:number;end:number}[]=[];
 let at=offset,total=0;
 for(let i=0;i<count;i++){
  if(at+46>end||view.getUint32(at,true)!==0x02014b50)throw Error('Directorio ZIP corrupto.');
  const flags=view.getUint16(at+8,true),method=view.getUint16(at+10,true),compressed=view.getUint32(at+20,true),expanded=view.getUint32(at+24,true);
  const n=view.getUint16(at+28,true),extra=view.getUint16(at+30,true),comment=view.getUint16(at+32,true),local=view.getUint32(at+42,true);
  if(at+46+n+extra+comment>end||local+30>offset)throw Error('Límites ZIP corruptos.');
  const name=strFromU8(bytes.subarray(at+46,at+46+n));
  if(!name||name.includes('..')||name.includes('\\')||name.startsWith('/')||/[\u0000-\u001f]/.test(name)||specs.has(name)||flags&1||![0,8].includes(method)||
   expanded>ARCHIVE_LIMITS.part||(total+=expanded)>ARCHIVE_LIMITS.expanded||expanded>Math.max(1_000_000,compressed*300))throw Error('ZIP inseguro, duplicado o demasiado grande.');
  if(view.getUint32(local,true)!==0x04034b50||view.getUint16(local+8,true)!==method||view.getUint16(local+6,true)!==flags)throw Error('Cabecera local ZIP incompatible.');
  const ln=view.getUint16(local+26,true),le=view.getUint16(local+28,true),start=local+30+ln+le;
  if(start+compressed>offset||strFromU8(bytes.subarray(local+30,local+30+ln))!==name)throw Error('Nombre o longitud ZIP inconsistente.');
  intervals.push({start:local,end:start+compressed});
  specs.set(name,{size:expanded,crc:view.getUint32(at+16,true)});
  at+=46+n+extra+comment;
 }
 if(at!==end)throw Error('Directorio ZIP inconsistente.');
 intervals.sort((a,b)=>a.start-b.start);
 if(intervals.some((x,i)=>i>0&&x.start<intervals[i-1].end))throw Error('Entradas ZIP solapadas.');
 const output:Record<string,Uint8Array>=Object.create(null);
 let used=0;const completed=new Set<string>();
 const decoder=new Unzip(file=>{
  const spec=specs.get(file.name);
  if(!spec||file.originalSize!==spec.size||output[file.name])throw Error('Entrada ZIP no declarada.');
  const chunks:Uint8Array[]=[],keep=retain(file.name);let length=0,crc=0xffffffff;
  file.ondata=(error,chunk,final)=>{
   if(error)throw Error('Datos ZIP corruptos.');
   length+=chunk.length;used+=chunk.length;
   if(length>spec.size||length>ARCHIVE_LIMITS.part||used>ARCHIVE_LIMITS.expanded)throw Error('Expansión ZIP fuera de límite.');
   crc=updateCRC(crc,chunk);if(keep)chunks.push(chunk);
   if(final){
    if(length!==spec.size)throw Error('Tamaño ZIP inconsistente.');
    if(((crc^0xffffffff)>>>0)!==spec.crc)throw Error('CRC ZIP inválido.');
    if(keep){const data=new Uint8Array(length);let pos=0;for(const part of chunks){data.set(part,pos);pos+=part.length}output[file.name]=data;}
    completed.add(file.name);
   }
  };
  file.start();
 });
 decoder.register(UnzipInflate);
 for(let i=0;i<bytes.length;i+=32768)decoder.push(bytes.subarray(i,i+32768),i+32768>=bytes.length);
 if(completed.size!==count)throw Error('ZIP incompleto.');
 return output;
}

