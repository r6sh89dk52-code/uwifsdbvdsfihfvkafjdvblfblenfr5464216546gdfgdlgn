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

const paginate=mod.exports.paginateIndexedWorkers;
assert.equal(typeof paginate,'function');
const pages=[];
for(let p=0;p<400;p++){
 const slice=paginate(index,'',p,25);
 assert.equal(slice.page,p);
 assert.equal(slice.pageCount,400);
 assert.equal(slice.total,10000);
 assert.equal(slice.first,p*25+1);
 assert.equal(slice.last,(p+1)*25);
 assert.equal(slice.workers.length,25);
 for(let i=0;i<25;i++)assert.equal(slice.workers[i],frozen[p*25+i],'no missing or duplicate workers on page '+p);
 pages.push(slice.workers.length);
}
assert.equal(pages.reduce((a,b)=>a+b,0),10000);
const last=paginate(index,'',100000,25);
assert.equal(last.page,399,'oversized page clamps to last');
assert.equal(last.workers[0],frozen[9975],'last page must not be empty');
const none=paginate(index,'NOT FOUND',99,25);
assert.equal(none.total,0);
assert.equal(none.page,0);
assert.equal(none.pageCount,0);
assert.equal(none.workers.length,0);
const partial=paginate(index,'ÁLVAREZ',1,25);
assert.equal(partial.total,5000);
assert.equal(partial.pageCount,200);
assert.deepEqual([...partial.workers.map(w=>w.dni)],[...frozen.filter(x=>x.name.includes('ÁLVAREZ')).slice(25,50).map(w=>w.dni)]);
const nameQuery=paginate(index,'nunez',0,25);
assert.equal(nameQuery.total,5000,'search must work across entire roster');
const only=paginate(index,'00100001',0,25);
assert.equal(only.total,1,'DNI search must work across all 400 pages');
assert.equal(only.workers[0],frozen[1]);
const short=paginate(index.slice(0,26),'',1,25);
assert.equal(short.total,26);
assert.equal(short.first,26);
assert.equal(short.last,26);
assert.equal(short.workers.length,1);

const app=fs.readFileSync('src/main.tsx','utf8');
for(const marker of [
 "import {buildWorkerSearchIndex,findIndexedWorkers} from './workerSearchIndex'",
 'const workerIndex=useMemo(()=>buildWorkerSearchIndex(workerList),[workerList]);',
 "page==='workers'",
 'paginateIndexedWorkers(workerIndex,workerQuery,workerPage,25)',
 'const filteredWorkers=workerPageData.workers;',
 'workerSearchPanelRef.current?.scrollIntoView({block:\'start\',behavior:\'auto\'})',
 'setWorkerPage(0)',
 'className="workerPagination"',
 'Página {workerPageData.page+1} de {workerPageData.pageCount}',
 'disabled={workerPageData.page===0}',
 'disabled={workerPageData.page>=workerPageData.pageCount-1}',
 'const prior=workerByDni.get(dni);',
 'const sortedHistory=useMemo(()=>[...att].sort((a,b)=>b.updatedAt-a.updatedAt),[att]);',
 'const visibleHistory=page===\'history\'?sortedHistory.slice(0,historyLimit):[];',
 'Mostrar 60 atenciones más',
 'countUnmatchedHistoryItems(a)',
 'canDeleteUnlinkedAttention(a.id,a.status,ledger.movements)',
 'workerInRoster:workerList.some',
 'writeDemoSnapshot(snapshotRef.current)'
]) assert(app.includes(marker),'missing UI/data-preservation requirement: '+marker);

// Importar PERSONAL is moved only in normal operation; emergency vault recovery stays available.
const workersView=app.indexOf("{page==='workers'&&");
const settingsView=app.indexOf("{page==='settings'&&");
const historyView=app.indexOf("{page==='history'&&");
assert(workersView>0&&historyView>workersView&&settingsView>historyView);
const workersMarkup=app.slice(workersView,historyView);
const settingsMarkup=app.slice(settingsView,app.indexOf('</main>',settingsView));
assert(!workersMarkup.includes('<PersonalImporter'),"normal workers view must not contain Excel importer");
assert(settingsMarkup.includes('<PersonalImporter current={workers}'),"Settings must include importer");
assert(settingsMarkup.includes('await writeDemoSnapshot({...snapshotRef.current,workers:updated})'),
 'Settings import must verify encrypted persistence before success');
assert.equal((app.match(/<PersonalImporter current={workers}/g)||[]).length,2,
 'retain existing emergency recovery importer');
assert(workersMarkup.includes('Para importar o actualizar el padrón desde Excel'));
assert(workersMarkup.includes('aria-label="Página siguiente de trabajadores"'));
assert(workersMarkup.includes('aria-label="Página anterior de trabajadores"'));

const jsx=ts.transpileModule(app,{fileName:'src/main.tsx',reportDiagnostics:true,
 compilerOptions:{jsx:ts.JsxEmit.ReactJSX,module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022}});
assert.equal((jsx.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).length,0,'main.tsx syntax');
console.log('PASS: 10000-worker original search parity; all 400 pages without gaps; global search, Settings import and clinical guards intact.');
console.log('Synthetic index creation ms (host benchmark, NOT HONOR FPS): '+indexMs.toFixed(1));
