import {useEffect,useState} from 'react';
import officialLogo from './branding/danper-logo-oficial.png';

/**
 * Preserve the official Danper wordmark, removing only its baked red backdrop.
 * Samples the existing logo: no substitute font, re-created mark or external asset.
 * The same crop and RGB-key formula is applied by the native UIKit welcome.
 */
export function wordmarkAlpha(g:number,b:number):number{
  return Math.max(0,Math.min(255,Math.round((Math.min(g,b)-24)*255/231)));
}
export function cleanWordmarkPixels(pixels:Uint8ClampedArray):Uint8ClampedArray{
  const output=new Uint8ClampedArray(pixels);
  for(let i=0;i<output.length;i+=4){
    const alpha=wordmarkAlpha(output[i+1],output[i+2]);
    output[i]=255;output[i+1]=255;output[i+2]=255;
    output[i+3]=Math.round(output[i+3]*alpha/255);
  }
  return output;
}
export async function makeTransparentWordmark(src:string):Promise<string>{
  const img=new Image();
  img.src=src;
  await img.decode();
  const scale=2;
  const left=Math.round(img.naturalWidth*.094);
  const top=Math.round(img.naturalHeight*.37);
  const width=Math.max(1,Math.round(img.naturalWidth*.83));
  const height=Math.max(1,Math.round(img.naturalHeight*.30));
  const canvas=document.createElement('canvas');
  canvas.width=width*scale;canvas.height=height*scale;
  const context=canvas.getContext('2d',{willReadFrequently:true});
  if(!context)throw new Error('Canvas no disponible');
  context.drawImage(img,left,top,width,height,0,0,canvas.width,canvas.height);
  const frame=context.getImageData(0,0,canvas.width,canvas.height);
  frame.data.set(cleanWordmarkPixels(frame.data));
  context.putImageData(frame,0,0);
  return canvas.toDataURL('image/png');
}
export default function DanperBrandLogo(){
 const [clean,setClean]=useState<string|null>(null);
 useEffect(()=>{
  let disposed=false;
  makeTransparentWordmark(officialLogo).then(src=>{if(!disposed)setClean(src)}).catch(()=>{});
  return()=>{disposed=true};
 },[]);
 return <span className="brand-logo-crop">{clean
   ?<img src={clean} alt="Danper, logotipo oficial" width={147} height={51}/>
   :<span className="brand-logo-fallback" aria-label="Danper">Danper</span>}
 </span>;
}
