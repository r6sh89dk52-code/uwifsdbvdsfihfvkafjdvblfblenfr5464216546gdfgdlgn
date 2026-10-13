// DANPER v0.15 - official ten-sheet workbook export plan
// Operates with fictitious demo data only. Material codes must be digits.
export const AMBULATORY_COLUMNS=30;
export function officialCode(code:string):boolean{return /^\d+$/.test(code)}
export function excelDate(date:string):number{return Math.round((Date.parse(date+'T00:00:00Z')-Date.UTC(1899,11,30))/86400000)}
