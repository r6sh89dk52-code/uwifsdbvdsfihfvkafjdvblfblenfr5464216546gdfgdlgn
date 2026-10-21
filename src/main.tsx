import React,{useEffect,useLayoutEffect,useMemo,useRef,useState} from 'react';import{createRoot}from'react-dom/client';
import{Activity,AlertTriangle,ArrowLeft,Bell,Check,ChevronDown,ChevronLeft,ChevronRight,ChevronUp,ClipboardList,Clock,FileClock,Home,Plus,Settings,ShieldAlert,Sun,Trash2,Users,UserPlus,X}from'lucide-react';import products from './products.json';import guias from './guias.json';import diagnoses from './diagnoses.json';import DanperBrandLogo from './DanperBrandLogo';import {shouldOfferWorkerRegistration} from './workerDiscovery';
import {buildWorkerSearchIndex,paginateIndexedWorkers} from './workerSearchIndex';import OfficialAreaField from './OfficialAreaField';import {DANPER_WORKSITES,validDanperWorksite,workerDetailsMissing} from './danperWorksites';import {canDeleteUnlinkedAttention} from './safeAttentionDeletion';import PersonalImporter from './PersonalImporter';import BackupSettingsPanel from './BackupSettingsPanel';import ClinicalMigrationGate from './ClinicalMigrationGate';import FreshStartPanel from './FreshStartPanel';import {inferProcedure,procedureDetail} from './procedureRules';import {type WorkerRecord} from './workerRules';import {officialRosterActive,searchableWorkers,type OperationalWorker} from './operationalRoster';import {medicationAllergyMatches} from './allergyRules';import {draftIsMeaningful, reminderDueAt, pendingDraftCount} from './draftRules';import {isNativeMobile,enableNativeNotifications,syncNativeDraftNotifications} from './nativeReminders';import {loadDemoSnapshot,writeDemoSnapshot,ClinicalMigrationRequiredError,isNativeSecureStore,readLegacyDemoSnapshot,workerVaultRecoveryRequired,type DemoSnapshot} from './secureDemoStore';import {restoreMissingWorkerVault} from './privateWorkerVault';import KardexWorkspace from './KardexWorkspace';import AmbulatoryExportPanel from './AmbulatoryExportPanel';import {validateReconciliationEvents,type ReconciliationEvent} from './ambulatoryReconciliation';import {validateMappingEvents,validateDeliveryIncidents,type CatalogMappingEvent,type DeliveryIncident} from './reconciliationRules';import {validateStockLots} from './inventoryRules';import {validateStockMovements,type StockLedger} from './kardexMovements';import {finalizeVisitAndPlanStock,type InVisitPhysicalUse} from './automaticClinicalDispensing';import {ClinicalStockChoice} from './ClinicalStockChoice';import {feedback,hapticsEnabled,setHapticsEnabled} from './nativeHaptics';import './style.css';import './visualRefresh.css';import './attentionStepper.css';import './stageB.css';import './diagnosisKeyboard.css';import './cohesiveExperience.css';import './stageC.css';import './visualPolish.css';import './workerAndReportClarity.css';import './workerOrganization.css';import {suggestionMaxHeight,suggestionScrollDelta} from './diagnosisKeyboardLayout';import {findFirstIncompleteStage,findFirstInvalidStage,type ClinicalStage,type ClinicalFieldIssue,type ClinicalValidationContext} from './attentionStepValidation';import appMetadata from '../package.json';
type AllergyStatus='unknown'|'none'|'known';type AllergyRecord={status:AllergyStatus;substances:string;updatedAt:number};type Product={code:string;name:string;unit:string};type Item={id:string;code:string;name:string;unit:string;quantity:number;procedure:string;physicalUse?:InVisitPhysicalUse};type Worker=WorkerRecord;type Attention={id:string;worker:Worker;date:string;time:string;category:string;system:string;segment:string;diagnosis:string;items:Item[];permission:string;workStatus:string;permissionTime:string;blueBandage:boolean;returned:boolean;photoSent:boolean;responsible:string;responsibleDni:string;status:'draft'|'saved';updatedAt:number;originId?:string;standaloneProcedures?:string[]};
const RESPONSIBLE='Felipe Azcárate Silva';const RESPONSIBLE_DNI='74958455';const emptyWorker:Worker={dni:'',name:'',area:'',labor:'',sex:'',age:'',ubigeo:'',site:''};const today=()=>{const d=new Date();return `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`};const now=()=>new Date().toTimeString().slice(0,5);const rid=()=>crypto.randomUUID();const mk=():Attention=>({id:rid(),worker:{...emptyWorker},date:today(),time:now(),category:'',system:'',segment:'',diagnosis:'',items:[],permission:'NO',workStatus:'LABORANDO',permissionTime:'',blueBandage:false,returned:false,photoSent:false,responsible:RESPONSIBLE,responsibleDni:RESPONSIBLE_DNI,status:'draft',updatedAt:Date.now(),standaloneProcedures:[]});

const normalize=(v:string)=>v.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('es').trim();

