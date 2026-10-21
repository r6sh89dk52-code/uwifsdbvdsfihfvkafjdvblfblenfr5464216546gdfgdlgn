// HONOR X5 Plus — deterministic no-data worker search equivalence test.
// No network, real DNI, clinical data, or device profiling in this script.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const ts=require('typescript');
const {performance}=require('node:perf_hooks');
const pathname='src/workerSearchIndex.ts';
const compiled=ts.transpileModule(fs.readFileSync(pathname,'utf8'),{
 fileName:pathname,reportDiagnostics:true,
 compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}
});
assert.deepEqual((compiled.diagnostics||[]).filter(x=>x.category===ts.DiagnosticCategory.Error).map(x=>ts.flattenDiagnosticMessageText(x.messageText,' ')),[]);
const mod={exports:{}};
vm.runInNewContext(compiled.outputText,{exports:mod.exports,module:mod},{filename:pathname});
const {buildWorkerSearchIndex,findIndexedWorkers}=mod.exports;
const workers=Array.from({length:10000},(_,i)=>({
 dni:String(i+100000).padStart(8,'0'),name:i%2===0?'ÁLVAREZ FICTICIO '+i:'ÑÚÑEZ PRUEBA '+i,
 area:'SIMULADA',labor:'TEST'
}));
const frozen=workers.map(x=>Object.freeze(x));
const t0=performance.now();
const index=buildWorkerSearchIndex(frozen);
const indexMs=performance.now()-t0;
assert.equal(index.length,frozen.length);
assert(index.every((x,i)=>x.worker===frozen[i]),'references unchanged');
const normalize=(v)=>v.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLocaleLowerCase('es').trim();
const oldSearch=(q)=>frozen.filter(w=>normalize(w.name).includes(normalize(q))||w.dni.includes(q.trim())).slice(0,25);
for(const query of ['', 'ÁLVAREZ','alvarez','nunez','00001000','00100000','ÑÚÑEZ','xyz', '  prueba  ', '00010001','Á']){
 const actual=findIndexedWorkers(index,query,25);
 const old=oldSearch(query);
 assert.equal(actual.length,old.length,'count for '+JSON.stringify(query));
 assert(actual.every((x,i)=>x===old[i]),'order/identity for '+JSON.stringify(query));
}
assert.equal(findIndexedWorkers(index,'',0).length,0);
assert.equal(findIndexedWorkers(index,'',25).length,25);
assert.equal(index[0].worker.name,'ÁLVAREZ FICTICIO 0');
const app=fs.readFileSync('src/main.tsx','utf8');
for(const marker of [
 "import {buildWorkerSearchIndex,findIndexedWorkers} from './workerSearchIndex'",
 'const workerIndex=useMemo(()=>buildWorkerSearchIndex(workerList),[workerList]);',
 "page==='workers'?findIndexedWorkers(workerIndex,workerQuery,25):[]",
 'const prior=workerByDni.get(dni);',
 'const sortedHistory=useMemo(()=>[...att].sort((a,b)=>b.updatedAt-a.updatedAt),[att]);',
 'const visibleHistory=page===\'history\'?sortedHistory.slice(0,historyLimit):[];',
 'Mostrar 60 atenciones más',
 'countUnmatchedHistoryItems(a)',
 'canDeleteUnlinkedAttention(a.id,a.status,ledger.movements)',
 'workerInRoster:workerList.some',
 'writeDemoSnapshot(snapshotRef.current)'
]) assert(app.includes(marker),'missing UI/data-preservation requirement: '+marker);
const jsx=ts.transpileModule(app,{fileName:'src/main.tsx',reportDiagnostics:true,
 compilerOptions:{jsx:ts.JsxEmit.ReactJSX,module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022}});
assert.equal((jsx.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).length,0,'main.tsx syntax');
console.log('PASS: indexed search matches original results over 10000 synthetic workers; history is progressive; security/FEFO guards intact.');
console.log('Synthetic index creation ms (host benchmark, NOT HONOR FPS): '+indexMs.toFixed(1));
