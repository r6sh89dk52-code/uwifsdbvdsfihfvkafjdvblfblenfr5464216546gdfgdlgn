import {Capacitor} from '@capacitor/core';
import {Directory,Filesystem} from '@capacitor/filesystem';
import {Share} from '@capacitor/share';
/** On iOS invoke the native Share Sheet; on web use a download link. */
export async function shareXlsx(filename:string,data:Uint8Array):Promise<void>{
 if(Capacitor.isNativePlatform()&&Capacitor.getPlatform()==='ios'){
  let binary='';const chunk=0x8000;
  for(let i=0;i<data.length;i+=chunk)binary+=String.fromCharCode(...data.slice(i,i+chunk));
  const base64=btoa(binary);
  const saved=await Filesystem.writeFile({path:filename,data:base64,directory:Directory.Cache,recursive:true});
  await Share.share({title:'Kardex diario DANPER',url:saved.uri,dialogTitle:'Compartir Kardex diario'});
 }else{
  const blob=new Blob([new Uint8Array(data)],{type:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'});
  const url=URL.createObjectURL(blob);
  const link=document.createElement('a');link.href=url;link.download=filename;document.body.append(link);link.click();link.remove();
  setTimeout(()=>URL.revokeObjectURL(url),30000);
 }
}
