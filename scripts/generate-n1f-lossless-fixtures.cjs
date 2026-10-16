'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {load,visit}=require('./ambulatory-test-helpers.cjs');
const workerRules=load('src/workerRules.ts');
const out=process.env.DANPER_N1_FIXTURE_DIR;
if(!out||!path.isAbsolute(out))throw Error('Expected absolute synthetic output path');
fs.mkdirSync(out,{recursive:true});
const t=Date.parse('2026-10-14T13:35:00Z');
const workers=[
 {dni:'00000001',name:'PERSONA FICTICIA ÁLVAREZ',area:'CAMPO',labor:'COSECHA',
  sex:'F',age:'22',ubigeo:'FICTICIO',site:'LA VENTUROSA',source:'manual',
  localCorrectionAt:t,extension:{approved:false,nullable:null}},
 {dni:'00000002',name:'PERSONA FICTICIA DOS',area:'PACKING',labor:'PROCESO',
  sex:'M',age:'30',ubigeo:'FICTICIO',site:'PLVENTUROSA',source:'imported',
  rosterStatus:'official',extra:['uno',null,{tags:['ÁREA',false]}]}
];
for(const w of workers)if(workerRules.normalizeDni(w.dni)!==w.dni)throw Error('invalid demo DNI');
const a={...visit('SAVE-DEMO',[{id:'MED-DEMO',code:'16000182',name:'PRODUCTO FICTICIO',
 unit:'UND',quantity:2,procedure:'TRATAMIENTO ORAL'}]),
 worker:structuredClone(workers[0]),date:'2026-10-14',status:'saved',
 updatedAt:t,photoSent:false,standaloneProcedures:['EVALUACIÓN','OBSERVACIÓN'],
 futureClinical:{nested:{name:'prueba áéí',tags:[null,false,0,'']},enabled:true}};
const draft={...visit('DRAFT-DEMO',[]),worker:{dni:'',name:'',site:''},
 status:'draft',diagnosis:'',date:'2026-10-14',updatedAt:t+600,
 items:[{id:'INCOMPLETO',name:'',quantity:0,procedure:''}],future:null};
const corrected={...visit('CORRECTION-DEMO',[]),worker:structuredClone(workers[0]),
 status:'draft',date:'2026-10-14',updatedAt:t+1200,originId:'SAVE-DEMO',
 diagnosis:'BORRADOR CORREGIDO',standaloneProcedures:['CONTROL'],photoSent:true};
const allergies={
 '00000001':{status:'known',substances:'SUSTANCIA FICTICIA',updatedAt:t,
               future:{reviewed:true,notes:['DEMO']}},
 '00000002':{status:'none',substances:'',updatedAt:t+1},
 '00000003':{status:'unknown',substances:'',updatedAt:t+2},
 '00000004':{status:'known',substances:'',updatedAt:t+3}
};
const snapshot={workers,attentions:[a,draft,corrected],allergies,notifications:true,
 stockLots:[],stockMovements:[],catalogMappings:[],deliveryIncidents:[],
 ambulatoryReconciliation:[],futureTop:{nullable:null,matrix:[[1,2],[3,4]]}};
const save=(name,obj)=>fs.writeFileSync(path.join(out,name),JSON.stringify(obj));
save('n1f-source.json',snapshot);
let nodes=0;const h=crypto.createHash('sha256');
const frame=(k,p,v)=>{
 const pb=Buffer.from(p), vb=Buffer.from(v), n=Buffer.alloc(8), m=Buffer.alloc(8);
 n.writeBigUInt64BE(BigInt(pb.length));m.writeBigUInt64BE(BigInt(vb.length));
 h.update(Buffer.from([k.charCodeAt(0)]));h.update(n);h.update(pb);h.update(m);h.update(vb);nodes++;
};
const esc=s=>s.replace(/~/g,'~0').replace(/\//g,'~1');
const walk=(v,p)=>{
 if(v===null)return frame('Z',p,'');
 if(Array.isArray(v)){frame('A',p,'');v.forEach((e,i)=>walk(e,p+'/i:'+i));return}
 if(typeof v==='object'){frame('O',p,'');for(const k of Object.keys(v).sort())walk(v[k],p+'/k:'+esc(k));return}
 if(typeof v==='string')return frame('S',p,v);
 if(typeof v==='boolean')return frame('B',p,String(v));
 if(typeof v==='number'&&Number.isFinite(v))return frame('N',p,String(v));
 throw Error('Invalid fixture primitive');
};
walk(snapshot,'$');
save('n1f-expected.json',{sourceSHA256:crypto.createHash('sha256')
 .update(fs.readFileSync(path.join(out,'n1f-source.json'))).digest('hex'),
 semanticSHA256:h.digest('hex'),nodes,workers:2,visits:3,saved:1,
 drafts:2,corrections:1,known:2,none:1,unknown:1,incomplete:1});
const altered=(name,edit)=>{const clone=structuredClone(snapshot);edit(clone);save(name,clone)};
altered('n1f-lost-extension.json',s=>{delete s.attentions[0].futureClinical.nested.tags});
altered('n1f-lost-null.json',s=>{delete s.futureTop.nullable});
altered('n1f-changed-allergy.json',s=>{s.allergies['00000003'].status='none'});
altered('n1f-lost-draft.json',s=>{s.attentions=s.attentions.filter(a=>a.status==='saved')});
altered('n1f-changed-photo.json',s=>{s.attentions[0].photoSent=true});
altered('n1f-duplicate-worker.json',s=>{s.workers[1].dni=s.workers[0].dni});
altered('n1f-invalid-allergy.json',s=>{s.allergies['00000001'].status='suspected'});
altered('n1f-duplicate-attention.json',s=>{s.attentions[1].id=s.attentions[0].id});
const reverse=v=>Array.isArray(v)?v.map(reverse):
 v!==null&&typeof v==='object'?Object.fromEntries(Object.keys(v).reverse().map(k=>[k,reverse(v[k])])):v;
save('n1f-reordered.json',reverse(snapshot));
console.log('PASS N1f: fictional worker corrections, draft history, allergies and all optional JSON fields generated.');
