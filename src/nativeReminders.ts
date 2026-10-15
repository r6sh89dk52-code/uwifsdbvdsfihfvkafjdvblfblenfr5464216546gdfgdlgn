import {Capacitor} from '@capacitor/core';
import {LocalNotifications} from '@capacitor/local-notifications';
import {notificationId,reminderDueAt} from './draftRules';

export type DraftReminder={id:string;updatedAt:number};
export function isNativeIOS():boolean{return Capacitor.getPlatform()==='ios'&&Capacitor.isNativePlatform()}
export async function enableNativeNotifications():Promise<'granted'|'denied'|'not-native'>{
 if(!isNativeIOS())return 'not-native';
 const result=await LocalNotifications.requestPermissions();return result.display==='granted'?'granted':'denied';
}

// Native iOS only; browser view provides in-app alerts but never promises background push.
// Serialized scheduling reduces races while the user is typing.
let queue:Promise<void>=Promise.resolve();
export function syncNativeDraftNotifications(drafts:DraftReminder[],enabled:boolean):Promise<void>{
 if(!isNativeIOS())return Promise.resolve();
 queue=queue.catch(()=>undefined).then(async()=>{
  const pending=await LocalNotifications.getPending();
  const ours=pending.notifications.filter(n=>n.id>=800000000&&n.id<1700000000).map(n=>({id:n.id}));
  if(ours.length)await LocalNotifications.cancel({notifications:ours});
  if(!enabled)return;
  const permission=await LocalNotifications.checkPermissions();if(permission.display!=='granted')return;
  const now=Date.now();
  // iOS may limit the number of pending local notifications. Schedule
  // the 50 nearest *valid* draft deadlines and never expose worker data.
  const byNotificationId=new Map<number,{id:number;due:number}>();
  for(const draft of drafts){
   if(typeof draft.id!=='string'||!draft.id||!Number.isFinite(draft.updatedAt))continue;
   const due=reminderDueAt(draft.updatedAt);
   if(!Number.isFinite(due)||due<=now+1000)continue;
   const id=notificationId(draft.id),previous=byNotificationId.get(id);
   if(!previous||due<previous.due)byNotificationId.set(id,{id,due});
  }
  const notifications=[...byNotificationId.values()].sort((a,b)=>a.due-b.due||a.id-b.id).slice(0,50).map(d=>({
   id:d.id,title:'DANPER Salud',
   body:'Tienes una atención pendiente por completar.',
   schedule:{at:new Date(d.due)},
   extra:{kind:'danper-draft-reminder'}
  }));
  if(notifications.length)await LocalNotifications.schedule({notifications});
 });
 return queue;
}
