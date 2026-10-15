/**
 * DANPER v0.21.10 — locally derived notification center.
 * Never writes to or modifies clinical, worker or stock records.
 */
import {countPhysicalUnits,type StockLot} from './inventoryRules';
import {reminderDueAt} from './draftRules';

export type NoticeRoute='history'|'kardex';
export type NoticeKind='draft'|'expired'|'expiry';
export type AppNotice={
 id:string;kind:NoticeKind;route:NoticeRoute;
 title:string;description:string;at:number;severity:'urgent'|'warning';
};
export type AttentionForNotices={id:string;status:string;updatedAt:number};

/** Date-only comparisons use local calendar dates, not UTC midnight on the iPhone. */
export function localDayNumber(timestamp:number):number{
 const d=new Date(timestamp);
 return Math.floor(Date.UTC(d.getFullYear(),d.getMonth(),d.getDate())/86400000);
}
export function expiryDayNumber(value:string):number|null{
 if(!/^\d{4}-\d{2}-\d{2}$/.test(value))return null;
 const [y,m,d]=value.split('-').map(Number);
 const utc=Date.UTC(y,m-1,d),check=new Date(utc);
 if(check.getUTCFullYear()!==y||check.getUTCMonth()!==m-1||check.getUTCDate()!==d)return null;
 return Math.floor(utc/86400000);
}
export function daysUntilExpiry(expires:string,now:number):number|null{
 const end=expiryDayNumber(expires);return end===null?null:end-localDayNumber(now);
}
export function activeStockLot(lot:StockLot):boolean{
 return countPhysicalUnits(lot)>0;
}
export function buildAppNotices(attentions:readonly AttentionForNotices[],lots:readonly StockLot[],now:number):AppNotice[]{
 const notices:AppNotice[]=[];
 for(const a of attentions){
  if(a.status!=='draft'||!Number.isFinite(a.updatedAt)||reminderDueAt(a.updatedAt)>now)continue;
  notices.push({id:'draft:'+a.id,kind:'draft',route:'history',title:'Atención pendiente',
   description:'Hay un borrador sin completar desde hace al menos una hora.',
   at:reminderDueAt(a.updatedAt),severity:'warning'});
 }
 for(const lot of lots){
  if(!activeStockLot(lot))continue;
  const days=daysUntilExpiry(lot.expires,now);
  if(days===null||days>30)continue;
  const expired=days<0;
  notices.push({id:'expiry:'+lot.id,kind:expired?'expired':'expiry',route:'kardex',
   title:expired?'Lote vencido':days===0?'Lote vence hoy':'Lote próximo a vencer',
   description:lot.name+' · '+(lot.lot||'sin número de lote')+' · '+(expired?'Venció hace '+(-days)+' día(s)':days===0?'Vence hoy':'Vence en '+days+' día(s)'),
   at:now,severity:expired||days<=7?'urgent':'warning'});
 }
 return notices.sort((a,b)=>(a.severity==='urgent'?0:1)-(b.severity==='urgent'?0:1)||a.at-b.at||a.id.localeCompare(b.id));
}

/** Schedule the single seven-day advance notice at 09:00 on the device's local clock. */
export function expiryReminderAt(expires:string,now:number):number|null{
 if(expiryDayNumber(expires)===null)return null;
 const [y,m,d]=expires.split('-').map(Number);
 const at=new Date(y,m-1,d-7,9,0,0,0).getTime();
 return at>now+1000?at:null;
}
export function expiryNotificationId(expires:string):number{
 let hash=2166136261;
 for(const c of expires){hash^=c.charCodeAt(0);hash=Math.imul(hash,16777619)}
 return 1700000000+(hash>>>0)%300000000;
}
export const LOCAL_NOTICE_LIMIT=56; // iOS has a pending-request limit; leave headroom.