function askForConfirmation(message:string){feedback('warning');return window.confirm(message)}
function App(){const [att,setAtt]=useState<Attention[]>(()=>isNativeSecureStore()?[]:readLegacyDemoSnapshot().attentions as Attention[]);const[page,setPage]=useState<'home'|'register'|'history'|'settings'|'workers'|'kardex'|'ambulatory'>('home');const[active,setActive]=useState<Attention|null>(null);
 // Reset navigation position after the new view has mounted, before paint.
 // No smooth scroll here: on iOS it otherwise looks like each page opens too low.
 useLayoutEffect(()=>{
   const focused=document.activeElement;
   if(focused instanceof HTMLElement&&focused.matches('input,textarea,select'))focused.blur();
   const root=document.scrollingElement;
   if(root)root.scrollTop=0;
   window.scrollTo({top:0,left:0,behavior:'auto'});
   const frame=window.requestAnimationFrame(()=>{
     if(root)root.scrollTop=0;
     window.scrollTo({top:0,left:0,behavior:'auto'});
   });
   return()=>window.cancelAnimationFrame(frame);
 },[page]);const[registerStep,setRegisterStep]=useState<ClinicalStage>(0);const[stepAlert,setStepAlert]=useState<ClinicalFieldIssue[]|null>(null);const stepAlertButton=useRef<HTMLButtonElement|null>(null);const[mode,setMode]=useState<'auto'|'light'|'dark'>('auto');const[hapticsOn,setHapticsOn]=useState(hapticsEnabled);const[savingAttention,setSavingAttention]=useState(false);const[savingWorker,setSavingWorker]=useState(false);const[query,setQuery]=useState('');const[workerQuery,setWorkerQuery]=useState('');const[workerPage,setWorkerPage]=useState(0);
const workerSearchPanelRef=useRef<HTMLElement|null>(null);
const workerPageScrollPending=useRef(false);
const[historyLimit,setHistoryLimit]=useState(60);const[workerForm,setWorkerForm]=useState<Worker|null>(null);const[workerProfileAlert,setWorkerProfileAlert]=useState<{missing:string[];changed:boolean}|null>(null);const[verifiedManualWorker,setVerifiedManualWorker]=useState(false);const[unknownWorkerDni,setUnknownWorkerDni]=useState<string|null>(null);const dismissedUnknownDni=useRef<string|null>(null);const registerWorkerButton=useRef<HTMLButtonElement|null>(null);const[workerReturn,setWorkerReturn]=useState<'home'|'register'>('home');const[editingDni,setEditingDni]=useState<string|null>(null);const[diagnosisSuggestionsVisible,setDiagnosisSuggestionsVisible]=useState(false);const diagnosisInputRef=useRef<HTMLTextAreaElement|null>(null);const diagnosisSuggestionsRef=useRef<HTMLDivElement|null>(null);const[workers,setWorkers]=useState<Worker[]>(()=>isNativeSecureStore()?[]:readLegacyDemoSnapshot().workers as Worker[]);const[ledger,setLedger]=useState<StockLedger>(()=>{
 const snapshot=isNativeSecureStore()?null:readLegacyDemoSnapshot();
 return {lots:snapshot?validateStockLots(snapshot.stockLots):[],movements:snapshot?validateStockMovements(snapshot.stockMovements):[]};
});const[mappings,setMappings]=useState<CatalogMappingEvent[]>(()=>isNativeSecureStore()?[]:validateMappingEvents(readLegacyDemoSnapshot().catalogMappings));const[incidents,setIncidents]=useState<DeliveryIncident[]>(()=>isNativeSecureStore()?[]:validateDeliveryIncidents(readLegacyDemoSnapshot().deliveryIncidents));const[ambulatoryEvents,setAmbulatoryEvents]=useState<ReconciliationEvent[]>(()=>isNativeSecureStore()?[]:validateReconciliationEvents(readLegacyDemoSnapshot().ambulatoryReconciliation));const[showSearch,setShowSearch]=useState(false);const[expandedProductId,setExpandedProductId]=useState<string|null>(null);const[collapsedGroups,setCollapsedGroups]=useState<string[]>([]);const[allergyRecords,setAllergyRecords]=useState<Record<string,AllergyRecord>>(()=>isNativeSecureStore()?{}:readLegacyDemoSnapshot().allergies as Record<string,AllergyRecord>);const[message,setMessage]=useState('');const[autoSavedAt,setAutoSavedAt]=useState<number|null>(null);const[reminderTick,setReminderTick]=useState(Date.now());const[notificationEnabled,setNotificationEnabled]=useState(()=>isNativeSecureStore()?false:readLegacyDemoSnapshot().notifications);const[notificationMessage,setNotificationMessage]=useState('');const activeRef=useRef<Attention|null>(null);const attRef=useRef<Attention[]>([]);const [storageReady,setStorageReady]=useState(!isNativeSecureStore());const[storageFault,setStorageFault]=useState('');const[vaultRecovery,setVaultRecovery]=useState(false);const[recoveryError,setRecoveryError]=useState('');const[migrationRequired,setMigrationRequired]=useState(false);const [storageState,setStorageState]=useState<'loading'|'saved'|'saving'|'error'>(isNativeSecureStore()?'loading':'saved');const snapshotRef=useRef<DemoSnapshot<Attention,Worker,AllergyRecord>>({attentions:att,workers,allergies:allergyRecords,notifications:notificationEnabled,stockLots:ledger.lots,stockMovements:ledger.movements,catalogMappings:mappings,deliveryIncidents:incidents,ambulatoryReconciliation:ambulatoryEvents});
useEffect(()=>{if(!isNativeSecureStore())return;
 let mounted=true;
 void loadDemoSnapshot().then(snapshot=>{
   if(!mounted)return;
   setAtt(snapshot.attentions as Attention[]);attRef.current=snapshot.attentions as Attention[];
   setVaultRecovery(workerVaultRecoveryRequired());
   setWorkers(snapshot.workers as Worker[]);setAllergyRecords(snapshot.allergies as Record<string,AllergyRecord>);
   setLedger({lots:validateStockLots(snapshot.stockLots),movements:validateStockMovements(snapshot.stockMovements)});setMappings(validateMappingEvents(snapshot.catalogMappings));setIncidents(validateDeliveryIncidents(snapshot.deliveryIncidents));setAmbulatoryEvents(validateReconciliationEvents(snapshot.ambulatoryReconciliation));setNotificationEnabled(snapshot.notifications);setStorageReady(true);setStorageState('saved');
 }).catch(error=>{if(mounted){if(error instanceof ClinicalMigrationRequiredError){setMigrationRequired(true);setStorageState('loading')}else{setStorageFault(error instanceof Error?error.message:String(error));setStorageState('error')}}});
 return()=>{mounted=false};
},[]);
useEffect(()=>{attRef.current=att;snapshotRef.current={attentions:att,workers,allergies:allergyRecords,notifications:notificationEnabled,stockLots:ledger.lots,stockMovements:ledger.movements,catalogMappings:mappings,deliveryIncidents:incidents,ambulatoryReconciliation:ambulatoryEvents};
 if(!storageReady||storageFault||vaultRecovery)return;
 setStorageState('saving');
 const timer=window.setTimeout(()=>{
   void writeDemoSnapshot(snapshotRef.current).then(()=>setStorageState('saved')).catch(error=>{
     setStorageFault(error instanceof Error?error.message:'No se pudo guardar en almacenamiento seguro.');setStorageState('error');
   });
 },550);
 return()=>clearTimeout(timer);
},[att,workers,allergyRecords,notificationEnabled,ledger,mappings,incidents,ambulatoryEvents,storageReady,storageFault,vaultRecovery]);
useEffect(()=>{activeRef.current=active},[active]);
useEffect(()=>{const timer=window.setInterval(()=>setReminderTick(Date.now()),30000);return()=>window.clearInterval(timer)},[]);
// Autoguardado tras 650 ms sin escribir. No altera atenciones confirmadas.
useEffect(()=>{if(page!=='register'||!active||active.status!=='draft'||!draftIsMeaningful(active))return;
 const timer=window.setTimeout(()=>{const copy={...active,updatedAt:Date.now()};setAtt(prev=>[copy,...prev.filter(x=>x.id!==copy.id)]);setAutoSavedAt(copy.updatedAt)},650);
 return()=>window.clearTimeout(timer)},[active,page]);
// Guarda sin esperar al temporizador si iOS/navegador oculta o cierra la página.
useEffect(()=>{function flush(){
 if(!storageReady||storageFault||vaultRecovery)return;
 const a=activeRef.current;
 if(a&&a.status==='draft'&&draftIsMeaningful(a)){
   const copy={...a,updatedAt:Date.now()};const updated=[copy,...attRef.current.filter(x=>x.id!==a.id)];
   attRef.current=updated;
   snapshotRef.current={...snapshotRef.current,attentions:updated};
 }
 void writeDemoSnapshot(snapshotRef.current).catch(error=>{
   setStorageFault(error instanceof Error?error.message:'Error al conservar el borrador.');setStorageState('error');
 });
 }
 const onVisibility=()=>{if(document.visibilityState==='hidden')flush()};
 document.addEventListener('visibilitychange',onVisibility);window.addEventListener('pagehide',flush);
 return()=>{document.removeEventListener('visibilitychange',onVisibility);window.removeEventListener('pagehide',flush)};
},[storageReady,storageFault,vaultRecovery]);
useEffect(()=>{if(!storageReady||storageFault||vaultRecovery)return;const drafts=att.filter(a=>a.status==='draft'&&draftIsMeaningful(a)).map(a=>({id:a.id,updatedAt:a.updatedAt}));void syncNativeDraftNotifications(drafts,notificationEnabled).catch(()=>setNotificationMessage('No se pudieron programar avisos nativos. Revisa los permisos del teléfono.'))},[att,notificationEnabled,storageReady,storageFault,vaultRecovery]);
useEffect(()=>{document.documentElement.dataset.theme=mode},[mode]);useEffect(()=>{if(!message)return;const t=setTimeout(()=>setMessage(''),3500);return()=>clearTimeout(t)},[message]);
const workerList=useMemo(()=>searchableWorkers(workers as OperationalWorker[],att.map(a=>a.worker) as OperationalWorker[]).sort((a,b)=>a.name.localeCompare(b.name,'es')),[att,workers]);
// Index once per roster change rather than normalizing thousands of names on each keystroke
// or on every unrelated React state update (important for entry-level Android CPUs).
const workerIndex=useMemo(()=>buildWorkerSearchIndex(workerList),[workerList]);
const workerPageData=useMemo(()=>page==='workers'
 ?paginateIndexedWorkers(workerIndex,workerQuery,workerPage,25)
 :{workers:[] as OperationalWorker[],total:0,page:0,pageCount:0,first:0,last:0},
 [page,workerIndex,workerQuery,workerPage]);
const filteredWorkers=workerPageData.workers;
// Only scroll after a pagination click; never summon the Android keyboard.
useLayoutEffect(()=>{
 if(page!=='workers'||workerForm||!workerPageScrollPending.current)return;
 workerPageScrollPending.current=false;
 workerSearchPanelRef.current?.scrollIntoView({block:'start',behavior:'auto'});
},[page,workerPage,workerForm]);
function changeWorkerPage(delta:number){
 const next=Math.max(0,Math.min(workerPageData.pageCount-1,workerPageData.page+delta));
 if(next===workerPageData.page)return;
 workerPageScrollPending.current=true;
 setWorkerPage(next);
}
const workerByDni=useMemo(()=>new Map(workerList.map(w=>[w.dni,w] as const)),[workerList]);
useEffect(()=>{
 if(page!=='register'||registerStep!==0||!active||active.status==='saved')return;
 const dni=active.worker.dni;
 if(!shouldOfferWorkerRegistration(dni,workerList.map(w=>w.dni),storageReady,dismissedUnknownDni.current))return;
 const timer=window.setTimeout(()=>setUnknownWorkerDni(current=>current===dni?current:dni),500);
 return()=>window.clearTimeout(timer);
},[page,registerStep,active?.worker.dni,active?.status,workerList,storageReady]);
useEffect(()=>{
 if(!unknownWorkerDni)return;
 registerWorkerButton.current?.focus({preventScroll:true});
 function onEscape(e:KeyboardEvent){if(e.key==='Escape'){e.preventDefault();dismissedUnknownDni.current=unknownWorkerDni;setUnknownWorkerDni(null)}}
 window.addEventListener('keydown',onEscape);
 return()=>window.removeEventListener('keydown',onEscape);
},[unknownWorkerDni]);const diagnosisMatches=(diagnoses as string[]).filter(x=>normalize(x).includes(normalize(active?.diagnosis||''))).slice(0,7);
const diagnosisDropdownOpen=page==='register'&&registerStep===1&&diagnosisSuggestionsVisible&&normalize(active?.diagnosis||'').length>=2&&diagnosisMatches.length>0;
useEffect(()=>{
 if(!diagnosisDropdownOpen)return;
 let alive=true;
 const viewport=window.visualViewport;
 function reveal(){
   if(!alive||document.activeElement!==diagnosisInputRef.current)return;
   const popup=diagnosisSuggestionsRef.current;
   if(!popup)return;
   const geometry={height:viewport?.height??window.innerHeight,offsetTop:viewport?.offsetTop??0};
   popup.style.maxHeight=suggestionMaxHeight(geometry.height)+'px';
   const bounds=popup.getBoundingClientRect();
   const delta=suggestionScrollDelta({top:bounds.top,bottom:bounds.bottom},geometry);
   if(delta>1)window.scrollBy({top:delta,behavior:'auto'});
 }
 const frame=window.requestAnimationFrame(reveal);
 const duringKeyboard=window.setTimeout(reveal,160);
 const afterKeyboard=window.setTimeout(reveal,360);
 viewport?.addEventListener('resize',reveal,{passive:true});
 viewport?.addEventListener('scroll',reveal,{passive:true});
 window.addEventListener('resize',reveal,{passive:true});
 return ()=>{
   alive=false;window.cancelAnimationFrame(frame);
   window.clearTimeout(duringKeyboard);window.clearTimeout(afterKeyboard);
   viewport?.removeEventListener('resize',reveal);viewport?.removeEventListener('scroll',reveal);
   window.removeEventListener('resize',reveal);
 };
},[diagnosisDropdownOpen,active?.diagnosis]);

const allergyData=active?.worker.dni?allergyRecords[active.worker.dni]:undefined;const allergyState:AllergyStatus=allergyData?.status||'unknown';const itemGroups=active?.items.reduce<Record<string,Item[]>>((groups,item)=>{const proc=item.procedure||'POR CONFIRMAR';(groups[proc]??=[]).push(item);return groups}, {})||{};const saved=att.filter(a=>a.status==='saved'),drafts=att.filter(a=>a.status==='draft'&&draftIsMeaningful(a));const overdueDrafts=pendingDraftCount(drafts,reminderTick);const week=useMemo(()=>{const d=new Date();const day=(d.getDay()+6)%7;d.setDate(d.getDate()-day);d.setHours(0,0,0,0);return d},[]);const weekCount=saved.filter(a=>new Date(a.date+'T12:00:00')>=week).length;const counted=saved.filter(a=>a.date===today()).length;
// Keep every record in memory and storage: only paginate the visible History cards.
// Loading all 1500+ cards at once makes the phone's WebView stutter while painting.
const sortedHistory=useMemo(()=>[...att].sort((a,b)=>b.updatedAt-a.updatedAt),[att]);
const visibleHistory=page==='history'?sortedHistory.slice(0,historyLimit):[];
// Read-only index for movement-status labels; never changes FEFO, movement or stock logic.
const dispensedHistoryItems=useMemo(()=>{
 const byAttention=new Map<string,Set<string>>();
 for(const movement of ledger.movements){
  const ref=movement.dispenseRef;
  if(!ref?.attentionId||!ref.itemId)continue;
  let items=byAttention.get(ref.attentionId);
  if(!items){items=new Set<string>();byAttention.set(ref.attentionId,items)}
  items.add(ref.itemId);
 }
 return byAttention;
},[ledger.movements]);
const countUnmatchedHistoryItems=(a:Attention)=>a.items.filter(item=>!dispensedHistoryItems.get(a.id)?.has(item.id)).length;
function persist(a:Attention,status:'draft'|'saved'){
 const timestamp=Date.now();const copy={...a,status,updatedAt:timestamp};
 if(status==='saved'&&a.originId){const confirmed={...copy,id:a.originId,originId:undefined};setAtt(prev=>[confirmed,...prev.filter(x=>x.id!==a.id&&x.id!==a.originId)]);setActive(confirmed);return}
 if(status==='draft'&&a.status==='saved'){const draft={...copy,id:rid(),originId:a.id,status:'draft' as const};setAtt(prev=>[draft,...prev]);setActive(draft);return}
 setAtt(prev=>[copy,...prev.filter(x=>x.id!==copy.id)]);setActive(copy)
}
function open(a?:Attention){setWorkerProfileAlert(null);setUnknownWorkerDni(null);dismissedUnknownDni.current=null;setStepAlert(null);feedback('selection');if(page==='register'&&active?.status==='draft'&&draftIsMeaningful(active)&&active.id!==a?.id)persist(active,'draft');const v=a?structuredClone(a):mk();setRegisterStep(0);setActive(v);setQuery('');setShowSearch(false);setExpandedProductId(null);setCollapsedGroups([]);setDiagnosisSuggestionsVisible(false);setPage('register')}
function patch(p:Partial<Attention>){if(!active)return;
 if(active.status==='saved'){setActive({...active,...p,id:rid(),originId:active.id,status:'draft',updatedAt:Date.now()});return}
 setActive({...active,...p})}
async function clearDemoData(){
 if(workers.length||att.length||ledger.lots.length||ledger.movements.length){
  setMessage('No se permite borrar la base de datos mientras tenga registros guardados.');
  feedback('warning');return;
 }
 if(!askForConfirmation('¿Eliminar todos los datos ficticios de prueba? Esta acción no se puede deshacer.'))return;
 const empty:DemoSnapshot<Attention,Worker,AllergyRecord>={attentions:[],workers:[],allergies:{},notifications:false,stockLots:[],stockMovements:[],catalogMappings:[],deliveryIncidents:[],ambulatoryReconciliation:[]};
 activeRef.current=null;attRef.current=[];snapshotRef.current=empty;
 try{await writeDemoSnapshot(empty);
  setActive(null);setAtt([]);setWorkers([]);setAllergyRecords({});setLedger({lots:[],movements:[]});setMappings([]);setIncidents([]);setAmbulatoryEvents([]);setNotificationEnabled(false);
  setMessage('Datos ficticios eliminados del almacenamiento actual.');
 }catch(error){
  setStorageFault(error instanceof Error?error.message:'No fue posible eliminar los datos protegidos.');
  setStorageState('error');
 }
}
async function deleteSavedAttention(attentionId:string){
 if(savingAttention||savingWorker)return;
 const target=att.find(a=>a.id===attentionId&&a.status==='saved');
 if(!target)return;
 const guard=canDeleteUnlinkedAttention(target.id,target.status,ledger.movements);
 if(!guard.allowed){setMessage(guard.reason);feedback('warning');return}
 if(!askForConfirmation('¿Eliminar definitivamente esta atención de prueba y sus borradores de corrección? Se excluirá de los reportes y no podrá recuperarse sin un respaldo externo.'))return;
 const remaining=att.filter(a=>a.id!==attentionId&&a.originId!==attentionId);
 const snapshot={...snapshotRef.current,attentions:remaining};
 setSavingAttention(true);setStorageState('saving');
 try{
  await writeDemoSnapshot(snapshot);
  snapshotRef.current=snapshot;setAtt(remaining);
  if(active&&(active.id===attentionId||active.originId===attentionId))setActive(null);
  setStorageState('saved');setMessage('Atención de prueba eliminada. No se modificó el Kardex.');feedback('success');
 }catch{
  setStorageState('error');setMessage('No se pudo eliminar la atención. Se conservaron los datos para reintentar.');feedback('error');
 }finally{setSavingAttention(false)}
}
function deleteDraft(draftId:string){if(!askForConfirmation('¿Eliminar este borrador ficticio? Esta acción no se puede deshacer.'))return;setAtt(prev=>prev.filter(x=>x.id!==draftId));if(active?.id===draftId)setActive(null);setMessage('Borrador de prueba eliminado.');}
async function activateIOSNotices(){try{const result=await enableNativeNotifications();if(result==='granted'){setNotificationEnabled(true);setNotificationMessage('Notificaciones locales habilitadas en el teléfono.')}else setNotificationMessage(result==='not-native'?'Esta opción se habilita en las apps iOS y Android; el navegador muestra avisos internos.':'El sistema no concedió permiso de notificaciones.')}catch{setNotificationMessage('No fue posible solicitar permisos de notificaciones.')}}

function updateAllergyStatus(status:AllergyStatus){const dni=active?.worker.dni||'';if(!/^\d{8}$/.test(dni)){setMessage('Primero selecciona un trabajador con DNI válido.');return}setAllergyRecords(prev=>({...prev,[dni]:{status,substances:status==='known'?(prev[dni]?.status==='known'?prev[dni].substances:''):'',updatedAt:Date.now()}}))}
function updateAllergySubstances(substances:string){const dni=active?.worker.dni||'';if(!/^\d{8}$/.test(dni))return;setAllergyRecords(prev=>({...prev,[dni]:{status:'known',substances,updatedAt:Date.now()}}))}
function toggleProduct(id:string){setExpandedProductId(current=>current===id?null:id)}
function updateProduct(id:string,patchItem:Partial<Item>){if(!active)return;patch({items:active.items.map(item=>item.id===id?{...item,...patchItem}:item)})}
function clinicalValidationContext():ClinicalValidationContext{return {validCategories:guias.H,validSystems:guias.P,rosterRequired:officialRosterActive(workers as OperationalWorker[]),workerInRoster:workerList.some(w=>w.dni===active?.worker.dni),rosterException:Boolean(active?.originId||active?.status==='saved'),allergiesReviewed:Boolean(allergyData),allergyStatus:allergyState,allergySubstances:allergyData?.substances||''}}
function raiseStepIssues(issues:ClinicalFieldIssue[]){if(!issues.length)return false;setRegisterStep(issues[0].step);setStepAlert(issues);feedback('warning');return true}
function workerNeedsProfileSave(w:Worker){
 const savedWorker=workers.find(p=>p.dni===w.dni);
 const missing=workerDetailsMissing(w);
 if(!validDanperWorksite(w.site))missing.push('Sede');
 const changed=Boolean(savedWorker&&(['name','area','labor','sex','age','ubigeo','site'] as const).some(field=>String(savedWorker[field]??'').trim()!==String(w[field]??'').trim()));
 return {missing,changed:changed||!savedWorker};
}
function selectRegisterStep(step:ClinicalStage){if(!active)return;
 if(registerStep===0&&step>0&&active.status!=='saved'&&/^\d{8}$/.test(active.worker.dni)&&active.worker.name.trim()){
  const profile=workerNeedsProfileSave(active.worker);
  if(profile.missing.length||profile.changed){setWorkerProfileAlert(profile);feedback('warning');return}
 }
 const issues=findFirstIncompleteStage(registerStep,step,active,clinicalValidationContext());
 if(raiseStepIssues(issues))return;setStepAlert(null);setRegisterStep(step);feedback('selection');window.scrollTo({top:0,behavior:'auto'});
}
function editActiveWorkerProfile(){if(!active)return;
 setWorkerProfileAlert(null);openWorkers('register');
 const existing=workers.find(w=>w.dni===active.worker.dni);
 setVerifiedManualWorker(false);
 setWorkerForm({...emptyWorker,...existing,...active.worker});
 setEditingDni(existing?.dni||null);
}
function dismissStepAlert(){const first=stepAlert?.[0];setStepAlert(null);if(first){window.requestAnimationFrame(()=>{const container=document.querySelector('[data-clinical-field="'+first.field+'"]');const el=container?.querySelector('input,select,textarea,button')||container;if(el instanceof HTMLElement){el.focus({preventScroll:true});el.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'center'})}})}}
useEffect(()=>{if(!stepAlert)return;stepAlertButton.current?.focus();function onEscape(e:KeyboardEvent){if(e.key==='Escape'){e.preventDefault();setStepAlert(null)}}window.addEventListener('keydown',onEscape);return()=>window.removeEventListener('keydown',onEscape)},[stepAlert]);
function openWorkers(from:'home'|'register'){setVerifiedManualWorker(false);setWorkerProfileAlert(null);setUnknownWorkerDni(null);feedback('selection');if(from==='register'&&active?.status==='draft'&&draftIsMeaningful(active))persist(active,'draft');setWorkerReturn(from);setWorkerForm(null);setEditingDni(null);setWorkerQuery('');setWorkerPage(0);setPage('workers')}
function goToPage(destination:'home'|'history'|'settings'|'workers'|'kardex'|'ambulatory'){feedback('selection');if(page==='register'&&active?.status==='draft'&&draftIsMeaningful(active))persist(active,'draft');setPage(destination)}
function startWorker(known?:Worker){setVerifiedManualWorker(false);setEditingDni(known?.dni||null);setWorkerForm(known?{...known}:{...emptyWorker,dni:workerReturn==='register'?(active?.worker.dni||''):''})}
async function saveWorker(){
 if(!workerForm||savingWorker)return;
 const w={...workerForm,dni:workerForm.dni.trim(),name:workerForm.name.trim(),area:workerForm.area.trim(),labor:workerForm.labor.trim(),site:workerForm.site||''};
 if(w.site&&!validDanperWorksite(w.site)){setMessage('Selecciona una de las dos sedes oficiales.');feedback('warning');return}
 if(workerReturn==='register'&&(workerDetailsMissing(w).length||!validDanperWorksite(w.site))){setMessage('Antes de regresar a la atención, completa área, labor y sede del trabajador.');feedback('warning');return}
 if(!/^\d{8}$/.test(w.dni)){setMessage('El DNI debe contener 8 dígitos.');feedback('warning');return}
 if(!w.name){setMessage('Ingresa apellidos y nombres.');feedback('warning');return}
 if(workerList.some(x=>x.dni===w.dni&&x.dni!==editingDni)){setMessage('Este DNI ya existe. Selecciónalo o edita su ficha.');feedback('warning');return}
 const previous=workers.find(x=>x.dni===editingDni);
 const existingStatus=(previous as OperationalWorker|undefined)?.rosterStatus;
 const verificationRequired=workerReturn==='register'&&officialRosterActive(workers as OperationalWorker[])&&!['official','verified'].includes(existingStatus||'');
 if(verificationRequired&&!verifiedManualWorker){setMessage('Verifica expresamente la identidad y vinculación laboral antes de registrar a un trabajador fuera del padrón oficial.');feedback('warning');return}
 const updated=[...workers.filter(x=>x.dni!==editingDni&&x.dni!==w.dni),{...w,source:'manual' as const,localCorrectionAt:Date.now(),rosterStatus:existingStatus==='official'?'official' as const:existingStatus==='verified'||(verificationRequired&&verifiedManualWorker)?'verified' as const:'pending' as const}];
 const snapshot={...snapshotRef.current,workers:updated};
 setSavingWorker(true);setStorageState('saving');
 try{
  await writeDemoSnapshot(snapshot);
  snapshotRef.current=snapshot;setWorkers(updated);setWorkerForm(null);setEditingDni(null);setVerifiedManualWorker(false);
  if(workerReturn==='register'&&active){patch({worker:{...w}});setWorkerProfileAlert(null);setPage('register')}
  setStorageState('saved');setMessage('Trabajador guardado en el padrón cifrado.');feedback('success');
 }catch{
  setStorageState('error');setMessage('No se pudo guardar el trabajador. Comprueba el almacenamiento y vuelve a intentar.');feedback('error');
 }finally{setSavingWorker(false)}
}
function selectWorker(w:Worker){setUnknownWorkerDni(null);dismissedUnknownDni.current=w.dni;if(workerReturn==='register'&&active){patch({worker:{...w}});setWorkerProfileAlert(null);setPage('register');setMessage('Trabajador seleccionado.')}else{setWorkerForm({...w});setEditingDni(w.dni)}}

