// v0.21.6: user-entered full DNI can offer an optional worker registration.
// The clinical roster is still the authority: a manual ficha does not bypass verification.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ts=require('typescript');
const vm=require('node:vm');
const read=(p)=>fs.readFileSync(p,'utf8');
const compiled=ts.transpileModule(read('src/workerDiscovery.ts'),{
 fileName:'workerDiscovery.ts',
 compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},
 reportDiagnostics:true
});
assert.equal((compiled.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).length,0);
const exposed={};vm.runInNewContext(compiled.outputText,{exports:exposed});
const offer=exposed.shouldOfferWorkerRegistration;
assert.equal(offer('00000001',[],true,null),true);
assert.equal(offer('00000001',['00000001'],true,null),false,'known worker no dialog');
assert.equal(offer('0000000',[],true,null),false,'do not prompt before 8 digits');
assert.equal(offer('abc00001',[],true,null),false,'only numeric DNI');
assert.equal(offer('00000001',[],false,null),false,'do not prompt before encrypted directory loads');
assert.equal(offer('00000001',[],true,'00000001'),false,'closing suppresses repeated modal');
assert.equal(offer('00000002',[],true,'00000001'),true,'different unknown DNI can prompt');
const main=read('src/main.tsx'),style=read('src/workerAndReportClarity.css');
for(const needle of [
 "import {shouldOfferWorkerRegistration} from './workerDiscovery'",
 'registerStep!==0',
 'active.status===\'saved\'',
 'setUnknownWorkerDni(current=>current===dni?current:dni),500',
 'role="alertdialog"',
 'aria-modal="true"',
 'Trabajador no encontrado',
 '>Registrar trabajador</button>',
 '>Cerrar</button>',
 "setWorkerForm({...emptyWorker,...active?.worker,dni})",
 "officialRosterActive(workers as OperationalWorker[])",
 "workerClinicalFields",
 '<textarea rows={2} value={active.worker.name}',
 'OfficialAreaField className="workerFieldArea" site={active.worker.site}',
 '<textarea rows={2} value={active.worker.labor}',
 "setUnknownWorkerDni(null)",
 "import './workerAndReportClarity.css'"
])assert(main.includes(needle),'attention UI missing: '+needle);
assert(main.includes('workerInRoster:workerList.some'),'official validation must stay active');
assert(main.includes("verificationRequired&&!verifiedManualWorker"),'unverified manual entries must be blocked by official roster');
assert(main.includes("rosterStatus:existingStatus==='official'?'official' as const"),'official status may only be kept for an already official worker');
for(const needle of ['.workerClinicalFields','grid-column:1 / -1','.workerDiscoveryOverlay','z-index:1400','.workerDiscoveryActions','max-height:90dvh','.reconciliationExplainer','.stageCExportStep']){
 assert(style.includes(needle),'styles missing '+needle);
}
const workspace=read('src/KardexWorkspace.tsx');
for(const t of ['¿Qué necesitas hacer?','Inventario físico','Entradas y salidas','Entrega de insumos','Exportar Kardex',"navigate('inventory')","navigate('movements')","navigate('deliveries')","navigate('reports')"])assert(workspace.includes(t),'Kardex clarity missing '+t);
assert(!workspace.includes('kardexSectionGrid'),'Kardex no duplicate tiles');
const report=read('src/AmbulatoryExportPanel.tsx');
for(const t of ['No tienes que adjuntar ninguna plantilla','Elegir período y lugar de reporte','Sede o fundo del reporte','Comprobar atenciones y existencias','Generar Excel (10 hojas) y compartir','sharedMonthlyReconciliation(ledger,result.data)','exportAmbulatoryWorkbook(internalTemplate(),result.data,shared.data)','result.data.blockers.length>0'])assert(report.includes(t),'report UI must preserve contract: '+t);
const returnPanel=read('src/ReconciliationPanel.tsx');
for(const t of ['Revisar productos y devoluciones','¿Qué significa una equivalencia?','¿Qué significa una incidencia?','sin modificar existencias','recordDeliveryIncident(ledger,incidents'])assert(returnPanel.includes(t),'reconciliation wording must retain audit logic: '+t);
for(const path of ['src/main.tsx','src/KardexWorkspace.tsx','src/AmbulatoryExportPanel.tsx','src/ReconciliationPanel.tsx']){
 const d=ts.transpileModule(read(path),{fileName:path,reportDiagnostics:true,compilerOptions:{
  target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext,
  jsx:ts.JsxEmit.ReactJSX,moduleResolution:ts.ModuleResolutionKind.Bundler,resolveJsonModule:true
 }});
 assert.deepEqual((d.diagnostics||[]).filter(x=>x.category===ts.DiagnosticCategory.Error).map(x=>ts.flattenDiagnosticMessageText(x.messageText,' ')),[],path);
}
const workflow=read('.github/workflows/ios-ipa.yml');
assert(workflow.includes("if: github.event_name == 'workflow_dispatch' || (github.event_name == 'push' && github.ref == 'refs/heads/main')"),'do not spend macOS PR minutes');
console.log('PASS: readable worker identity, optional safe registration, official roster, Kardex/report plain language, TSX and macOS quota.');
