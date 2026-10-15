import {Capacitor} from '@capacitor/core';
import {LocalNotifications} from '@capacitor/local-notifications';
import {notificationId,reminderDueAt} from './draftRules';
import {activeStockLot,expiryNotificationId,expiryReminderAt,LOCAL_NOTICE_LIMIT} from './notificationCenterRules';
import {type StockLot} from './inventoryRules';

export type DraftReminder={id:string;updatedAt:number};
export type NoticeInputs={drafts:readonly DraftReminder[];lots:readonly StockLot[]};
export function isNativeIOS():boolean{return Capacitor.getPlatform()==='ios'&&Capacitor.isNativePlatform()}
export async function enableNativeNotifications():Promise<'granted'|'denied'|'not-native'>{
 if(!isNativeIOS())return 'not-native';
 const result=await LocalNotifications.requestPermissions();return result.display==='granted'?'granted':'denied';
}
const IN_APP_FIRST_ID=800000000,IN_APP_END_ID=2000000000;
const genericBody='Abre DANPER Salud Móvil para revisar tus avisos.';
// No names, DNI, diagnoses or specific medications appear on the iPhone lock screen.
// iOS delivers already-scheduled local notifications even if the app is closed.
type NativePending={id:number;title:string;body:string;schedule:{at:Date};extra:{kind:string}};
export function planLocalNotifications(input:NoticeInputs,now=Date.now()):NativePending[]{
 const planned:NativePending[]=[];
 for(const draft of input.drafts){
  const due=reminderDueAt(draft.updatedAt);
  if(!Number.isFinite(due)||due<=now+1000)continue;
  planned.push({id:notificationId(draft.id),title:'DANPER Salud Móvil',
   body:'Tienes una atención pendiente por completar.',
   schedule:{at:new Date(due)},extra:{kind:'danper-draft-reminder'}});
 }
 // One generic OS notification per expiry day; several affected lots share an alert.
 // The full product/lot details are available only AFTER unlocking the app.
 const dates=new Set(input.lots.filter(activeStockLot).map(l=>l.expires).filter(Boolean));
 for(const expires of dates){
  const due=expiryReminderAt(expires,now);
  if(due===null)continue;
  planned.push({id:expiryNotificationId(expires),title:'DANPER Salud Móvil',
   body:genericBody,schedule:{at:new Date(due)},extra:{kind:'danper-stock-expiry'}});
 }
 planned.sort((a,b)=>a.schedule.at.getTime()-b.schedule.at.getTime()||a.id-b.id);
 const ids=new Set<number>();
 return planned.filter(n=>{if(ids.has(n.id))return false;ids.add(n.id);return true}).slice(0,LOCAL_NOTICE_LIMIT);
}
let queue:Promise<void>=Promise.resolve();
let lastSignature:string|null=null;
/** Local iPhone schedules only; zero network, zero push tokens, no server. */
export function syncNativeNotifications(input:NoticeInputs,enabled:boolean):Promise<void>{
 if(!isNativeIOS())return Promise.resolve();
 const now=Date.now();
 const plan=enabled?planLocalNotifications(input,now):[];
 const signature=JSON.stringify(plan.map(n=>[n.id,n.schedule.at.getTime(),n.extra.kind]));
 if(signature===lastSignature)return queue;
 queue=queue.catch(()=>undefined).then(async()=>{
  const permission=enabled?await LocalNotifications.checkPermissions():null;
  if(enabled&&permission?.display!=='granted'){
   lastSignature=null;throw Error('Los permisos de notificaciones de iOS están desactivados.');
  }
  const pending=await LocalNotifications.getPending();
  const ours=pending.notifications.filter(n=>n.id>=IN_APP_FIRST_ID&&n.id<IN_APP_END_ID).map(n=>({id:n.id}));
  if(ours.length)await LocalNotifications.cancel({notifications:ours});
  if(enabled&&plan.length)await LocalNotifications.schedule({notifications:plan});
  lastSignature=signature;
 });
 return queue;
}
/** Retained for callers upgrading from pre-0.21.9 code. */
export function syncNativeDraftNotifications(drafts:DraftReminder[],enabled:boolean):Promise<void>{
 return syncNativeNotifications({drafts,lots:[]},enabled);
}