async function save(){
 if(!active||savingAttention)return;
 if(raiseStepIssues(findFirstInvalidStage(active,clinicalValidationContext())))return;
 if(!/^\d{4}-\d{2}-\d{2}$/.test(active.date)||!/^\d{2}:\d{2}$/.test(active.time)){setRegisterStep(1);setMessage('Confirma fecha y hora válidas.');feedback('warning');return}
 if(active.items.some(i=>!Number.isInteger(i.quantity)||i.quantity<0||!i.procedure)){setRegisterStep(2);setMessage('Revisa la cantidad y confirma el procedimiento de cada producto.');feedback('warning');return}
 if(!/^\d{8}$/.test(active.worker.dni)){setRegisterStep(0);setMessage('Ingresa un DNI de 8 dígitos.');feedback('warning');return}
 if(!active.worker.name.trim()){setRegisterStep(0);setMessage('Ingresa el nombre del trabajador.');feedback('warning');return}
 if(officialRosterActive(workers as OperationalWorker[])&&!workerList.some(w=>w.dni===active.worker.dni)&&!active.originId&&active.status!=='saved'){setRegisterStep(0);setMessage('El DNI no figura en el padrón real confirmado. Verifica el Excel PERSONAL antes de guardar una atención nueva.');feedback('warning');return}
 if(!active.diagnosis.trim()){setRegisterStep(1);setMessage('Ingresa el diagnóstico presuntivo o descripción.');feedback('warning');return}
 const confirmed:Attention={...active,id:active.originId||active.id,originId:undefined,status:'saved',updatedAt:Date.now()};
 const next=[confirmed,...att.filter(x=>x.id!==active.id&&x.id!==confirmed.id)];
 setSavingAttention(true);setStorageState('saving');
 try{
  // A correction must never erase or alter an already-linked movement.
  const previousSaved=att.find(a=>a.status==='saved'&&a.id===confirmed.id);
  for(const move of ledger.movements.filter(m=>m.dispenseRef?.attentionId===confirmed.id)){
   const ref=move.dispenseRef!;
   const item=confirmed.items.find(i=>i.id===ref.itemId&&i.code===ref.clinicalCode&&
     i.name===ref.clinicalName&&i.unit===ref.clinicalUnit&&i.quantity===ref.clinicalQuantity);
   const original=previousSaved?.items.find(i=>i.id===ref.itemId);
   if(!item||!original||JSON.stringify(item.physicalUse??null)!==JSON.stringify(original.physicalUse??null))
    throw Error('No se puede modificar un producto con salidas físicas vinculadas a uno o varios lotes. Se requiere corrección auditada.');
  }
  // Never retroactively auto-consume for an attention already saved previously,
  // including same-day corrections or double-taps after a successful save.
  const alreadySaved=att.some(a=>a.status==='saved'&&a.id===confirmed.id);
  const result=alreadySaved?{
   ledger,deducted:0,pending:confirmed.items.filter(i=>!ledger.movements.some(m=>
    m.dispenseRef?.attentionId===confirmed.id&&m.dispenseRef.itemId===i.id)).length
  }:finalizeVisitAndPlanStock(ledger,confirmed,confirmed.updatedAt);
  // Single encrypted snapshot: visit, physical stock and audit movements.
  const snapshot={...snapshotRef.current,attentions:next,stockLots:result.ledger.lots,stockMovements:result.ledger.movements};
  await writeDemoSnapshot(snapshot);
  snapshotRef.current=snapshot;setAtt(next);setLedger(result.ledger);setActive(confirmed);setPage('history');
  setStorageState('saved');
  setMessage('Atención finalizada: '+result.deducted+' descuento(s) automáticos, '+result.pending+' consumo(s) con inventario pendiente. No necesitas confirmar en otro módulo.');
  feedback(result.pending?'warning':'success');
 }catch(error){
  setStorageState('error');setMessage(error instanceof Error?error.message:'No se guardó la atención. Comprueba el almacenamiento.');feedback('error');
 }finally{setSavingAttention(false)}
}
function leave(){if(active&&active.status==='draft'&&draftIsMeaningful(active))persist(active,'draft');setPage('home');setActive(null)}
const historyWorker=workerList.find(w=>w.dni&&w.dni===active?.worker.dni);
const matches=(products as Product[]).filter(p=>p.name.toLocaleLowerCase('es').includes(query.toLocaleLowerCase('es'))).slice(0,12);
function addProduct(p:Product){if(!active)return;
const matches=allergyState==='known'?medicationAllergyMatches(p.name,allergyData?.substances||''):[];
if(matches.length&&!window.confirm('ADVERTENCIA: existe coincidencia textual con una alergia registrada ('+matches.join(', ')+'). Esta comprobación es incompleta y NO sustituye verificación clínica. ¿Deseas continuar agregando el producto al registro de prueba?'))return;
const result=inferProcedure(p,active.items,active.standaloneProcedures||[]);const id=rid();patch({items:[...active.items,{id,code:p.code,name:p.name,unit:p.unit,quantity:1,procedure:result.procedure}]});setQuery('');setShowSearch(false);setExpandedProductId(result.needsConfirmation?id:null);setCollapsedGroups(v=>v.filter(x=>x!==(result.procedure||'POR CONFIRMAR')));
if(result.needsConfirmation)setMessage('Selecciona el procedimiento correcto para el insumo agregado.');else if(matches.length)setMessage('Atención: revisa la alergia y confirma la indicación antes de administrar.');} 
function toggleStandaloneProcedure(procedure:string){if(!active)return;const existing=active.standaloneProcedures||[];patch({standaloneProcedures:existing.includes(procedure)?existing.filter(v=>v!==procedure):[...existing,procedure]})}

