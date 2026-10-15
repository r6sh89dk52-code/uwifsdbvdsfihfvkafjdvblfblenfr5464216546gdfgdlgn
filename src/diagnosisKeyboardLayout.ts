/**
 * Pure iOS visual-viewport geometry for a portaled diagnosis suggestion popover.
 * The popup is rendered in document.body, outside animated clinical panels and
 * fixed bottom navigation. Absolute document coordinates track page + viewport.
 */
export type VisualViewportGeometry = {
  height:number;
  width:number;
  offsetTop:number;
  offsetLeft:number;
};
export type InputGeometry={left:number;top:number;bottom:number;width:number};
export type DiagnosisPopover={top:number;left:number;width:number;maxHeight:number;visibleTop:number};
export function diagnosisPopoverPosition(
  viewport:VisualViewportGeometry,
  input:InputGeometry,
  scroll:{x:number;y:number},
  matchCount:number,
  gap=10
):DiagnosisPopover|null{
  if(!Number.isFinite(viewport.height)||!Number.isFinite(viewport.width)||
    viewport.height<185||viewport.width<190||!Number.isFinite(input.left)||
    !Number.isFinite(input.bottom)||matchCount<1)return null;
  const rows=Math.min(3,matchCount);
  const desired=38+rows*48;
  const maxHeight=Math.round(Math.min(216,desired,Math.max(112,viewport.height*0.37)));
  const viewportLeft=viewport.offsetLeft;
  const viewportRight=viewportLeft+viewport.width;
  const availableWidth=Math.max(150,viewport.width-24);
  const width=Math.min(Math.max(150,input.width),availableWidth);
  const left=Math.min(Math.max(input.left,viewportLeft+12),viewportRight-width-12);
  // iOS can scroll the visual viewport independently from the layout viewport.
  // Always locate the bottom of the *visible* area, not window.innerHeight.
  const visibleTop=viewport.offsetTop+viewport.height-maxHeight-gap;
  return {
    top:Math.round(scroll.y+visibleTop),
    left:Math.round(scroll.x+left),
    width:Math.round(width),
    maxHeight,
    visibleTop
  };
}
/** Scroll the textarea upwards only when the popup would cover its insertion area. */
export function diagnosisInputClearance(inputBottom:number,popoverVisibleTop:number,gap=12):number{
  if(!Number.isFinite(inputBottom)||!Number.isFinite(popoverVisibleTop))return 0;
  return Math.max(0,Math.ceil(inputBottom+gap-popoverVisibleTop));
}
