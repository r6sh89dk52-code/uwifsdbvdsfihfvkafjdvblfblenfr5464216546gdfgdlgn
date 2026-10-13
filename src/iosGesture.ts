/**
 * Screen-edge navigation for Capacitor apps.
 * iOS uses a real UIKit UIScreenEdgePanGestureRecognizer and sends this event.
 * Browser previews use a narrow-edge touch fallback, never a full-screen swipe.
 */
export const IOS_BACK_EVENT = 'danper-native-swipe-back';
export type EdgeSwipePoint = {x:number;y:number;time:number};

export function shouldTriggerEdgeBack(start:EdgeSwipePoint,end:EdgeSwipePoint,viewportWidth:number):boolean{
  const dx=end.x-start.x;
  const dy=Math.abs(end.y-start.y);
  const duration=end.time-start.time;
  return viewportWidth>0 && start.x>=0 && start.x<=Math.min(28,viewportWidth*0.085) &&
    dx>=86 && dy<=Math.max(42,dx*0.55) && duration>0 && duration<=900;
}

/** Touch gesture only for web previews; avoid competing with the native iOS recognizer. */
export function attachBrowserEdgeBack(onBack:()=>void):()=>void{
  let start:EdgeSwipePoint|null=null;
  const begin=(event:TouchEvent)=>{
    start=null;
    if(event.touches.length!==1 || window.getSelection()?.toString())return;
    const target=event.target instanceof Element?event.target:null;
    if(target?.closest('input,textarea,select,[contenteditable="true"],[data-no-edge-back], [role="slider"]'))return;
    const touch=event.touches[0];
    if(touch.clientX>Math.min(28,window.innerWidth*0.085))return;
    start={x:touch.clientX,y:touch.clientY,time:Date.now()};
  };
  const end=(event:TouchEvent)=>{
    const started=start;start=null;
    if(!started||event.changedTouches.length!==1)return;
    const t=event.changedTouches[0];
    if(shouldTriggerEdgeBack(started,{x:t.clientX,y:t.clientY,time:Date.now()},window.innerWidth))onBack();
  };
  const cancel=()=>{start=null};
  window.addEventListener('touchstart',begin,{passive:true});
  window.addEventListener('touchend',end,{passive:true});
  window.addEventListener('touchcancel',cancel,{passive:true});
  return()=>{
    window.removeEventListener('touchstart',begin);
    window.removeEventListener('touchend',end);
    window.removeEventListener('touchcancel',cancel);
  };
}
