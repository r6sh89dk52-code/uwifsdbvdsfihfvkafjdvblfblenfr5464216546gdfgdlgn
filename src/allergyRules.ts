/** Basic literal-name warning only. No ingredient/cross-reaction safety claims. */
export function medicationAllergyMatches(productName:string,substances:string):string[]{
 const norm=(s:string)=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('es').trim();
 const name=norm(productName);
 return substances.split(/[,;\n]+/).map(s=>s.trim()).filter(s=>s.length>=3&&name.includes(norm(s)));
}