const freq=(a:Attention)=>{const others=saved.filter(x=>x.id!==a.id&&x.date===a.date&&x.worker.dni===a.worker.dni&&((x.time||'')<=(a.time||'')));return['PRIMERA','SEGUNDA','TERCERA','CUARTA','QUINTA'][others.length]||'REVISAR'};
if(migrationRequired)return <ClinicalMigrationGate/>;
if(vaultRecovery)return <div className="app"><main className="secureLoading vaultRecoveryPage">
 <h1>Recuperación del padrón</h1>
 <p role="alert">No se encuentra el archivo cifrado de trabajadores al que apunta Keychain. Esto puede suceder después de cambiar o reinstalar el contenedor de archivos del iPhone. <strong>El resto del almacenamiento no se ha limpiado.</strong></p>
 <p>No se ha creado un padrón vacío automáticamente. Para continuar, restaura desde un Excel con hoja PERSONAL; los archivos no se envían a GitHub.</p>
 <PersonalImporter current={workers} onApply={async updated=>{
  await restoreMissingWorkerVault(updated);setWorkers(updated);setVaultRecovery(false);setRecoveryError('');
  setMessage('Padrón cifrado restaurado. Comprueba los trabajadores.');
 }}/>
 <section className="panel"><h3>Continuar sin trabajadores anteriores</h3>
 <p>Solo si no necesitas recuperar el antiguo padrón, puedes confirmar uno vacío. La referencia de Keychain anterior se conservará, pero <strong>los trabajadores antiguos no reaparecerán</strong>.</p>
 <button type="button" className="workerSecondary wide" onClick={()=>{
  if(!askForConfirmation('Se iniciará un padrón vacío. Esto no recuperará los trabajadores anteriores. ¿Confirmas?'))return;
  void restoreMissingWorkerVault([]).then(()=>{setWorkers([]);setVaultRecovery(false);setRecoveryError('')}).catch(e=>setRecoveryError(e instanceof Error?e.message:String(e)))
 }}>Continuar con padrón vacío (confirmar)</button>
 </section>
 {recoveryError&&<p className="importError" role="alert">{recoveryError}</p>}<FreshStartPanel/>
 <p className="hint">No desinstales la aplicación ni elimines sus datos. Si no tienes una copia del padrón anterior, consulta antes de confirmar el inicio vacío.</p>
 </main></div>;
