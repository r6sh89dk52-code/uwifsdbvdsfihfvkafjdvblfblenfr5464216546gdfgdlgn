/**
 * Stage A v0.4: deterministic procedure suggestions, without medical inference.
 * Products are looked up by name only. A suggestion is NEVER evidence that a
 * medication was actually administered. User confirms / edits each entry.
 */
export type ProductLike = {name:string;unit?:string};
export type RecordedLike = {procedure:string};
export type ProcedureProposal = {procedure:string;source:'presentation'|'context'|'review';needsConfirmation:boolean};

const normalize = (value:string) => value.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toUpperCase();
const distinct = (values:string[]) => [...new Set(values.filter(Boolean))];

export function inferProcedure(product:ProductLike, items:RecordedLike[], standalone:string[]=[]):ProcedureProposal {
  const n=normalize(product.name);
  // Check explicit dosage form before considering other products in the attention.
  // The route is a suggestion, not a clinical determination.
  if (/\b(TABLETA|TABLETAS|PASTILLA|PASTILLAS|CAPSULA|CAPSULAS|GRAGEA|GRAGEAS|COMPRIMIDO|COMPRIMIDOS)\b/.test(n))
    return {procedure:'TRATAMIENTO ORAL',source:'presentation',needsConfirmation:false};
  if (/\b(AMPOLLA|AMPOLLAS|AMP|INYECTABLE)\b/.test(n))
    return {procedure:'INYECTABLE',source:'presentation',needsConfirmation:false};
  if (/OFTALM|GOTAS OCULARES|GOTA OCULAR/.test(n))
    return {procedure:'APLICACION DE GOTAS OFTALMICAS',source:'presentation',needsConfirmation:false};
  if (/\b(CREMA|CREMAS|UNGUENTO|POMADA)\b/.test(n))
    return {procedure:'APLICACION DE CREMA',source:'presentation',needsConfirmation:false};

  const procedures=distinct([...items.map(i=>i.procedure),...standalone]);
  // Dental/acupuncture needles and special syringe presentations do not prove injection.
  const specialized=/ACUPUNTURA|ODONTOLOG|NYLON.*AGUJA|SEDA.*AGUJA|CAJA PARA DESCARTAR|ACIDO ORTOFOSFORICO/.test(n);
  const pending:ProcedureProposal={procedure:'',source:'review',needsConfirmation:true};
  // Needle or syringe may be used with an injection, but is not itself proof
  // of an injected medicine; do not inherit unrelated previous selections.
  if (/\b(AGUJA|AGUJAS|JERINGA|JERINGAS)\b/.test(n) && !specialized) {
    return procedures.includes('INYECTABLE')
      ? {procedure:'INYECTABLE',source:'context',needsConfirmation:false}
      : pending;
  }
  // Generic supplies are contextual; if two plausible types of procedure are
  // recorded, ask instead of silently choosing the last item added.
  if (/\b(GASA|GASAS|ALGODON|CURITA|CURITAS|APOSITO|APOSITOS|GUANTE|GUANTES|ALCOHOL|VENDA|VENDAS)\b/.test(n) || /AGUA OXIGENADA/.test(n)) {
    const plausible=procedures.filter(p=>['INYECTABLE','CURACION DE HERIDA','SUTURAS','EXTRACCION DE CUERPO EXTRAÑO','RETIRO DE PUNTOS DE SUTURA'].includes(p));
    if(plausible.length===1)return {procedure:plausible[0],source:'context',needsConfirmation:false};
    return pending;
  }
  return pending;
}

export function procedureDetail(procedure:string):string {
  return ['INYECTABLE','CURACION DE HERIDA','SUTURAS','EXTRACCION DE CUERPO EXTRAÑO','RETIRO DE PUNTOS DE SUTURA'].includes(procedure)?'INSUMOS':'-';
}

