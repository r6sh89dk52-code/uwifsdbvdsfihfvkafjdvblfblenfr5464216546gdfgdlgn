const fs=require('node:fs'),path=require('node:path'),ts=require('typescript');
const {DOMParser,XMLSerializer}=require('@xmldom/xmldom');
const cache=new Map();
function load(file){
 const absolute=path.resolve(file);
 if(cache.has(absolute))return cache.get(absolute);
 if(file.endsWith('.json'))return JSON.parse(fs.readFileSync(absolute,'utf8'));
 const source=ts.transpileModule(fs.readFileSync(absolute,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,esModuleInterop:true},reportDiagnostics:true});
 const errors=source.diagnostics.filter(d=>d.category===ts.DiagnosticCategory.Error);
 if(errors.length)throw Error('TS transpilation failed: '+file);
 const module={exports:{}};cache.set(absolute,module.exports);
 const localRequire=name=>name.startsWith('.')?load(path.resolve(path.dirname(absolute),name+(path.extname(name)?'':'.ts'))):require(name);
 new Function('require','module','exports','DOMParser','XMLSerializer',source.outputText)(localRequire,module,module.exports,DOMParser,XMLSerializer);
 return module.exports;
}
const M='http://schemas.openxmlformats.org/spreadsheetml/2006/main';
const parse=text=>new DOMParser({onError(level,message){if(level==='error'||level==='fatalError')throw Error('XML inválido: '+message)}}).parseFromString(text,'application/xml');
const all=(doc,tag)=>Array.from(doc.getElementsByTagNameNS(M,tag));
const value=c=>c.getAttribute('t')==='inlineStr'?all(c,'t').map(t=>t.textContent).join(''):all(c,'v')[0]?.textContent||'';
function visit(id='a',items=[]){return{id,status:'saved',date:'2026-10-13',time:'08:25',worker:{dni:'00000001',name:'PERSONA FICTICIA UNO',area:'PRODUCCION AGRICOLA PALTO',labor:'PRUEBA',sex:'F',age:'22',ubigeo:'ZONA FICTICIA'},category:'ENFERMEDAD',system:'RESPIRATORIO',segment:'',diagnosis:'DX FICTICIO',items,permission:'NO',workStatus:'LABORANDO',permissionTime:'',blueBandage:false,returned:false,photoSent:false,responsible:'RESPONSABLE FICTICIO',responsibleDni:'00000002',standaloneProcedures:['OBSERVACION']};}
const options={subdivision:'LA VENTUROSA'};
module.exports={load,parse,all,value,visit,options,M};