if(!storageReady||storageFault)return <div className="app"><main className="secureLoading"><h1>Almacenamiento local</h1><p>{storageFault?'No se pudo acceder al almacenamiento seguro. No se han borrado ni sobrescrito registros.':'Recuperando registros protegidos del iPhone…'}</p>{storageFault&&<><p role="alert">{storageFault}</p><FreshStartPanel/></>}</main></div>;
return <div className={'app page-'+page+(page==='register'?' registerOpen':'')}><header className="brand"><div className="brandmark"><DanperBrandLogo/><small>SALUD MÓVIL</small></div><button className="headIcon" onClick={()=>goToPage('settings')} aria-label="Ajustes"><Settings size={22}/></button></header><main>
{page==='home'&&<><div className="greeting"><div><div className="eyebrow">DEPARTAMENTO DE SALUD</div><h1>Bienvenido, Felipe</h1><p>Departamento de Salud · Registro ambulatorio local</p></div><div className="pulse"><Activity/></div></div><details className="warning demoNotice"><summary><ShieldAlert size={16}/> Modo de prueba · Solo datos ficticios</summary><p>PROTOTIPO DE PRUEBA: utilizar solo datos ficticios. {isNativeSecureStore()?'Almacenamiento de prueba protegido con Keychain; pendiente validación clínica y base SQLite cifrada.':'En navegador, los datos no están cifrados.'}</p></details>{overdueDrafts>0&&<button type="button" className="pendingAlert" onClick={()=>goToPage('history')}><Bell size={19}/><span><strong>{overdueDrafts} borrador{overdueDrafts===1?'':'es'} pendiente{overdueDrafts===1?'':'s'} más de una hora</strong><small>Revisar y completar atenciones de prueba</small></span><ChevronRight size={16}/></button>}<button className="hero" onClick={()=>open()}><div><span>ACCESO RÁPIDO</span><h2>Nueva atención</h2><p>Registra con menos pasos</p></div><Plus size={28}/></button><div className="stats"><div><strong>{counted}</strong><span>Hoy</span></div><div><strong>{weekCount}</strong><span>Esta semana</span></div><div><strong>{drafts.length}</strong><span>Borradores</span></div></div><h3>Herramientas</h3><div className="tiles"><button onClick={()=>goToPage('history')}><ClipboardList/><strong>Historial</strong><span>Consultar atenciones</span></button><button onClick={()=>openWorkers('home')}><UserPlus/><strong>Trabajadores</strong><span>Registrar o buscar personal</span></button><button onClick={()=>goToPage('history')}><FileClock/><strong>Pendientes</strong><span>{drafts.length} borradores</span></button><button onClick={()=>open()}><ShieldAlert/><strong>Alergias</strong><span>Revisar antes del tratamiento</span></button><button onClick={()=>goToPage('kardex')}><ClipboardList/><strong>Kardex</strong><span>Inventario, movimientos y reportes</span></button><button onClick={()=>goToPage('ambulatory')}><ClipboardList/><strong>Exportar</strong><span>Indicador ambulatorio · 10 hojas</span></button></div></>}
{page==='ambulatory'&&<><div className="pageHead"><button type="button" onClick={()=>goToPage('home')} aria-label="Volver al inicio"><ArrowLeft/></button><div><span>INDICADOR AMBULATORIO</span><h2>Exportar Excel</h2><small>Libro original de 10 hojas · solo datos ficticios</small></div></div><AmbulatoryExportPanel attentions={att} ledger={ledger} mappings={mappings} incidents={incidents} reconciliation={ambulatoryEvents} onReconciliation={setAmbulatoryEvents}/></>}
{page==='kardex'&&<><KardexWorkspace onExit={()=>goToPage('home')} onOpenIndicator={()=>goToPage('ambulatory')} attentions={att} ledger={ledger} mappings={mappings} incidents={incidents} onChange={setLedger} onMappings={setMappings} onIncidents={setIncidents} responsible={RESPONSIBLE}/></>}
{page==='register'&&active&&<><div className="pageHead"><button onClick={leave}><ArrowLeft/></button><div><span>REGISTRO AMBULATORIO</span><h2>{active.status==='saved'?'Editar atención':active.originId?'Corregir atención':'Nueva atención'}</h2><small className="autosaveStatus">{active.status==='draft'?(autoSavedAt?'Guardado automático '+new Date(autoSavedAt).toLocaleTimeString('es-PE',{hour:'2-digit',minute:'2-digit'})+' · Aviso tras 60 min':'Autoguardado activo · Aviso tras 60 min'):'Atención confirmada · edita para generar borrador'}</small></div></div><div className="registerProgress" role="status" aria-live="polite"><strong>Paso {registerStep+1} de 4</strong><span>{['Trabajador','Evaluación','Tratamiento','Resultado'][registerStep]}</span></div><div className="registerSteps" role="navigation" aria-label="Etapas de la atención"><button type="button" className={registerStep===0?'selected':''} aria-current={registerStep===0?'step':undefined} aria-label="Paso 1: Trabajador" onClick={()=>selectRegisterStep(0 as 0)}><span>1</span>Trabajador</button><button type="button" className={registerStep===1?'selected':''} aria-current={registerStep===1?'step':undefined} aria-label="Paso 2: Evaluación" onClick={()=>selectRegisterStep(1 as 1)}><span>2</span>Evaluación</button><button type="button" className={registerStep===2?'selected':''} aria-current={registerStep===2?'step':undefined} aria-label="Paso 3: Tratamiento" onClick={()=>selectRegisterStep(2 as 2)}><span>3</span>Tratamiento</button><button type="button" className={registerStep===3?'selected':''} aria-current={registerStep===3?'step':undefined} aria-label="Paso 4: Resultado" onClick={()=>selectRegisterStep(3 as 3)}><span>4</span>Resultado</button></div>{registerStep>0&&<div className="registerMiniSummary"><Users size={17}/><div><strong>{active.worker.name.trim()||'Trabajador por seleccionar'}</strong><span>{/^\d{8}$/.test(active.worker.dni)?'DNI '+active.worker.dni:'DNI pendiente'}{registerStep>1&&active.diagnosis.trim()?' · '+active.diagnosis.trim():''}</span></div><button type="button" aria-label="Editar trabajador" onClick={()=>selectRegisterStep(0)}>Editar</button></div>}{registerStep===0&&<><section id="attention-worker" className="panel"><h3><Users size={18}/> Trabajador</h3><div className="workerActions"><button type="button" className="workerSecondary" onClick={()=>openWorkers('register')}><Users size={16}/> Buscar en padrón</button><button type="button" className="workerPrimary" onClick={()=>{setWorkerReturn('register');setWorkerForm({...emptyWorker,dni:active.worker.dni});setEditingDni(null);setPage('workers')}}><UserPlus size={16}/> Nuevo trabajador</button></div><div className="fields two workerClinicalFields"><label className="workerFieldDni" data-clinical-field="worker-dni">DNI<input inputMode="numeric" maxLength={8} value={active.worker.dni} onChange={e=>{const dni=e.target.value.replace(/\D/g,'');const prior=workerByDni.get(dni);setUnknownWorkerDni(null);patch({worker:prior?{...prior}:{...active.worker,dni}})}} placeholder="8 dígitos" /></label><label className="workerFieldFull" data-clinical-field="worker-name">Nombre completo<textarea rows={2} value={active.worker.name} onChange={e=>patch({worker:{...active.worker,name:e.target.value}})} placeholder="Apellidos y nombres" /></label><label className="workerFieldSite">Sede del trabajador <em>*</em><select value={active.worker.site||''} onChange={e=>patch({worker:{...active.worker,site:e.target.value}})}><option value="">Seleccionar sede</option>{DANPER_WORKSITES.map(site=><option key={site.id} value={site.id}>{site.label}</option>)}</select></label><OfficialAreaField className="workerFieldArea" site={active.worker.site} value={active.worker.area} onChange={area=>patch({worker:{...active.worker,area}})} /><label className="workerFieldLabor">Labor<textarea rows={2} value={active.worker.labor} onChange={e=>patch({worker:{...active.worker,labor:e.target.value}})} placeholder="Labor del trabajador" /></label><label>Sexo<select value={active.worker.sex} onChange={e=>patch({worker:{...active.worker,sex:e.target.value}})}><option value="">Sin dato</option><option value="M">M</option><option value="F">F</option></select></label><label>Edad<input inputMode="numeric" value={active.worker.age} onChange={e=>patch({worker:{...active.worker,age:e.target.value}})}/></label><label>Ubigeo<input value={active.worker.ubigeo} onChange={e=>patch({worker:{...active.worker,ubigeo:e.target.value}})}/></label></div><div className="workerProfileHelper"><p className="hint">Los datos completados aquí se deben guardar también en la ficha del trabajador antes de continuar; no se actualizan atenciones anteriores.</p><button type="button" className="workerSecondary" onClick={editActiveWorkerProfile}><UserPlus size={16}/> Completar o guardar ficha</button></div>{historyWorker&&<p className="hint">DNI identificado en el padrón local o en el historial de prueba.</p>}</section></>}
{registerStep===1&&<><section className="panel allergyPanel" aria-labelledby="allergy-panel-title"><h3 id="allergy-panel-title"><ShieldAlert size={18}/> Alergias del trabajador <span className="allergy-priority">Revisar antes del tratamiento</span></h3>
{!/^\d{8}$/.test(active.worker.dni)?<p className="hint">Selecciona primero al trabajador para consultar o registrar su estado de alergias.</p>:<>
<div className="allergyStatus" data-clinical-field="allergy-status" role="group" aria-label="Estado de alergias">
<label className={'allergyOption'+(allergyState==='unknown'&&allergyData?' chosen':'')}><input type="radio" name="allergy-status" checked={allergyState==='unknown'&&Boolean(allergyData)} onChange={()=>updateAllergyStatus('unknown')}/><span className="allergyOptionText">No evaluado</span></label>
<label className={'allergyOption'+(allergyState==='none'?' chosen':'')}><input type="radio" name="allergy-status" checked={allergyState==='none'} onChange={()=>updateAllergyStatus('none')}/><span className="allergyOptionText">Refiere no tener alergias conocidas</span></label>
<label className={'allergyOption'+(allergyState==='known'?' chosen':'')}><input type="radio" name="allergy-status" checked={allergyState==='known'} onChange={()=>updateAllergyStatus('known')}/><span className="allergyOptionText">Alergias conocidas</span></label>
</div>
{allergyState==='known'&&<label data-clinical-field="allergy-substances">Sustancias o medicamentos reportados<textarea rows={2} value={allergyData?.substances||''} onChange={e=>updateAllergySubstances(e.target.value)} placeholder="Escribe los nombres reportados; sepáralos con comas"/></label>}
<div className={allergyState==='known'?'allergyAdvice alert':'allergyAdvice'}>
<AlertTriangle size={16}/><span>{allergyState==='known'?'Revisa las sustancias registradas antes de agregar productos. Las coincidencias textuales no detectan todas las alergias ni reacciones cruzadas.':allergyState==='none'?'Declaración del trabajador: no refiere alergias conocidas. No garantiza ausencia de riesgo.':'Estado pendiente de evaluar. No se interpreta como ausencia de alergias.'}</span>
</div>
</>}
<p className="hint">Información interna del prototipo; no se exporta al Excel. {isNativeSecureStore()?'En iPhone, almacenamiento de prueba protegido con Keychain.':'En navegador, almacenamiento de prueba sin cifrado.'} No ingresar datos reales.</p>
</section>
<section id="attention-clinical" className="panel"><h3><Activity size={18}/> Atención</h3><div className="fields two"><label data-clinical-field="clinical-date">Fecha<input type="date" value={active.date} onChange={e=>patch({date:e.target.value})}/></label><label data-clinical-field="clinical-time">Hora<input type="time" value={active.time} onChange={e=>patch({time:e.target.value})}/></label></div><label data-clinical-field="clinical-category">Categoría <em>*</em><select value={active.category} onChange={e=>patch({category:e.target.value,system:'',segment:''})}><option value="" disabled>Seleccionar categoría...</option>{guias.H.map(v=><option key={v}>{v}</option>)}</select></label>{(['ENFERMEDAD','ACCIDENTE COMUN','ACCIDENTE DE TRABAJO','MATERNIDAD'].includes(active.category))&&<label data-clinical-field="clinical-system">Sistema afectado <em>*</em><select value={active.system} onChange={e=>patch({system:e.target.value,segment:''})}><option value="" disabled>Seleccionar sistema...</option>{guias.P.map(v=><option key={v}>{v}</option>)}</select></label>}{(['ENFERMEDAD','ACCIDENTE COMUN','ACCIDENTE DE TRABAJO','MATERNIDAD'].includes(active.category))&&active.system.toUpperCase().includes('OSTEO')&&<label data-clinical-field="clinical-segment">Segmento osteomuscular <em>*</em><input value={active.segment} onChange={e=>patch({segment:e.target.value})} placeholder="Parte afectada"/></label>}<label data-clinical-field="clinical-diagnosis">Diagnóstico presuntivo / comentario <em>*</em><textarea ref={diagnosisInputRef} rows={3} value={active.diagnosis} onFocus={()=>setDiagnosisSuggestionsVisible(true)} onChange={e=>{patch({diagnosis:e.target.value});setDiagnosisSuggestionsVisible(true)}} placeholder="Escribe el diagnóstico presuntivo (sin CIE-10)"/></label>{diagnosisDropdownOpen&&<div ref={diagnosisSuggestionsRef} className="diagnosisSuggestions" role="group" aria-label="Sugerencias de diagnóstico"><span>SUGERENCIAS · seleccionar es opcional</span>{diagnosisMatches.map(d=><button key={d} type="button" onClick={()=>{patch({diagnosis:d});setDiagnosisSuggestionsVisible(false)}}>{d}</button>)}</div>}{diagnosisDropdownOpen&&<div className="diagnosisKeyboardScrollRoom" aria-hidden="true"/>}<p className="hint">Puedes escribir cualquier diagnóstico presuntivo o comentario clínico. Las sugerencias son textos de ayuda, no diagnósticos automáticos; sin CIE-10.</p></section></>}
{registerStep===2&&<><section className="panel"><h3><ClipboardList size={18}/> Procedimientos independientes</h3><p className="hint">Si realizas una curación de herida u otro procedimiento, puedes registrarlo por separado, incluso sin medicamentos. Los insumos compatibles podrán vincularse automáticamente cuando no haya ambigüedad.</p><label className="toggle"><input type="checkbox" checked={(active.standaloneProcedures||[]).includes('CURACION DE HERIDA')} onChange={()=>toggleStandaloneProcedure('CURACION DE HERIDA')}/> Se realizó CURACION DE HERIDA</label><details><summary>Otro procedimiento (opcional)</summary><label>Tipo de procedimiento<select value={(active.standaloneProcedures||[]).find(v=>v!=='CURACION DE HERIDA')||''} onChange={e=>{if(!active)return;patch({standaloneProcedures:[...(active.standaloneProcedures||[]).filter(v=>v==='CURACION DE HERIDA'),...(e.target.value?[e.target.value]:[])]})}}><option value="">Ninguno</option>{guias.W.filter(v=>v!=='CURACION DE HERIDA').map(v=><option key={v} value={v}>{v}</option>)}</select></label></details></section>
<div className={'registerAllergyCheckpoint'+(allergyState==='known'?' documented':'')} role="status"><ShieldAlert size={20}/><div><strong>{allergyState==='known'?'Alergias documentadas':allergyState==='none'?'Sin alergias conocidas declaradas':'Alergias pendientes de evaluar'}</strong><p>{allergyState==='known'?(allergyData?.substances?.trim()||'Consultar detalle en Evaluación'):allergyState==='none'?'Declaración registrada; confirmar siempre antes de administrar.':'Revisa el estado de alergias en Evaluación antes de administrar.'}</p></div><button type="button" onClick={()=>selectRegisterStep(1)}>Revisar</button></div><section id="attention-treatment" data-clinical-field="treatment-items" className="panel medsPanel"><h3><Plus size={18}/> Medicamentos e insumos <span className="count">{active.items.length}</span></h3>
<p className="hint">Cada producto mantiene su propio procedimiento. Toca una fila para cambiar su cantidad, procedimiento o eliminarla.</p>
{active.items.length>0&&<div className="medGroups">{Object.entries(itemGroups).map(([procedure,items])=><div className="medGroup" key={procedure}>
<button type="button" className="medGroupTitle" onClick={()=>setCollapsedGroups(v=>v.includes(procedure)?v.filter(x=>x!==procedure):[...v,procedure])} aria-expanded={!collapsedGroups.includes(procedure)}><span>{procedure} <small>{items.length} producto{items.length===1?'':'s'}</small></span>{collapsedGroups.includes(procedure)?<ChevronDown size={17}/>:<ChevronUp size={17}/>}</button>
{!collapsedGroups.includes(procedure)&&items.map(i=>{
const matches=allergyState==='known'?medicationAllergyMatches(i.name,allergyData?.substances||''):[];
return <div className="compactItem" key={i.id}>
<button type="button" className="itemSummary" aria-expanded={expandedProductId===i.id} onClick={()=>toggleProduct(i.id)}>
<div className="itemSummaryText"><strong>{i.name}</strong><span>Cantidad {i.quantity} · {i.procedure||'Procedimiento pendiente'}</span>{matches.length>0&&<span className="itemWarning"><AlertTriangle size={12}/> Revisar posible coincidencia de alergia</span>}</div>{expandedProductId===i.id?<ChevronUp size={17}/>:<ChevronDown size={17}/>}</button>
{expandedProductId===i.id&&<div className="itemEdit"><small>{i.code} · {i.unit} · Detalle: {i.procedure?procedureDetail(i.procedure):'Por confirmar'}</small>
<div className="itemControls"><label>Cantidad<input aria-label={'Cantidad de '+i.name} type="number" min="0" step="1" value={i.quantity} onChange={e=>updateProduct(i.id,{quantity:Number(e.target.value)})}/></label><label>Tipo de atención<select aria-label={'Tipo de atención de '+i.name} value={i.procedure} onChange={e=>updateProduct(i.id,{procedure:e.target.value})}><option value="">Seleccionar procedimiento</option>{guias.W.map(v=><option key={v}>{v}</option>)}</select></label><button aria-label={'Eliminar '+i.name} onClick={()=>{patch({items:active.items.filter(x=>x.id!==i.id)});setExpandedProductId(null)}}><Trash2 size={17}/></button></div><ClinicalStockChoice item={i} ledger={ledger} locked={ledger.movements.some(m=>m.dispenseRef?.attentionId===(active.originId||active.id)&&m.dispenseRef.itemId===i.id)} onChange={physicalUse=>updateProduct(i.id,{physicalUse})}/></div>}
</div>})}</div>)}</div>}
{!showSearch&&<button type="button" className="addAnother" onClick={()=>{setShowSearch(true);setQuery('')}}><Plus size={18}/> {active.items.length?'Agregar otro medicamento/insumo':'Agregar medicamento/insumo'}</button>}
{showSearch&&<div className="addSearch"><div className="searchTop"><strong>Buscar medicamento o insumo</strong><button type="button" onClick={()=>{setShowSearch(false);setQuery('')}} aria-label="Cerrar búsqueda"><X size={18}/></button></div><label>Buscar por nombre<input autoFocus value={query} onChange={e=>setQuery(e.target.value)} placeholder="Ej. paracetamol, gasa, jeringa" /></label>{query.trim().length>=2&&<div className="results">{matches.map(p=><button type="button" key={p.code} onClick={()=>addProduct(p)}><strong>{p.name}</strong><small>{p.unit} · Código asignado automáticamente</small></button>)}{matches.length===0&&<div className="hint">No se encontró coincidencia.</div>}</div>}</div>}
<p className="hint">Si un insumo admite varios procedimientos, tendrás que confirmar su clasificación. Al finalizar se descuenta automáticamente el stock verificable. Si no hay existencia física o la presentación necesita comprobarse, el consumo clínico queda registrado sin inventar saldo y se avisa de la conciliación pendiente.</p>
</section></>}
{registerStep===3&&<><div className="clinicalReview" aria-label="Resumen previo al guardado"><div className="clinicalReviewHeader"><ClipboardList size={17}/><strong>Resumen de la atención</strong><span>Revisa antes de guardar</span></div><div><span>Trabajador</span><strong>{active.worker.name||'Sin seleccionar'}</strong></div><div><span>Categoría</span><strong>{active.category||'Sin seleccionar'}</strong></div><div><span>Sistema</span><strong>{active.system||'No corresponde'}</strong></div><div><span>Diagnóstico</span><strong>{active.diagnosis||'Pendiente'}</strong></div><div><span>Tratamiento</span><strong>{active.items.length} producto(s) · {(active.standaloneProcedures||[]).length} procedimiento(s)</strong></div><div><span>Alergias</span><strong>{allergyState==='known'?'Reportadas: '+(allergyData?.substances||''):allergyState==='none'?'Niega alergias conocidas':'No evaluadas'}</strong></div><button type="button" onClick={()=>selectRegisterStep(1)}>Editar evaluación</button></div><section id="attention-result" className="panel"><h3><Clock size={18}/> Resultado y controles</h3><label>Situación al finalizar<select value={active.permission==='SI'?'permiso':'laborando'} onChange={e=>patch(e.target.value==='permiso'?{permission:'SI',workStatus:'NO LABORANDO',permissionTime:now()}:{permission:'NO',workStatus:'LABORANDO',permissionTime:''})}><option value="laborando">Continúa laborando</option><option value="permiso">Se retira con permiso</option></select></label>{active.permission==='SI'&&<label data-clinical-field="result-permission-time">Hora de permiso<input type="time" value={active.permissionTime} onChange={e=>patch({permissionTime:e.target.value})}/></label>}{(/ACCIDENTE|LESI|HERIDA|CURACION|SUTURA/i.test(active.category+' '+active.diagnosis+' '+active.items.map(i=>i.procedure).join(' ')))&&<><label className="toggle"><input type="checkbox" checked={active.blueBandage} onChange={e=>patch({blueBandage:e.target.checked,returned:e.target.checked?active.returned:false})}/> Uso de curita azul y guante</label>{active.blueBandage&&<label className="toggle"><input type="checkbox" checked={active.returned} onChange={e=>patch({returned:e.target.checked})}/> Se devolvió curita azul y guante</label>}<label className="toggle"><input type="checkbox" checked={active.photoSent} onChange={e=>patch({photoSent:e.target.checked})}/> Se envió foto de lesión o curación</label></>}</section></>}
<div className="registerDock" role="group" aria-label="Acciones de atención">{registerStep>0&&<button type="button" className="secondary" onClick={()=>selectRegisterStep((registerStep-1) as 0|1|2|3)}><ArrowLeft size={16}/> Anterior</button>}<button type="button" className="secondary" onClick={()=>{persist(active,'draft');setMessage('Borrador guardado.');setPage('home')}}><FileClock size={16}/> Borrador</button>{registerStep<3?<button type="button" className="primary" onClick={()=>selectRegisterStep((registerStep+1) as 0|1|2|3)}>Siguiente <ChevronRight size={17}/></button>:<button type="button" className="primary" onClick={()=>void save()} disabled={savingAttention}><Check size={16}/>{savingAttention?'Guardando…':'Guardar'}</button>}</div></>}
{page==='workers'&&<><div className="pageHead"><button onClick={()=>{setPage(workerReturn);setWorkerForm(null)}} aria-label="Volver"><ArrowLeft/></button><div><span>PADRÓN DE TRABAJADORES</span><h2>{workerForm?'Ficha de trabajador':'Trabajadores'}</h2></div></div><div className="warning">Padrón local. Tras activar el Excel REAL solo se muestran trabajadores oficiales; los registros anteriores permanecen protegidos. {isNativeSecureStore()?'Padrón cifrado en un archivo privado del iPhone; clave en Keychain.':'Almacenamiento web de prueba sin cifrado.'} El almacenamiento de atenciones requiere validación clínica antes de usar datos reales.</div>{workerForm?<section className="panel"><h3><UserPlus size={18}/> {editingDni?'Editar trabajador':'Registrar nuevo trabajador'}</h3><div className="fields two"><label>DNI <em>*</em><input inputMode="numeric" maxLength={8} disabled={Boolean(editingDni)} value={workerForm.dni} onChange={e=>setWorkerForm({...workerForm,dni:e.target.value.replace(/\D/g,'')})} placeholder="8 dígitos"/></label><label>Apellidos y nombres <em>*</em><input value={workerForm.name} onChange={e=>setWorkerForm({...workerForm,name:e.target.value})} placeholder="Apellidos y nombres"/></label><label className="workerFieldSite">Sede<select value={workerForm.site||''} onChange={e=>setWorkerForm({...workerForm,site:e.target.value})}><option value="">Seleccionar sede</option>{DANPER_WORKSITES.map(site=><option key={site.id} value={site.id}>{site.label}</option>)}</select></label><OfficialAreaField site={workerForm.site} value={workerForm.area} onChange={area=>setWorkerForm({...workerForm,area})}/><label>Labor<input value={workerForm.labor} onChange={e=>setWorkerForm({...workerForm,labor:e.target.value})}/></label><label>Sexo<select value={workerForm.sex} onChange={e=>setWorkerForm({...workerForm,sex:e.target.value})}><option value="">Sin dato</option><option value="M">M</option><option value="F">F</option></select></label><label>Edad<input inputMode="numeric" value={workerForm.age} onChange={e=>setWorkerForm({...workerForm,age:e.target.value})}/></label><label>Ubigeo<input value={workerForm.ubigeo} onChange={e=>setWorkerForm({...workerForm,ubigeo:e.target.value})}/></label></div><p className="hint">{workerReturn==='register'?'Para volver a la atención, completa área, labor y sede. Puedes escribir un área nueva aunque no esté en el catálogo. La corrección se guardará en el padrón privado.':'Puedes completar los datos restantes más adelante. Para usar este trabajador en una atención se solicitarán área, labor y sede.'}</p>{workerReturn==='register'&&officialRosterActive(workers as OperationalWorker[])&&!['official','verified'].includes((workers.find(w=>w.dni===editingDni) as OperationalWorker|undefined)?.rosterStatus||'')&&<label className="workerManualCheck"><input type="checkbox" checked={verifiedManualWorker} onChange={e=>setVerifiedManualWorker(e.target.checked)}/> Confirmo que verifiqué la identidad y vinculación laboral de este colaborador fuera del padrón importado. Sin esta verificación la atención no continuará.</label>}<div className="actions"><button className="secondary" onClick={()=>setWorkerForm(null)}>Cancelar</button><button className="primary" onClick={()=>void saveWorker()} disabled={savingWorker}><Check size={17}/>{savingWorker?'Guardando…':workerReturn==='register'?'Guardar ficha y volver a atención':'Guardar trabajador'}</button></div></section>:<><button className="workerPrimary wide" onClick={()=>startWorker()}><UserPlus size={17}/> Registrar nuevo trabajador</button><p className="hint">Para importar o actualizar el padrón desde Excel, abre <strong>Ajustes → Importar padrón desde Excel</strong>.</p><section ref={workerSearchPanelRef} className="panel workerSearchPanel"><label>Buscar por DNI o nombre<input value={workerQuery} onChange={e=>{setWorkerQuery(e.target.value);setWorkerPage(0)}} placeholder="DNI o apellidos"/></label><p className="hint">{workerPageData.total===0?'No hay coincidencias':`Mostrando ${workerPageData.first}–${workerPageData.last} de ${workerPageData.total} trabajadores`}</p></section>{filteredWorkers.length===0&&<div className="empty">No se encontraron trabajadores. Puedes registrar uno nuevo.</div>}{filteredWorkers.map(w=><div key={w.dni} className="workerCard"><button className="workerCardSelect" onClick={()=>selectWorker(w)}><strong>{w.name}</strong><small>DNI {w.dni} · {w.area||'Área pendiente'}</small><span>{workerReturn==='register'?'Seleccionar para la atención':'Ver / editar ficha'}</span></button><button className="workerEdit" aria-label={'Editar '+w.name} onClick={()=>startWorker(w)}><Settings size={17}/></button></div>)}{workerPageData.pageCount>1&&<nav className="workerPagination" aria-label="Páginas del padrón de trabajadores">
 <button type="button" className="workerSecondary" aria-label="Página anterior de trabajadores" disabled={workerPageData.page===0} onClick={()=>changeWorkerPage(-1)}><ChevronLeft size={17}/> Anterior</button>
 <span className="workerPaginationStatus" aria-live="polite">Página {workerPageData.page+1} de {workerPageData.pageCount}</span>
 <button type="button" className="workerSecondary" aria-label="Página siguiente de trabajadores" disabled={workerPageData.page>=workerPageData.pageCount-1} onClick={()=>changeWorkerPage(1)}>Siguiente <ChevronRight size={17}/></button>
</nav>}</>}</>}
{page==='history'&&<><div className="sectionTop"><div className="eyebrow">ATENCIONES REGISTRADAS</div><h2>Historial y pendientes</h2></div>{overdueDrafts>0&&<div className="pendingInfo"><Bell size={17}/> Hay {overdueDrafts} borrador{overdueDrafts===1?'':'es'} que lleva{overdueDrafts===1?'':'n'} al menos una hora sin completarse.</div>}<div className="warning">Datos clínicos privados. {isNativeSecureStore()?'iOS: registros clínicos en archivo cifrado y clave en Keychain.':'Navegador: almacenamiento de pruebas sin cifrar.'} Verifica primero el respaldo restaurable antes de usar datos clínicos reales.</div>{att.length===0&&<div className="empty">Aún no existen atenciones. Comienza con Nueva atención.</div>}{visibleHistory.map(a=><div className="historyEntry" key={a.id}><button className="history" onClick={()=>open(a)}><div className="historyIcon">{a.status==='draft'?<FileClock/>:<ClipboardList/>}</div><div><strong>{a.worker.name||'Atención sin trabajador'}</strong><small>{a.date} · {a.time} · {a.status==='draft'?'Borrador':freq(a)}</small><span>{a.diagnosis||'Sin diagnóstico todavía'}</span></div><ChevronRight size={18}/></button>{a.status==='saved'&&a.items.length>0&&<div className="historyActions" role="status">
 <span>{countUnmatchedHistoryItems(a)===0
 ? 'Consumos clínicos y salidas físicas conciliados automáticamente'
 : countUnmatchedHistoryItems(a)+' producto(s) registrados en atención, con salida física no verificable. No se inventaron saldos; Excel provisional disponible.'}</span>
 </div>}{a.status==='draft'&&<div className="historyActions"><span>{reminderDueAt(a.updatedAt)<=reminderTick?'Aviso de 1 hora cumplido':'Pendiente · recordatorio a los 60 min'}</span><button type="button" onClick={()=>deleteDraft(a.id)}><Trash2 size={14}/> Eliminar borrador</button></div>}{a.status==='saved'&&<div className="historyActions"><span>{canDeleteUnlinkedAttention(a.id,a.status,ledger.movements).allowed?'Atención de prueba sin entregas vinculadas':'Entregas vinculadas: eliminación bloqueada para proteger Kardex'}</span><button type="button" disabled={savingAttention||!canDeleteUnlinkedAttention(a.id,a.status,ledger.movements).allowed} onClick={()=>void deleteSavedAttention(a.id)}><Trash2 size={14}/> Eliminar atención</button></div>}</div>)}{historyLimit<sortedHistory.length&&<button type="button" className="workerSecondary wide" onClick={()=>setHistoryLimit(n=>n+60)}>Mostrar 60 atenciones más ({visibleHistory.length} de {sortedHistory.length})</button>}</>}
{page==='settings'&&<><div className="sectionTop"><div className="eyebrow">PREFERENCIAS</div><h2>Configuración</h2></div><section className="panel"><h3><Sun size={18}/> Apariencia</h3><div className="modes">{(['auto','light','dark']as const).map(m=><button className={mode===m?'selected':''} key={m} onClick={()=>setMode(m)}>{m==='auto'?'Sistema':m==='light'?'Claro':'Oscuro'} {mode===m&&<Check size={16}/>}</button>)}</div></section><section className="panel"><h3>Animaciones y sensaciones hápticas</h3><div className="hapticSettings"><label><input type="checkbox" checked={hapticsOn} onChange={e=>{setHapticsOn(e.target.checked);setHapticsEnabled(e.target.checked);if(e.target.checked)feedback('selection')}}/> Respuesta háptica del iPhone</label></div><p className="hint">Vibración discreta al guardar correctamente, navegar y abrir confirmaciones. Sin hápticos en navegador. Las animaciones respetan «Reducir movimiento» del sistema.</p></section><section className="panel"><h3><Users size={18}/> Responsable preconfigurado</h3><strong>{RESPONSIBLE}</strong><p className="hint">Protección nativa de acceso mediante Face ID o código del iPhone. Los registros incorporarán los datos del responsable configurado.</p></section><section className="panel"><h3><Bell size={18}/> Recordatorios de borradores</h3><p>Recordatorio después de <strong>60 minutos sin completar</strong> una atención.</p><p className="hint">{isNativeMobile()?'En iOS y Android, los avisos locales se programan para los borradores con información a los 60 minutos de inactividad, si autorizas las notificaciones. El aviso no muestra nombres, DNI ni datos clínicos. Su entrega con la app cerrada aún requiere validación física.':'En navegador, los avisos se muestran solo al abrir o mantener activa la aplicación. Las notificaciones nativas requieren permiso del sistema.'}</p>{isNativeMobile()?<button className="workerPrimary wide" onClick={()=>notificationEnabled?setNotificationEnabled(false):void activateIOSNotices()}>{notificationEnabled?'Desactivar avisos nativos':'Autorizar avisos en el teléfono'}</button>:<div className="nativePending">Windows / navegador: alertas solo al abrir o mantener activa la app.</div>}{notificationMessage&&<p className="hint" role="status">{notificationMessage}</p>}</section><BackupSettingsPanel/><PersonalImporter current={workers} linkedDnis={[...att.map(a=>a.worker.dni),...Object.keys(allergyRecords),...(active?.worker.dni?[active.worker.dni]:[])]} onActivateOfficial={async updated=>{await writeDemoSnapshot({...snapshotRef.current,workers:updated});setWorkers(updated);setWorkerQuery('');setMessage('Padrón REAL activado: listado operativo filtrado. Historial y registros anteriores conservados.');feedback('success')}} onApply={async updated=>{
 // Import is not successful merely because React updated its memory.
 // Persist and verify the encrypted worker vault before reporting success.
 await writeDemoSnapshot({...snapshotRef.current,workers:updated});
 setWorkers(updated);setWorkerQuery('');
 setMessage('Padrón guardado y verificado en este dispositivo.');feedback('success');
 }}/><details><summary>Reiniciar completamente los datos de prueba de este teléfono</summary><FreshStartPanel/></details><section className="panel"><h3>Persistencia local</h3><p className="hint">{isNativeSecureStore()?'Bóveda local AES-GCM y almacén seguro del dispositivo; sin sincronización automática.': 'Navegador: solo pruebas, sin cifrado.'} Estado: {storageState==='saved'?'guardado':storageState==='saving'?'guardando':storageState==='loading'?'cargando':'error'}</p>{storageFault&&<p role="alert">{storageFault}</p>}</section><section className="panel"><h3>Estado</h3><p className="hint">DANPER v{appMetadata.version} · Kardex de Enfermería con 98 productos, sin donados; movimientos auditados, entregas confirmadas y exportaciones Excel implementadas. En iOS se utiliza Keychain y en Android Keystore para proteger las claves locales. La validación física de Excel, impresión y SideStore sigue pendiente, al igual que SQLite cifrada para historiales grandes. Solo datos ficticios.</p><button className="dangerButton" disabled={workers.length>0||att.length>0||ledger.lots.length>0||ledger.movements.length>0} onClick={()=>void clearDemoData()}>Limpiar datos de prueba</button>{(workers.length>0||att.length>0||ledger.lots.length>0||ledger.movements.length>0)&&<p className="hint">Borrado de datos deshabilitado mientras existan trabajadores, atenciones o inventario.</p>}</section></>}
