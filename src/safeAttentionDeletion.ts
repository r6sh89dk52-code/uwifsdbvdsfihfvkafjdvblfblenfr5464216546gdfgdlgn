/** Prototype-only deletion guard: confirmed stock usage is immutable and cannot
 * be orphaned by a destructive attention deletion. No stock is ever restored here.
 */
export type LinkedMovement={dispenseRef?:{attentionId:string}|null};
export function canDeleteUnlinkedAttention(
 attentionId:string,
 status:'saved'|'draft',
 movements:readonly LinkedMovement[]
):{allowed:boolean;reason:string}{
 if(!attentionId?.trim())return{allowed:false,reason:'Atención sin identificador válido.'};
 if(status!=='saved')return{allowed:false,reason:'Los borradores se eliminan desde su acción correspondiente.'};
 if(movements.some(m=>m.dispenseRef?.attentionId===attentionId))
  return{allowed:false,reason:'Esta atención tiene entregas confirmadas. No puede eliminarse porque dejaría movimientos del Kardex sin su atención de origen. Requiere un procedimiento de anulación auditada.'};
 return{allowed:true,reason:''};
}
