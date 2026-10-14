import {type KardexCatalogProduct} from './kardexCatalog';
export function isIndividualNursingProduct(p:Pick<KardexCatalogProduct,'group'>):boolean {
 return ['TABLETAS','AMPOLLAS','JERINGAS'].includes(p.group);
}
export function stripDateInput(v:string):string {
 return v.replace(/\D/g,'').slice(0,8);
}
/** DD/MM/AAAA masks digits on mobile, without relying on iOS date picker. */
export function formatDateInput(v:string):string {
 const d=stripDateInput(v);
 if(d.length<=2)return d;
 if(d.length<=4)return d.slice(0,2)+'/'+d.slice(2);
 return d.slice(0,2)+'/'+d.slice(2,4)+'/'+d.slice(4);
}
/** Supports DDMMYY (20YY) and DDMMYYYY; invalid day/month/year is rejected. */
export function parseDateInput(v:string):string|null {
 const d=stripDateInput(v);
 if(d.length!==6&&d.length!==8)return null;
 const day=Number(d.slice(0,2)),month=Number(d.slice(2,4));
 const year=Number(d.length===6?'20'+d.slice(4,6):d.slice(4,8));
 if(year<2000||year>2099||month<1||month>12||day<1||day>31)return null;
 const check=new Date(Date.UTC(year,month-1,day));
 if(check.getUTCFullYear()!==year||check.getUTCMonth()!==month-1||check.getUTCDate()!==day)return null;
 return String(year)+'-'+String(month).padStart(2,'0')+'-'+String(day).padStart(2,'0');
}
export function isoToDateInput(iso:string):string {
 const match=/^(\d{4})-(\d{2})-(\d{2})$/.exec(iso);
 return match?match[3]+'/'+match[2]+'/'+match[1]:'';
}
