// Pure scheduling rules. Never include worker identifiers in notification content.
export const DRAFT_REMINDER_MS=60*60*1000;
export type DraftTimestamp={status?:string;updatedAt:number};
export function reminderDueAt(updatedAt:number):number {return updatedAt+DRAFT_REMINDER_MS}
export function draftIsMeaningful(a:{worker?:{dni?:string;name?:string};diagnosis?:string;items?:unknown[];standaloneProcedures?:unknown[]}):boolean{
 return Boolean(a.worker?.dni?.trim()||a.worker?.name?.trim()||a.diagnosis?.trim()||(a.items?.length??0)>0||(a.standaloneProcedures?.length??0)>0)
}
export function pendingDraftCount(drafts:DraftTimestamp[],now:number):number{
 return drafts.filter(x=>x.status==='draft'&&Number.isFinite(x.updatedAt)&&reminderDueAt(x.updatedAt)<=now).length
}
export function notificationId(id:string):number{
 let hash=2166136261;for(const char of id){hash^=char.charCodeAt(0);hash=Math.imul(hash,16777619)}
 return 800000000+(hash>>>0)%900000000;
}
