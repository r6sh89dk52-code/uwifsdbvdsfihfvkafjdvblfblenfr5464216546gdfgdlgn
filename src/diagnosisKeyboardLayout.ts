/**
 * Geometry for iOS WKWebView's visual viewport when the software keyboard is open.
 * The dropdown remains in normal document flow; scroll it above the visible keyboard.
 */
export type VisibleViewport = {height:number;offsetTop:number};
export type SuggestionGeometry = {top:number;bottom:number};
export function suggestionScrollDelta(
  suggestion:SuggestionGeometry,
  viewport:VisibleViewport,
  gap=14
):number{
  if(!Number.isFinite(suggestion.bottom)||!Number.isFinite(viewport.height)||viewport.height<=0)return 0;
  const visibleBottom=viewport.offsetTop+viewport.height;
  return Math.max(0,Math.ceil(suggestion.bottom-visibleBottom+gap));
}
export function suggestionMaxHeight(viewportHeight:number):number{
  if(!Number.isFinite(viewportHeight)||viewportHeight<=0)return 184;
  // Header + at least two choices on compact iPhones; more options can scroll inside.
  return Math.max(120,Math.min(208,Math.floor(viewportHeight*0.35)));
}
