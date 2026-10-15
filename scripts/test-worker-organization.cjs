// Stage D: two verified worksites, persistent staff corrections, explicit verification,
// return to clinical encounter and guarded deletion. All sensitive use is fictitious.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ts=require('typescript');const read=path=>fs.readFileSync(path,'utf8');
const org=read('src/danperWorksites.ts'),deleteCode=read('src/safeAttentionDeletion.ts');
const catalog=JSON.parse(read('src/ambulatoryTemplate.json'));
for(const p of ['LA VENTUROSA','PLVENTUROSA']){
 assert(catalog.subdivisions.some(s=>s[0]===p),'official source must contain '+p);
}
function exportsFor(code,file){
 const compiler={fileName:file,compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS,esModuleInterop:true},reportDiagnostics:true};
 const emitted=ts.transpileModule(code,compiler);
 assert.deepEqual((emitted.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).map(d=>ts.flattenDiagnosticMessageText(d.messageText,' ')),[]);
 const exports={};vm.runInNewContext(emitted.outputText,{exports,require:p=>{assert.equal(p,'./ambulatoryTemplate.json');return catalog}});
 return exports;
}
const mapping=exportsFor(org,'src/danperWorksites.ts');
assert.equal(mapping.DANPER_WORKSITES.length,2);
assert.deepEqual([...mapping.DANPER_WORKSITES.map(s=>s.code)],['A071','I031']);
assert(mapping.validDanperWorksite('LA VENTUROSA'));
assert(mapping.validDanperWorksite('PLVENTUROSA'));
assert(!mapping.validDanperWorksite('CHEPEN'));
assert.equal(mapping.workerDetailsMissing({area:'',labor:''}).length,2);
assert.equal(mapping.workerDetailsMissing({area:'SERVICIOS DE SALUD',labor:'ENFERMERO'}).length,0);
const removal=exportsFor(deleteCode,'src/safeAttentionDeletion.ts').canDeleteUnlinkedAttention;
assert.equal(removal('a','draft',[]).allowed,false);
assert.equal(removal('a','saved',[]).allowed,true);
assert.equal(removal('a','saved',[{dispenseRef:{attentionId:'b'}}]).allowed,true);
assert.equal(removal('a','saved',[{dispenseRef:{attentionId:'a'}}]).allowed,false);
const main=read('src/main.tsx'),worker=read('src/workerRules.ts'),roster=read('src/operationalRoster.ts');
for(const value of [
 'workerNeedsProfileSave','workerDetailsMissing(w)',
 'validDanperWorksite(w.site)','setWorkerProfileAlert(profile)',
 'function editActiveWorkerProfile()','setWorkerForm({...emptyWorker,...existing,...active.worker})',
 'workerReturn===\\'register\\'','Guardar ficha y volver a atención',
 'localCorrectionAt:Date.now()','writeDemoSnapshot(snapshot)',
 'workerManualCheck','verifiedManualWorker','rosterStatus:existingStatus',
 'Sede del trabajador','Sede<select','DANPER_WORKSITES.map(site=',
 'canDeleteUnlinkedAttention(target.id,target.status,ledger.movements)',
 'async function deleteSavedAttention',
 'eliminación bloqueada','Eliminar atención',
 "import './workerOrganization.css'"
]){assert(main.includes(value.replaceAll("\\'","'")),'missing UI contract: '+value);}
assert(worker.includes('site?:string'));
assert(worker.includes('localCorrectionAt?:number'));
assert(roster.includes("source:corrected?'manual'"),'re-import must retain local changes');
assert(roster.includes('area:row.area||replacement.area'));
const ambulatory=read('src/AmbulatoryExportPanel.tsx');
assert(ambulatory.includes('DANPER_WORKSITES.map(p='));
assert(!ambulatory.includes('templateLayout.subdivisions.map(p='));
assert(ambulatory.includes('siteConflicts.length>0||withoutSite.length>0||busy'));
assert(ambulatory.includes('no se asignarán códigos por suposición.'));
const store=read('src/secureDemoStore.ts');
assert(store.includes('writeWorkerVault(safe.workers)'));
assert(store.includes('writeClinicalVault({...safe,workers:[]})'));
for(const path of ['src/main.tsx','src/danperWorksites.ts','src/safeAttentionDeletion.ts','src/AmbulatoryExportPanel.tsx','src/workerRules.ts','src/operationalRoster.ts']){
 const result=ts.transpileModule(read(path),{fileName:path,reportDiagnostics:true,
  compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext,jsx:ts.JsxEmit.ReactJSX,resolveJsonModule:true}});
 assert.deepEqual((result.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).map(d=>ts.flattenDiagnosticMessageText(d.messageText,' ')),[],path+' syntax');
}
const ios=read('.github/workflows/ios-ipa.yml');
assert(ios.includes("if: github.event_name == 'workflow_dispatch' || (github.event_name == 'push' && github.ref == 'refs/heads/main')"));
console.log('PASS: only La Venturosa + PL Venturosa, staff completion, verified manual edits, durable vault, audit-preserving delete and no macOS PR.');
