import {normalizeDni,type WorkerRecord} from './workerRules';
import {reviewOfficialRoster,type OfficialRosterReview} from './officialRosterReview';

/**
 * Official roster is a view of existing local workers, not a destructive purge.
 * No encounters, allergies, medicines, stock or archived worker records change.
 */
export type OperationalStatus='official'|'verified'|'excluded'|'pending';
export type OperationalWorker=WorkerRecord & {rosterStatus?:OperationalStatus};
export type RosterActivation={
 workers:OperationalWorker[];
 review:OfficialRosterReview;
 officialCount:number;
 manualVerifiedCount:number;
 excludedCount:number;
};
export function officialRosterActive(rows:readonly OperationalWorker[]):boolean{
 return rows.some(w=>w.rosterStatus==='official');
}
/** After activation, historical encounters never repopulate worker search. */
export function searchableWorkers<W extends OperationalWorker>(roster:readonly W[],encounterWorkers:readonly W[]=[]):W[]{
 const active=officialRosterActive(roster);
 const byDni=new Map<string,W>();
 if(!active)for(const row of encounterWorkers)if(normalizeDni(row.dni)===row.dni)byDni.set(row.dni,row);
 for(const row of roster){
  if(normalizeDni(row.dni)!==row.dni)continue;
  if(!active||row.rosterStatus==='official'||row.rosterStatus==='verified')byDni.set(row.dni,row);
 }
 return [...byDni.values()];
}
/** Keep excluded records intact for review/recovery; only mark membership. */
export function prepareOfficialRoster(current:readonly OperationalWorker[],official:readonly WorkerRecord[],linkedDnis:readonly string[]=[]):RosterActivation{
 const review=reviewOfficialRoster([...current],[...official],linkedDnis);
 const previousOfficial=current.filter(w=>w.rosterStatus==='official').length;
 // A likely incomplete subsequent workbook cannot silently displace a live official roster.
 if(previousOfficial>=100&&official.length<Math.ceil(previousOfficial*0.8))
  throw Error('El nuevo Excel contiene menos del 80 % de los trabajadores del padrón oficial anterior. No se aplicará un archivo posiblemente incompleto.');
 const reference=new Map(official.map(row=>[row.dni,row]));
 const present=new Set<string>();
 const workers:OperationalWorker[]=current.map(row=>{
  const replacement=reference.get(row.dni);
  if(replacement){
   present.add(row.dni);
   // Authoritative identity comes from PERSONAL, not from mixed demo records.
   // Retain only explicitly saved local corrections to location/job fields,
   // while official identity and DNI still come from the imported roster.
   const corrected=typeof row.localCorrectionAt==='number'&&Number.isSafeInteger(row.localCorrectionAt)&&row.localCorrectionAt>0;
   return {...replacement,source:corrected?'manual' as const:'imported' as const,
    rosterStatus:'official' as const,
    ...(corrected?{area:row.area||replacement.area,labor:row.labor||replacement.labor,
      site:row.site||replacement.site,localCorrectionAt:row.localCorrectionAt}:{})};
  }
  // Manual verification is only trusted if explicitly performed AFTER this feature exists.
  return {...row,rosterStatus:row.rosterStatus==='verified'?'verified' as const:'excluded' as const};
 });
 for(const row of official)if(!present.has(row.dni))
  workers.push({...row,source:'imported',rosterStatus:'official'});
 const officialCount=workers.filter(w=>w.rosterStatus==='official').length;
 const manualVerifiedCount=workers.filter(w=>w.rosterStatus==='verified').length;
 const excludedCount=workers.filter(w=>w.rosterStatus==='excluded').length;
 if(officialCount!==official.length||workers.length!==current.length+official.length-review.matchingDni)
  throw Error('El padrón propuesto no supera la comprobación de integridad. No se modificará nada.');
 return {workers,review,officialCount,manualVerifiedCount,excludedCount};
}
