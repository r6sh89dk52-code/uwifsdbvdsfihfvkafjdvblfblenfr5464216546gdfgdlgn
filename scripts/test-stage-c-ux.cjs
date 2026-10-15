// Stage C: interactive Kardex dashboard and official exporters remain safe and guided.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ts=require('typescript');
const read=(f)=>fs.readFileSync(f,'utf8');
const workspace=read('src/KardexWorkspace.tsx');
const panel=read('src/KardexPanel.tsx');
const daily=read('src/KardexDailyExport.tsx');
const ambulatory=read('src/AmbulatoryExportPanel.tsx');
const app=read('src/main.tsx');
const css=read('src/stageC.css');
const core=read('src/cohesiveExperience.css');
const check=(source,arr,name)=>arr.forEach(token=>assert(source.includes(token),name+': missing '+token));
check(workspace,[
 '¿Qué necesitas hacer?',
 'onClick={()=>navigate(\'inventory\')}','onClick={()=>navigate(\'movements\')}',
 'onClick={()=>navigate(\'deliveries\')}','onClick={()=>navigate(\'reports\')}',
 'ledger.movements.length','ledger.lots.length===0',
 '<KardexPanel ledger={ledger}','<KardexDailyExport ledger={ledger}',
 '<AttentionDeliveryPanel attentions={attentions}'
],'Kardex overview');
check(panel,[
 "const[entryOpen,setEntryOpen]=useState(lots.length===0)",
 'setEntryOpen(true);',
 'aria-expanded={entryOpen}',
 'aria-controls="kardex-entry-form"',
 'hidden={!entryOpen}',
 'id="kardex-entry-form"',
 '<KardexProductSearch label="Producto oficial"',
 'validateStockLot(raw)',
 "ledger.movements.some(m=>m.lotId===editId)",
 'onChange({...ledger,lots:','<h3><ClipboardList size={18}/>Inventario registrado</h3>'
],'Inventory');
check(daily,[
 'stageCProgress','stageCExportStep',
 '1</span> Elegir fechas y modalidad','2</span> Revisar el Kardex y recuentos',
 '3</span> Exportar el Excel oficial',
 'buildDailyReport(ledger,date,counts)',
 'buildKardexRangeReport(ledger,from,to,counts)',
 'exportOfficialKardex(template,result.report',
 'type="number" inputMode="decimal"',
 "mode==='daily'&&!turn",
 "result.report?.exportable",
 'shareXlsx(',
 'F/S se calcula únicamente a partir de los recuentos físicos introducidos'
],'Official daily reports');
check(ambulatory,[
 'stageCProgress','stageCExportStep',
 '1</span> Elegir período y lugar de reporte','2</span> Comprobar atenciones y existencias',
 '3</span> Crear archivo y compartir',
 'buildAmbulatoryRows(attentions,ledger,start,end',
 'sharedMonthlyReconciliation(ledger,result.data)',
 'exportAmbulatoryWorkbook(internalTemplate(),result.data,shared.data)',
 'result.data.blockers.length>0','disabled={!subdivision',
 "subdivision",
 "No debes importar ningún Excel",
 "shareXlsx("
],'Official ambulatory workbook');
check(app,["import './stageC.css';","import './cohesiveExperience.css'"],'Styles integration');
check(css,['.kardexGuide','.kardexEntryBody[hidden]','.stageCProgress','.stageCExportStep',
 '.page-ambulatory','.page-kardex','prefers-reduced-motion:reduce'],'Responsive design');
assert(!app.includes('diagnosisFloatingSuggestions'),'discarded v0.21.2 portal must stay excluded');
check(core,['.page-home','.page-register','.page-kardex','.page-ambulatory','.page-settings'],'A and B must stay coherent');
for(const file of ['src/KardexWorkspace.tsx','src/KardexPanel.tsx','src/KardexDailyExport.tsx','src/AmbulatoryExportPanel.tsx','src/main.tsx']){
 const result=ts.transpileModule(read(file),{fileName:file,reportDiagnostics:true,
  compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.ESNext,jsx:ts.JsxEmit.ReactJSX,
   moduleResolution:ts.ModuleResolutionKind.Bundler,resolveJsonModule:true}});
 const errors=(result.diagnostics||[]).filter(x=>x.category===ts.DiagnosticCategory.Error);
 assert.deepEqual(errors.map(e=>ts.flattenDiagnosticMessageText(e.messageText,' ')),[],file+' TypeScript JSX syntax');
}
console.log('PASS: Stage C guided Kardex, expandable preserved inventory, both Excel flows, guards and v0.21.2 exclusion.');
