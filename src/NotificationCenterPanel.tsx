import {ArrowLeft,Bell,Clock3,PackageSearch,ChevronRight,ShieldCheck} from 'lucide-react';
import {type AppNotice,type NoticeRoute} from './notificationCenterRules';

type Props={notices:readonly AppNotice[];onBack:()=>void;onOpen:(route:NoticeRoute)=>void};
export default function NotificationCenterPanel({notices,onBack,onOpen}:Props){
 return <section className="danperNotificationCenter" aria-label="Centro de avisos locales">
  <div className="pageHead"><button type="button" onClick={onBack} aria-label="Volver al inicio"><ArrowLeft/></button>
   <div><span>CENTRO DE AVISOS</span><h2>Notificaciones</h2><small>Recordatorios internos y existencias por vencer</small></div>
  </div>
  <div className="panel notificationPrivacy">
   <ShieldCheck size={19}/>
   <p>Estos avisos se calculan con información guardada en tu iPhone. No se envían datos a servidores ni se muestran diagnósticos o DNI en la pantalla bloqueada.</p>
  </div>
  {notices.length===0?
   <div className="panel notificationEmpty"><Bell size={29}/><strong>Sin avisos pendientes</strong><p>Cuando haya borradores atrasados o lotes próximos a vencer, los verás aquí.</p></div>:
   <><p className="notificationCount">{notices.length} aviso{notices.length!==1?'s':''} por revisar</p>
    <div className="notificationFeed">{notices.slice(0,80).map(notice=>
     <button type="button" className={'notificationItem notification-'+notice.severity} key={notice.id} onClick={()=>onOpen(notice.route)}>
      <span className="notificationItemIcon">{notice.kind==='draft'?<Clock3 size={21}/>:<PackageSearch size={21}/>}</span>
      <span className="notificationItemText"><strong>{notice.title}</strong><small>{notice.description}</small><em>{notice.route==='history'?'Abrir historial':'Revisar Kardex'}</em></span>
      <ChevronRight size={16}/>
     </button>)}</div>
    {notices.length>80&&<p className="hint">Hay {notices.length-80} avisos adicionales. Revisa tus registros e inventario.</p>}</>}
 </section>;
}
