/** Verified by the user against DANPER_Tabla_Correspondencias_Kardex_Indicador_104x432(1).xlsx.
 * Only associations approved for DEMO attendances (86 of 98 nurse-Kardex rows).
 * E-62 and E-63 are distinct nurse supplies mapped to a shared official code;
 * their physical lots MUST be selected explicitly by the user. E-68 (nylon)
 * and the 11 materials with no proposed numeric code are NOT authorized.
 * This does not merge the two stock ledgers or infer unit conversions.
 */
import {kardexCatalog} from './kardexCatalog';
import products from './products.json';
const authorizedPairs="1:16000007;2:16000029;3:16000037;4:16000039;5:16016685;6:16000055;7:16011903;8:16000057;9:16000061;10:16015455;11:16000065;12:16000086;13:16000089;14:16000105;15:16000132;16:16000137;17:16000152;18:16000158;19:16000174;21:16011905;22:16000182;23:16000191;24:16000196;26:16000035;27:16000040;28:16000064;29:16000080;30:16000081;31:16000082;32:16000084;33:16000088;34:16000006;35:16024392;36:16000131;37:16000150;38:16000156;39:16011904;40:16019736;41:16000148;42:16000149;43:16000146;44:16000147;45:16011898;46:16000133;47:16000171;48:16000195;49:16000213;50:16011872;51:16000172;52:16017902;53:16000207;54:16000000;55:16000001;56:16000002;57:16000013;58:16000014;59:16010672;60:16000077;61:16000094;62:16024400;63:16024400;64:16000130;65:16000128;66:16000135;67:16000136;69:16000210;70:16000209;71:16000227;72:16000231;73:16000235;74:16000236;75:16000237;76:16000238;77:16000054;78:16000165;79:16000164;80:10000575;83:16013532;87:16000025;88:16000009;89:16000010;90:16000066;91:16024399;92:16000143;93:16000142;96:16019966".split(';').map(part=>{
 const [id,code]=part.split(':');return {kardexCode:'E-'+id,clinicalCode:code};
});
export const reviewedAssociations=authorizedPairs.map(({kardexCode,clinicalCode})=>{
 const kardex=kardexCatalog.find(p=>p.id===kardexCode);
 const official=products.find(p=>p.code===clinicalCode);
 if(!kardex||!official)throw Error('La matriz verificada contiene un código inexistente.');
 return {kardexCode,kardexName:kardex.name,clinicalCode,clinicalName:official.name,clinicalUnit:official.unit};
});
if(reviewedAssociations.length!==86||new Set(reviewedAssociations.map(x=>x.kardexCode)).size!==86||reviewedAssociations.some(x=>x.kardexCode==='E-68'||x.kardexCode.startsWith('D-')))throw Error('Correspondencias verificadas incompletas.');
export function reviewedAssociationsFor(clinicalCode:string){
 return reviewedAssociations.filter(x=>x.clinicalCode===clinicalCode);
}
export function isReviewedAssociation(clinicalCode:string,kardexCode:string){
 return reviewedAssociations.some(x=>x.clinicalCode===clinicalCode&&x.kardexCode===kardexCode);
}