</main><nav className="appTabBar" aria-label="Navegación principal"><button className={page==='home'?'active':''} onClick={()=>goToPage('home')}><Home/>Inicio</button><button className={page==='register'?'active':''} onClick={()=>open()}><Plus/>Registrar</button><button className={page==='history'?'active':''} onClick={()=>goToPage('history')}><ClipboardList/>Historial</button><button className={page==='settings'?'active':''} onClick={()=>goToPage('settings')}><Settings/>Ajustes</button></nav>{workerProfileAlert&&page==='register'&&registerStep===0&&<div className="workerDiscoveryOverlay"><div className="workerDiscoveryDialog" role="alertdialog" aria-modal="true" aria-labelledby="worker-profile-title" aria-describedby="worker-profile-desc">
 <div className="workerDiscoveryIcon"><UserPlus size={24}/></div><h3 id="worker-profile-title">Completar datos del trabajador</h3>
 <p id="worker-profile-desc">{workerProfileAlert.missing.length?'Falta: '+workerProfileAlert.missing.join(', ')+'. ':''}{workerProfileAlert.changed?'Los datos ingresados necesitan guardarse en su ficha. ':''}Para continuar, registra o actualiza los datos del colaborador en el padrón local.</p>
 <div className="workerDiscoveryActions"><button type="button" className="primary" onClick={editActiveWorkerProfile}>Completar ficha</button><button type="button" className="secondary" onClick={()=>setWorkerProfileAlert(null)}>Cerrar</button></div>
 </div></div>}{unknownWorkerDni&&page==='register'&&registerStep===0&&<div className="workerDiscoveryOverlay">
 <div className="workerDiscoveryDialog" role="alertdialog" aria-modal="true" aria-labelledby="worker-not-found-title" aria-describedby="worker-not-found-desc" onKeyDown={e=>{if(e.key==='Tab'){const buttons=e.currentTarget.querySelectorAll('button');if(buttons.length===2){if(e.shiftKey&&document.activeElement===buttons[0]){e.preventDefault();buttons[1].focus()}else if(!e.shiftKey&&document.activeElement===buttons[1]){e.preventDefault();buttons[0].focus()}}}}}>
  <div className="workerDiscoveryIcon"><UserPlus size={24}/></div>
  <h3 id="worker-not-found-title">Trabajador no encontrado</h3>
  <p id="worker-not-found-desc">El DNI ingresado no figura en el padrón disponible. ¿Deseas registrar su ficha ahora?</p>
  {officialRosterActive(workers as OperationalWorker[])&&<p className="workerDiscoveryCaution">El padrón oficial está activo: una ficha manual requerirá verificación para habilitar nuevas atenciones.</p>}
  <div className="workerDiscoveryActions"><button ref={registerWorkerButton} type="button" className="primary" onClick={()=>{const dni=unknownWorkerDni;dismissedUnknownDni.current=dni;openWorkers('register');setWorkerForm({...emptyWorker,...active?.worker,dni});setUnknownWorkerDni(null)}}>Registrar trabajador</button><button type="button" className="secondary" onClick={()=>{dismissedUnknownDni.current=unknownWorkerDni;setUnknownWorkerDni(null)}}>Cerrar</button></div>
 </div>
</div>}{stepAlert&&page==='register'&&<div className="clinicalAlertOverlay"><div className="clinicalAlertDialog" role="alertdialog" aria-modal="true" aria-labelledby="clinical-alert-title" aria-describedby="clinical-alert-desc" onKeyDown={e=>{if(e.key==='Tab'){e.preventDefault();stepAlertButton.current?.focus()}}}><div className="clinicalAlertIcon"><AlertTriangle size={24}/></div><h3 id="clinical-alert-title">Falta completar información</h3><p id="clinical-alert-desc">Antes de continuar al siguiente paso, revisa:</p><ul>{stepAlert.slice(0,4).map((issue,i)=><li key={issue.field+'-'+i}>{issue.message}</li>)}</ul>{stepAlert.length>4&&<p>Y {stepAlert.length-4} campo(s) adicionales.</p>}<button ref={stepAlertButton} type="button" className="primary" onClick={dismissStepAlert}>Corregir ahora</button></div></div>}{message&&<div className="toast" role="alert"><button onClick={()=>setMessage('')}><X size={16}/></button>{message}</div>}</div>}

createRoot(document.getElementById('root')!).render(<React.StrictMode><App/></React.StrictMode>);
