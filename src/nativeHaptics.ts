/** Light, native-only iOS feedback. Never blocks saving or asks permission.
 * Respect the user's in-app choice; reduced motion is controlled by CSS.
 */
import {Capacitor} from '@capacitor/core';
import {Haptics,ImpactStyle,NotificationType} from '@capacitor/haptics';
export type FeedbackKind='tap'|'selection'|'success'|'warning'|'error';
const KEY='danper-haptics-enabled-v1';
export function hapticsEnabled():boolean{
 try{return localStorage.getItem(KEY)!=='off'}catch{return true}
}
export function setHapticsEnabled(value:boolean):void{
 try{localStorage.setItem(KEY,value?'on':'off')}catch{/* noncritical preference */}
}
export async function hapticFeedback(kind:FeedbackKind):Promise<void>{
 if(!hapticsEnabled()||!Capacitor.isNativePlatform()||Capacitor.getPlatform()!=='ios')return;
 try{
  switch(kind){
   case 'tap':await Haptics.impact({style:ImpactStyle.Light});break;
   case 'selection':await Haptics.selectionChanged();break;
   case 'success':await Haptics.notification({type:NotificationType.Success});break;
   case 'warning':await Haptics.notification({type:NotificationType.Warning});break;
   case 'error':await Haptics.notification({type:NotificationType.Error});break;
  }
 }catch{/* Haptics are optional: do not interrupt clinical data workflows. */}
}
export function feedback(kind:FeedbackKind):void{void hapticFeedback(kind)}
