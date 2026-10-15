/** UI-only decision. Never confuses a partly typed DNI with an unknown worker. */
export function shouldOfferWorkerRegistration(
  dni:string,
  knownDnis:readonly string[],
  ready:boolean,
  previouslyDismissed:string|null
):boolean{
  return ready&&/^\d{8}$/.test(dni)&&dni!==previouslyDismissed&&!knownDnis.includes(dni);
}
