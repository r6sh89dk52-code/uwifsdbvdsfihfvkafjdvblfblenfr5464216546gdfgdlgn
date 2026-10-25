'use strict';
// Static guardrail only. It does NOT replace Swift/Xcode UI or clinical tests.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'src/main.tsx'),'utf8');
const home=fs.readFileSync(path.join(root,'native-ios/App/NativeRootView.swift'),'utf8');
const form=fs.readFileSync(path.join(root,'native-ios/App/N2NativeClinicalFormView.swift'),'utf8');
const osteomuscular=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2OsteomuscularSegments.swift'),'utf8');
const draftDashboard=fs.readFileSync(path.join(root,'native-ios/App/N2NativeDraftsDashboard.swift'),'utf8');
for(const item of [
  'ZONA CERVICAL,DORSAL,LUMBAR Y SACRA','ZONA CERVICAL','ZONA DORSAL',
  'ZONA LUMBAR','ZONA SACRA','PIE','PIERNA','RODILLA','TOBILLO',
  'PRIMERO, SEGUNDO ,TERCERO, CUARTO Y QUINTO DEDO DERECHO E IZQUIERDO'
]) assert(osteomuscular.includes(item),
  'Debe conservar opciones anatómicas históricas y específicas: '+item);
for(const marker of [
  'DanperChoiceField(title:"Segmento osteomuscular"',
  'selection:segmentChoice',
  'N2OsteomuscularSegments.options +',
  'TextField("Describe la zona afectada",text:$form.segment)',
  'clinical-osteomuscular-segment-choice'
]) assert(form.includes(marker),
  'El segmento osteomuscular debe poder seleccionarse o especificarse: '+marker);
for(const marker of [
  'draft-dashboard-delete-','Button(role:.destructive)',
  'selectedDeleteID=draft.id',
  'id:id,expectedRevision:expectedRevision)',
  'N2DraftReminder.cancel(id:id,mode:vault.mode)',
  'confirmationDialog("¿Eliminar este borrador?"'
]) assert(draftDashboard.includes(marker),
  'Borrar borrador debe estar disponible y ser confirmado en el tablero: '+marker);
assert(!draftDashboard.includes('Para borrar un borrador, ábrelo'),
  'El borrador ya no debe requerir abrir el formulario para poder eliminarlo');
for(const marker of [
  'let latest=try await vault.readDraftsWithRevision()',
  'let expectedRevision=loadedRevision',
  'let prior=records',
  'records.removeAll(where:{$0.id==id})',
  'records=prior',
  'loadedRevision=confirmed.revision'
]) assert(draftDashboard.includes(marker),
  'Borradores necesitan una única lectura y eliminación inmediata reversible: '+marker);
assert(!draftDashboard.includes('vault.inspect()') &&
       !draftDashboard.includes('vault.readDrafts()'),
       'El listado no debe descifrar varias veces la base por eliminación');

assert(draftDashboard.includes(
  '.accessibilityLabel("Eliminar borrador de " + (draft.workerName.isEmpty ? "trabajador sin seleccionar" : draft.workerName))'),
  'la etiqueta accesible de la papelera debe ser una expresión Swift válida');
console.log('PASS: segmento osteomuscular seleccionable y eliminación directa/confirmada de borradores.');
const editor=fs.readFileSync(path.join(root,'native-ios/App/N2NativeWorkerEditorView.swift'),'utf8');
const kardex=fs.readFileSync(path.join(root,'native-ios/App/N2Build222KardexHub.swift'),'utf8');
const inventory=fs.readFileSync(path.join(root,'native-ios/App/N2NativeInventoryView.swift'),'utf8');
const catalog=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2NativeCatalogIndex.swift'),'utf8');
const indicator=fs.readFileSync(path.join(root,'native-ios/App/N2VerifiedIndicatorExportView.swift'),'utf8');
const nursing=fs.readFileSync(path.join(root,'native-ios/App/N2VerifiedNursingExportView.swift'),'utf8');
const clinicalSettings=fs.readFileSync(path.join(root,'native-ios/App/N2ClinicalWorkspaceView.swift'),'utf8');
for(const settings of [home,clinicalSettings,indicator]) {
  assert(!settings.includes('N2ReconciliationView()'),
    'no reenlazar la antigua conciliación de inventarios por sede');
}

const reportStages=fs.readFileSync(path.join(root,'native-ios/App/N2Build222ExportStages.swift'),'utf8');
const clinicalRules=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2ProcedureRules.swift'),'utf8');
const palette=fs.readFileSync(path.join(root,'native-ios/App/DanperUITheme.swift'),'utf8');
const blank=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2EmptyDemoSnapshot.swift'),'utf8');
const core=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift'),'utf8');
const demo=fs.readFileSync(path.join(root,'native-ios/App/N2SyntheticTrialIOSVault.swift'),'utf8');
const reset=fs.readFileSync(path.join(root,'native-ios/App/N2DemoResetView.swift'),'utf8');
const personal=fs.readFileSync(path.join(root,'native-ios/App/N2NativePersonalImportView.swift'),'utf8');
const app=fs.readFileSync(path.join(root,'native-ios/App/DANPERNativeApp.swift'),'utf8');
const clinicalHome=fs.readFileSync(path.join(root,'native-ios/App/N2ClinicalWorkspaceView.swift'),'utf8');
const rosterSearch=fs.readFileSync(path.join(root,'native-ios/App/N2WorkerSearchSheet.swift'),'utf8');
const medicationRow=fs.readFileSync(path.join(root,'native-ios/App/N2MedicationRowView.swift'),'utf8');
const cutCore=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2KardexCutPreview.swift'),'utf8');
const cutView=fs.readFileSync(path.join(root,'native-ios/App/N2KardexCutPreviewView.swift'),'utf8');
const autoAccounting=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2AutomaticCutAccounting.swift'),'utf8');
const vaultSource=fs.readFileSync(path.join(root,'native-ios/App/N2ProtectedClinicalIOSVault.swift'),'utf8');
const clinicalTx=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2ClinicalTransactions.swift'),'utf8');
const pendingResolution=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2PendingResolution.swift'),'utf8');
const batchReviewed=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2UserReviewedKardexLinks.swift'),'utf8');
const officialWriter=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N1sNursingExcelWriter.swift'),'utf8');
const mappingCore=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2OperationalMapping.swift'),'utf8');
const mappingView=fs.readFileSync(path.join(root,'native-ios/App/N2OperationalMappingView.swift'),'utf8');

const history=fs.readFileSync(path.join(root,'native-ios/App/N2NativeHistoryView.swift'),'utf8');
const theme=fs.readFileSync(path.join(root,'native-ios/App/DanperUITheme.swift'),'utf8');
const firstWorker=fs.readFileSync(path.join(root,'native-ios/App/N2FirstManualWorkerView.swift'),'utf8');
const must=(data,needle,label)=>assert(data.includes(needle),`Falta ${label}: ${needle}`);
// In DANPER's historical ambulance workbook, "UBIGEO" contains locality
// names (CHEPÉN/TRUJILLO), never a numeric-only entry restriction.
for(const [label,view,identifier] of [
  ['registro y edición de PERSONAL',editor,'worker-ubigeo-locality'],
  ['primer trabajador de nueva bóveda',firstWorker,'first-manual-worker-ubigeo']
]) {
  const start=view.indexOf('DanperField(title:"Ubigeo / localidad (opcional)")');
  assert(start>=0,label+': falta campo de localidad');
  const section=view.slice(start,start+520);
  assert(section.includes('.keyboardType(.default)') &&
         !section.includes('.keyboardType(.numberPad)') &&
         section.includes('.textInputAutocapitalization(.characters)') &&
         section.includes(identifier),
         label+': Ubigeo debe aceptar letras, espacios y tildes');
}
must(editor,'"ubigeo":ubigeo.trimmingCharacters(in:.whitespacesAndNewlines)',
  'la edición guarda localidad completa sin normalizarla a dígitos');
must(firstWorker,'"ubigeo":ubigeo.trimmingCharacters(in:.whitespacesAndNewlines)',
  'el primer trabajador guarda localidad ingresada, no cadena vacía');
console.log('PASS: Ubigeo de ciudades escrito en letras, en alta, edición e inicio sin Excel.');
const exportedIndicatorCore=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2VerifiedIndicatorWorkbook.swift'),'utf8');
const vigilanceCodes=fs.readFileSync(path.join(root,
  'native-ios/Sources/DanperCore/N2VigilanceOrganizationCodes.swift'),'utf8');
const vigilanceExport=fs.readFileSync(path.join(root,
  'native-ios/Sources/DanperCore/N2OccupationalVigilanceWorkbook.swift'),'utf8');
const vigilanceView=fs.readFileSync(path.join(root,
  'native-ios/App/N2OccupationalVigilanceExportView.swift'),'utf8');
for(const required of [
  '1003|SERVICIOS DE SALUD|20000136',
  '1001|SERVICIOS DE SALUD|20000066',
  '1003|PRODUCCION AGRICOLA PALTO|20000126',
  '1001|ASEGURAMIENTO DE LA CALIDAD FRESCO|20000101',
  'return ("1003","A071")',
  'return ("1001","I031")'
]) must(vigilanceCodes,required,
  'Vigilancia conserva los catálogos oficiales por sociedad y sede');
must(vigilanceExport,'N2VigilanceOrganizationCodes.resolve(',
  'Vigilancia completa C/D por atención');
must(vigilanceExport,'codes.subdivision,codes.organizationalUnit',
  'Vigilancia escribe los códigos C y D en la hoja original');
must(vigilanceView,'data.unresolvedOrganizationalUnits>0',
  'Vigilancia muestra unidades sin equivalencia sin inventar códigos');
console.log('PASS: vigilancia osteomuscular asigna A071/I031 y UO acreditada según sede y área.');
const indicatorWriter=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N1sFullExcelWriter.swift'),'utf8');
// New-attention and home counters reuse one VERIFIED clinical snapshot,
// retaining exactly the original journal validation and immutable revision.
const workspace=fs.readFileSync(path.join(root,'native-ios/App/N2WorkspaceVault.swift'),'utf8');
for(const filePath of [
  'native-ios/App/N2ProtectedClinicalIOSVault.swift',
  'native-ios/App/N2SyntheticTrialIOSVault.swift',
  'native-ios/App/N2WorkspaceVault.swift',
  'native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift'
]) {
  const src=fs.readFileSync(path.join(root,filePath),'utf8');
  assert(src.includes('readDraftsWithRevision()'),
    filePath+' debe exponer borradores con su revisión autenticada');
}
const recovered=fs.readFileSync(path.join(root,
  'native-ios/Sources/DanperCore/N2NativeDraftRecovery.swift'),'utf8');
assert(recovered.includes('static func readVerified(_ snapshot:Data)'),
  'La lectura cifrada verificada no debe repetir las auditorías completas');
assert(core.includes('N2NativeDraftRecovery.readVerified(active.snapshot)'),
  'La bóveda debe utilizar únicamente snapshots ya autenticados');
const auditedFormReader=fs.readFileSync(path.join(root,
  'native-ios/Sources/DanperCore/N2NativeFormContext.swift'),'utf8');
assert(auditedFormReader.includes('static func readVerified(snapshot:Data,revision:Int,products:N2NativeCatalogIndex)') &&
       auditedFormReader.includes('public static func read(snapshot:Data,revision:Int,products:N2NativeCatalogIndex)'),
  'El formulario debe conservar la lectura estricta de datos externos y la lectura optimizada de bóveda');


for(const marker of [
  'public func prepareClinicalForm(',
  'public func readDashboard()throws',
  'let context=try N2NativeFormContextReader.readVerified(',
  'let drafts=try N2NativeDraftRecovery.readVerified(active.snapshot)'
]) must(core,marker,'formulario e Inicio desde una sola recuperación cifrada');
for(const adaptor of [demo,vaultSource,workspace]) {
  for(const marker of ['prepareClinicalForm()', 'readDashboard()']) {
    must(adaptor,marker,'adaptador de lectura clínica única');
  }
}
must(form,'let prepared=try await vault.prepareClinicalForm()',
  'una recuperación autenticada para Nueva atención');
// Restrict this assertion to the INITIAL form load, not the entire View.
// Deleting an existing draft intentionally refreshes the draft list from
// the latest encrypted revision; that explicit user action must stay intact.
const initialFormLoadStart=form.indexOf('@MainActor private func load() async {');
const initialFormLoadEnd=form.indexOf('    @MainActor\n    private func recordAllergy(',initialFormLoadStart);
assert(initialFormLoadStart>=0 && initialFormLoadEnd>initialFormLoadStart,
  'No se pudo delimitar la carga inicial de Nueva atención');
const initialFormLoad=form.slice(initialFormLoadStart,initialFormLoadEnd);
assert(initialFormLoad.includes('vault.prepareClinicalForm()'),
  'La carga inicial debe compartir una única recuperación autenticada');
assert(!initialFormLoad.includes('vault.readDrafts()') &&
       !initialFormLoad.includes('vault.clinicalFormContext()'),
  'La carga inicial no debe recuperar dos veces la misma bóveda');
assert(form.includes('let freshRevision=try await vault.currentRevision()') &&
       form.includes('let prepared=try await vault.prepareClinicalForm()') &&
       form.includes('drafts=prepared.drafts') &&
       form.includes('context=prepared.context'),
  'Eliminar en el formulario debe refrescar borradores y contexto en una sola lectura');
assert(form.includes('let latestRevision=try await vault.currentRevision()') &&
       !form.includes('let latest=try await vault.clinicalFormContext()'),
  'Autosave debe consultar revisión cifrada sin reconstruir el padrón de trabajadores');
for(const filePath of [
  'native-ios/App/N2ProtectedClinicalIOSVault.swift',
  'native-ios/App/N2SyntheticTrialIOSVault.swift',
  'native-ios/App/N2WorkspaceVault.swift',
  'native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift'
]) {
  const src=fs.readFileSync(path.join(root,filePath),'utf8');
  assert(src.includes('currentRevision()'),
    filePath+' debe exponer revisión autenticada ligera');
}
// The former combined history reader remains available for other screens,
// but Home must call the newer direct counters instead of rebuilding a full
// roster/visit projection. Scope the guard to Home's refresh function.
const homeRefreshStart=clinicalHome.indexOf('private func refreshHomeCounts() async {');
const homeRefreshEnd=clinicalHome.indexOf('    private func homeMetric(',homeRefreshStart);
assert(homeRefreshStart>=0 && homeRefreshEnd>homeRefreshStart,
  'No se pudo delimitar la actualización de contadores de Inicio');
const homeRefresh=clinicalHome.slice(homeRefreshStart,homeRefreshEnd);
must(homeRefresh,'vault.dashboardCounters(',
  'Inicio debe consultar los contadores directos y cifrados');
assert(!homeRefresh.includes('vault.readDashboard()') &&
       !homeRefresh.includes('vault.readHistory()'),
  'Inicio no debe reconstruir el padrón ni el historial para mostrar las cifras');
console.log('PASS: Inicio y Nueva atención aprovechan una sola lectura cifrada, sin cachear datos clínicos.');
// Home counters and the 25-worker lookup should not repeatedly sort/rebuild
// a complete 9k-person index merely to show three numbers or one small page.
const formReader=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2NativeFormContext.swift'),'utf8');
const workerSearch=fs.readFileSync(path.join(root,'native-ios/App/N2WorkerSearchSheet.swift'),'utf8');
must(formReader,'let hasOfficialWorkers=w.contains',
  'la selección oficial del padrón se conserva');
must(formReader,'guard w.allSatisfy({',
  'la optimización no omite validaciones del padrón');
assert(!formReader.includes('N2NativeSnapshotReader.read(snapshot)'),
  'el formulario no puede reconstruir historial para filtrar trabajadores');
must(workerSearch,'private let pageSize=25','páginas reales de 25 trabajadores');
assert(!workerSearch.includes('.sorted{'),
  'la búsqueda nativa no debe reordenar los 9k registros en cada render');
for(const source of [core,workspace,vaultSource,demo]) {
  must(source,'dashboardCounters(','contador rápido por estado validado');
}
must(clinicalHome,'vault.dashboardCounters(',
  'Inicio calcula contadores sin generar el historial completo');
console.log('PASS: padrón 9k con orden único, 25 visibles, y contadores directos del diario cifrado.');
for(const marker of [
  'eligibleForSharedClose(',
  'end.hasSuffix("-08")',
  'projection.reportedUse==Double(used)',
  'projection.received==Double(income)',
  'expected==Int(physicalCount)',
  'N2PendingDispensingEvidence.read(snapshot:clinical)',
  'R histórico declarado='
]) assert(exportedIndicatorCore.includes(marker),'Protección de Indicador único: '+marker);
for(const marker of [
  'PERÍODO: ',
  'KARDEX AMBULATORIO · PROVISIONAL',
  'KARDEX AMBULATORIO · OFICIAL',
  'cachedNumber:sheet==4',
  'verifiedIncome:sheet==4 ? reconciledValues[row]?["E"]',
  'reconciledValues[row]=[',
  'opening+income-consumed==closing,closing==count'
]) assert(indicatorWriter.includes(marker),'Excel RESU conservado: '+marker);
assert(indicator.includes('endDate=min(cycleEnd,now)'),
  'el corte abierto debe exportarse a la fecha');
assert(indicator.includes('Button("Todas")'),
  'la selección completa para un corte debe ser explícita');
// Pending packages must remain in the provisional book without invented R.
for(const marker of [
  'R PENDIENTE. Cantidad clínica declarada=',
  'R PENDIENTE; declaración histórica sin correspondencia',
  'else if linesByItem[key] != nil',
  'if container {',
  'estimate.received==Double(income)',
  'row["verifiedIncome"]=income'
]) assert(exportedIndicatorCore.includes(marker),
  'Provisional conserva la atención y no inventa R: '+marker);
assert(!exportedIndicatorCore.includes('guard !container else{throw Failure.unverifiedDelivery}'),
  'un envase sin apertura no puede abortar el libro provisional completo');
for(const marker of [
  'documented>=missingR',
  'provisional,!reviewed'
]) assert(indicatorWriter.includes(marker),
  'OOXML permite R vacía solo en libros provisionales auditados: '+marker);

assert(nursing.includes('@State private var site="AMBAS"'),
  'El Kardex de Enfermeras exporta el inventario conjunto sin sede invisible');
assert(!nursing.includes('site.isEmpty ||'),
  'La exportación del Kardex no puede depender de un selector de sede eliminado');
must(nursing,'exportFailureMessage(error)',
  'el rechazo de Excel enfermería debe mostrar su causa');
must(indicator,'LabeledContent("Ámbito",value:"Fundo y Planta La Venturosa")',
  'el Indicador conserva ambas sedes sin separarlas en inventarios');
assert(!indicator.includes('N2ReconciliationView()'),
  'no enlazar una conciliación por sede obsoleta desde el Indicador único');
must(indicator,'if !allowed {selectConfirmed()}',
  'Modo provisional no debe agregar todas las atenciones pendientes sin permiso');

must(app,'N2ClinicalWorkspaceGateView(authenticatedLaunch:true)','inicio cifrado tras autenticación con importación PERSONAL');
assert(!app.includes('NativeRootView()'),'No puede abrirse el modo ficticio en inicio normal');
must(clinicalHome,'clinical-first-run-import-personal','importar PERSONAL como acción principal');
must(clinicalHome,'clinical-first-run-restore-222','restauración opcional Build222');
must(clinicalHome,'clinical-first-run-manual-worker','inicio manual sin Excel');
for(const phrase of ['DanperBrandHeader {','Bienvenido',
  'ACCESO RÁPIDO','Nueva atención','homeMetric('])
  must(clinicalHome,phrase,'cabecera y estructura de Inicio Build222');
for(const phrase of ['UIImage(named:"BrandLogo")',
  'Image(uiImage:Self.wordmark ?? UIImage())','danper-brand-header',
  'ignoresSafeArea(edges:.top)','Text("SALUD MÓVIL")'])
  must(theme,phrase,'cabecera roja con logo oficial');
for(const phrase of ['N2WorkerSearchSheet(workers:context.workers',
  'showWorkerSearch=true','attention-browse-workers','onSelect:{worker in'])
  must(form,phrase,'búsqueda real desde Paso 1');
for(const phrase of ['roster-global-search','roster-result-',
  'private let pageSize=25','onNewWorker()'])
  must(rosterSearch,phrase,'padrón nativo con una pulsación y páginas');
for(const phrase of ['private func issueCodes(for stage:Int',
  'private func focusFirstMissing','validationIssueCode',
  'scrollIssueRequest=DanperScrollRequest(fieldID:field)',
  'Button("Ir al campo")'])
  must(form,phrase,'validación por código, desplazamiento y foco');
for(const phrase of ['DanperScrollRequest:Equatable',
  'onChange(of:jumpRequest)','confirmationDialog(title'])
  must(theme,phrase,'componentes de navegación al error');
for(const phrase of ['Procedimientos independientes',
  'expand-other-procedures','treatment-medications',
  'medication-procedure-group-'])
  must(form,phrase,'tratamiento compacto y plegable');
for(const phrase of ['N2MedicationRowView(', 'independentProceduresSection()',
  'medicationPickerSection(context)', 'medicationGroup(group,context:context)'])
  must(form,phrase,'segmentación del formulario SwiftUI para Xcode');
for(const phrase of ['@Binding var medication:N2FormMedication',
  'context.options(for:medication.code,at:visitDate,site:dispensingSite)',
  'medication.procedureConfirmed=true',
  'medication.physicalQuantity=Double(medication.quantity)',
  'DanperCheckRow(selected:$medication.approveOpening)',
  'onRemove:()->Void'])
  must(medicationRow,phrase,'edición compacta enlazada al mismo FEFO y borrador');
must(medicationRow,'expandedID==medication.id','medicamentos compactos por defecto');
assert(!medicationRow.includes('expandedID==medication.id || medication.procedure.isEmpty'),
  'un medicamento nuevo no debe desplegar todos los controles');
must(form,'expandedMedication=nil','inserción compacta de nuevo producto');
for(const key of ['kardex-register-current-stock','kardex-ninth-cut-preview',
 'N2NativeInventoryView(initialOperation:"lot")','N2KardexCutPreviewView()'])
  must(kardex,key,'alta visible de stock y corte mensual');
for(const key of ['public static func period(for day:String)',
 'public static func calculate(asOf:String','verifiedUsed','laterReceipts',
 'signedAdjustments','requiresOperatorReconciliation'])
  must(cutCore,key,'reconstrucción matemática del día 9 sin mutaciones');
for(const key of ['KARDEX · UN SOLO INVENTARIO',
 'Resumen del corte mensual','automaticCutAccounting(through:format(Date()))',
 'Stock estimado al día 9','El detalle de consumos diarios está en el Excel Kardex de Enfermeras'])
  must(cutView,key,'conciliación automática desde atenciones, sin escrituras');
for(const key of ['visit["status"] as? String=="saved"',
 'line.daily[visitDay,default:0]+=n',
 'line.unlinked+=1',
 'line.unknownPackage+=1',
 'line.used+=debit',
 'let linked=Dictionary(grouping:movements'])
  must(autoAccounting,key,'contabilización automática y única de atenciones terminadas');
must(vaultSource,'func automaticCutAccounting(through date:String)',
     'consulta del inventario cifrado desde la fuente única');
// An unlinked opening cannot silently turn into a fabricated stock debit.
for(const fragment of [
  'blockedUnverifiedOpening=true',
  'Apertura pendiente: el stock inicial no se guardó',
  'El stock inicial del día 9 necesita esa apertura conciliada',
  'No contabilices una caja abierta como cerrada',
  'No se generó un descuento retroactivo automático'
]) must(inventory,fragment,'instrucciones de stock inicial y apertura sin lote');

const vaultCore=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift'),'utf8');
const workspaceVault=fs.readFileSync(path.join(root,'native-ios/App/N2WorkspaceVault.swift'),'utf8');
must(vaultCore,'public func automaticCutAccounting(mappings:Data,through date:String)',
     'API de lectura consolidada en la bóveda cifrada');
assert(!vaultSource.includes('readVerifiedSnapshot()'),
       'No invocar funciones inexistentes de lectura de inventario');
for (const [source,label] of [
  [workspaceVault,'N2WorkspaceVault'],
  [vaultSource,'bóveda clínica iOS'],
  [demo,'bóveda de demostración']
]) {
  must(source,'func automaticCutAccounting(through date:String)',
       'puente de lectura del corte mensual en '+label);
}
must(workspaceVault,'N2ProtectedClinicalIOSVault.shared',
     'N2WorkspaceVault: la fuente clínica sigue separada');
must(workspaceVault,'N2SyntheticTrialIOSVault.shared',
     'N2WorkspaceVault: la fuente sintética sigue separada');
assert(!/\+\s*\n\s*\(/.test(autoAccounting),
       'No dividir una concatenación Swift después del operador +');
must(autoAccounting,'[attentionID,itemID].joined(separator:',
     'clave única de atención/medicamento sin concatenación inválida');

for(const key of ['private static func historicalAt(',
 'if historical {','after["updatedAt"]=eventAt!',
 '"unit":before["catalogUnit"]!,"at":eventAt!'])
  must(clinicalTx,key,'FEFO de atención histórica sin alterar conteos posteriores');
must(nursing,'Desde el 9 hasta la fecha','exportación diaria, semanal y corte mensual');
assert(!cutView.includes('vault.addLot')&&!cutView.includes('vault.receiveStock') &&
       !cutView.includes('vault.reconcileCount'),
       'la estimación del corte no puede alterar existencias');


for(const phrase of ['rosterPage','matches.dropFirst(safePage*pageSize)',
  'Button("Siguiente")'])
  must(history,phrase,'paginación del Personal');

must(clinicalHome,'N2FirstManualWorkerView()','registro inicial sin archivo');
for(const phrase of ['N2EmptyDemoSnapshot.make()','N2SnapshotEditor.addWorker(',
  'activateOnlyWithConsent(source,approvedByUser:true)',
  'first-manual-worker-activate','.deviceOwnerAuthentication',
  'N2ProtectedClinicalIOSVault.shared.inspect()==nil'])
  must(firstWorker,phrase,'alta protegida del primer trabajador sin fuente precargada');
assert(!firstWorker.includes('activateSyntheticFixture(') &&
       !firstWorker.includes('startSyntheticDemo('),
       'El alta sin Excel no puede crear registros ficticios de demostración');
for(const fragment of [
  'authentication.canEvaluatePolicy(',
  'case .biometryNotEnrolled:',
  'case .passcodeNotSet:',
  'N2ProtectedStoreError',
  'N2ProtectedClinicalIOSVault.Failure',
  'message=Self.explainFailure(error,stage:stage)',
  'Inicio → Empezar con una base vacía (DEMO)'
]) must(firstWorker,fragment,'el alta clínica explica fallos y remite a DEMO sin omitir autenticación');
assert(!firstWorker.includes('#if targetEnvironment(simulator)'),
       'la autenticación de la fuente clínica nunca debe omitirse por estar en Simulator');

assert(clinicalHome.indexOf('clinical-first-run-import-personal') <
       clinicalHome.indexOf('clinical-first-run-restore-222'));

for(const label of ['DEPARTAMENTO DE SALUD','Text("Bienvenido")',
  'clinical-home-new-attention','clinical-home-tool-','N2HealthMascot()'])
  must(clinicalHome,label,'portada nativa 222');
for(const label of ['@AppStorage("danper.haptics.enabled")',
  '.sensoryFeedback(.selection,trigger:tab)',
  '.animation(reduceMotion ? nil : DanperStyle.animation,value:tab)'])
  must(clinicalHome,label,'hápticos y navegación de la portada');
for(const label of ['private var medicationGroupNames',
  'collapsedMedicationGroups','medication-procedure-group-',
  'ForEach(medicationGroupNames,id:\\.self)'])
  must(form,label,'medicamentos plegables por procedimiento');
for(const label of ['private let stepTitles=["Trabajador","Evaluación","Tratamiento","Resultado"]',
  'private func clinicalSection()->some View {',
  'DanperPanel("Alergias del trabajador")'])
  must(form,label,'etapas equivalentes');
const allergyIndex=form.indexOf('DanperPanel("Alergias del trabajador")');
assert(allergyIndex>form.indexOf('private func clinicalSection()'),
  'La revisión de alergias debe estar en Evaluación, como Build 222');
must(kardex,'label:"Lotes registrados"','contador de lotes que conserva los agotados');
must(kardex,'lotCount=context.lots.count','conteo real sin ocultar lotes agotados');
must(kardex,'vault.clinicalFormContext()','lectura de lotes sin estimaciones');


for(const term of ['Buscar en padrón','Nuevo trabajador','REGISTRO AMBULATORIO','registerSteps'])
  must(source,term,'referencia Build 222');
for(const name of ['Inicio','Registrar','Historial','Ajustes'])
  must(home,`Label("${name}"`,'pestaña nativa');
must(home,'Button {tab=1} label: {','acceso a nueva atención');
for(const term of ['attention-browse-workers','attention-add-worker','attention-worker-dni',
 'attention-worker-name-query','attention-worker-suggestions','attention-edit-worker-profile',
 'Alergias del trabajador','editingDNI:editingWorkerDNI',
 'allergyStatus=context?.allergies[worker.dni]?.status ?? "unknown"',
 'private func recordAllergy(','private func workerSection('])
  must(form,term,'primera etapa SwiftUI');
for(const term of ['worker-registration-dni','worker-save','worker-continue-attention',
 'DanperPanel("Datos laborales")','DanperPanel("Datos personales")'])
  must(editor,term,'editor SwiftUI');
assert.equal((form.match(/private func workerSection\(/g)||[]).length,1);
for(const term of ['kardex-route-','Registrar ingreso','Conciliar existencias',
 'Kardex de Enfermeras','Indicador Ambulatorio'])
  must(kardex,term,'hub único sin menús duplicados');
must(inventory,'init(initialOperation:String?=nil)','acción física de inventario');
for(const view of [indicator,nursing])
  for(const term of ['N2Build222ExportProgress','N2Build222StageHeading(step:1',
                     'N2Build222StageHeading(step:2','N2Build222StageHeading(step:3'])
    must(view,term,'exportación Excel de tres etapas');
for(const term of ['Crear archivo y compartir','useOfficialCut()','Libro conjunto'])
  if(term!=='Libro conjunto')must(indicator,term,'indicador');
for(const term of ['Período','Vista previa','Compartir'])
  must(nursing,term,'Kardex Excel');
must(reportStages,'struct N2Build222ExportProgress','componentes de Excel');
const official=clinicalRules.match(/public static let procedures=\[([\s\S]*?)\]/);
assert(official,'No se pudo leer el catálogo de procedimientos aprobado');
const codes=[...official[1].matchAll(/"([^"]+)"/g)].map(x=>x[1]);
const grouping=form.slice(form.indexOf('private var procedureGroups:'),
                          form.indexOf('private func procedureOption(',form.indexOf('private var procedureGroups:')));
for(const code of codes) {
  const matches=grouping.match(new RegExp('"'+code+'"','g'))||[];
  assert.equal(matches.length,1,'Procedimiento extraviado o duplicado: '+code);
}
assert.equal(codes.length,12,'Catálogo inesperadamente distinto: revisar manualmente');
must(home,'danper-visual-palette','selector de paleta de salud');
must(home,'N2HealthMascot()','mascota SwiftUI');
must(palette,'danper.visual.palette','tema nativo');
for (const value of [
  'inventory-select-product','inventory-single-quantity','inventory-save-',
  'Número de lote o referencia','Escribe el nombre del medicamento o insumo',
  'inventory-verified-unit','Vencimiento · DD/MM/AA',
  'Cantidad disponible','Registrar stock'])
  must(inventory,value,'formulario compacto de registro de medicamentos');
for (const line of [
  'let confirmed=units[product.id] ??',
  'product.id=="E-86" && product.name=="ALCOHOL 1 LT" ? "FCO" : nil',
  'product.group=="TABLETAS"',
  '("E-18","LOPERAMIDA TAB","UND")',
  '("E-94","GUANTES LIMPIOS M","CJA")',
  '("E-95","GUANTES LIMPIOS S","CJA")',
  'unit:confirmed'
]) must(catalog,line,'unidad médica confirmada, sin asumir UND');
assert(!inventory.includes('Nombre o código E-'),
       'La búsqueda no debe sugerir códigos internos como texto visible');
assert(!inventory.includes('material.map{$0.name+" · "+$0.id}'),
       'El producto seleccionado se muestra solo por nombre');
assert(!inventory.includes('detail:$0.id+" · "+$0.group'),
       'No mostrar E- como detalle de sugerencias');
assert(inventory.includes('materialCode=product.id') &&
       inventory.includes('unit=product.unit ?? ""'),
       'Elegir un producto debe cargar su unidad automáticamente');
assert(inventory.includes('TextField("Escribe el nombre del medicamento o insumo"'),
       'El buscador debe ser editable inmediatamente, sin segunda lupa');
assert(!/\b(?:let|var)\s+\w+\s*=!/.test(inventory),
       'Swift requiere separar la asignación de la negación (ej. let x = !condición)');
must(inventory,'let existingPackaged = !',
     'validación de envase sin error de sintaxis Swift');
for (const bad of ['Sede del inventario','Capacidad interna por envase',
  'Envases sellados','Unidades sueltas','Contenido de envase abierto',
  'Kardex físico protegido'])
  assert(!inventory.includes(bad),'Inventario vuelve a mostrar campo interno: '+bad);
assert(!form.includes('DanperPanel("Dispensación al guardar")'),
       'No introducir segunda confirmación de consumo');
assert(!form.includes('Actualizar verificación'),
       'La atención se guarda y descuenta sin verificación manual');
must(form,'step=record.stage','volver al paso del borrador recuperado');
must(form,'step=recovered.stage','cargar borrador en su paso anterior');
must(form,'makeDraftPatch(context:context,stage:step)',
     'guardar etapa en borrador cifrado');
must(clinicalTx,'Sin existencias FEFO disponibles en el inventario único.',
     'no segmentar FEFO por sede');
assert(!clinicalTx.includes('verifiedSites[l['),
       'FEFO no debe filtrar lotes según sede');
assert(!nursing.includes('let scoped=lots.filter'),
       'El Kardex de Enfermeras no debe segregar stock por sede');
for(const key of [
  'case .registerStock:','case .verifyCorrespondence:',
  'case .verifyPhysicalUse, .reviewPending:',
  'case .reviewChronology:','showStockRegistration=true',
  'N2NativeInventoryView(initialOperation:"lot")',
  'Label("Registrar existencias",systemImage:"shippingbox.fill")',
  'Label("Vincular producto",systemImage:"link")',
  'pending-container-stock-','"Volver a comprobar pendientes"'
]) must(form,key,'resolución contextual y única de consumos pendientes');
for(const key of [
  'case registerStock','case verifyCorrespondence','case verifyPhysicalUse',
  'case reviewChronology',
  'Sin existencias FEFO disponibles',
  'Sin correspondencia aprobada.',
  'No hay envase abierto verificable'
]) must(pendingResolution,key,'clasificación conservadora de los motivos reales');
assert(!form.includes('Button("Verificar cantidad y apertura pendiente")'),
       'No pedir aperturas para consumos sin stock');
assert(!form.includes('Button("Resolver correspondencia")'),
       'No mostrar vinculación redundante cuando el motivo real es stock');

for (const key of [
  'committedQuery=query',
  '.task(id:query)',
  'Contabilizado en el corte 9–8 · sin salida física verificada',
  'history-register-actual-stock-',
  'reconstructedCount',
  'Registro clínico incorporado una sola vez al cálculo'
]) must(history,key,'historial muestra reconstrucción sin inventar movimiento');
for (const key of [
  'private var clinicalOnlyMatches:',
  'context.products.authorizedNursingOptions(for:product.code).isEmpty',
  'N2AuxiliaryInventoryView(code:auxiliaryCode,context:context',
  'inventory-auxiliary-'
]) must(inventory,key,'buscar insumos clínicos externos al Kardex de 98');
for (const key of [
  'await previousAutosave?.value',
  'let lines=try await vault.dispensingLines(visitID:form.id)',
  'guard !Task.isCancelled,!saved,!busy else{return}',
  'drafts.removeAll(where:{$0.id==form.id})'
]) must(form,key,'guardado atómico sin carrera con borrador y sin lecturas redundantes');

console.log('PASS: pendientes con una sola acción pertinente: stock, vínculo, lote o cronología.');
for(const phrase of [
  'kardexID:"E-20"','clinicalCode:"16025008"',
  'kardexID:"E-68"','clinicalCode:"16000178"',
  'kardexID:"E-86"','clinicalCode:"16000019"',
  'kardexID:"E-94"','clinicalCode:"10000929"',
  'kardexID:"E-95"','clinicalCode:"16000127"',
  'kardexID:"E-97"','clinicalCode:"16021493"',
  '"E-25","E-81","E-82","E-84","E-85","E-98"'
]) must(batchReviewed,phrase,'seis confirmaciones y seis exclusiones');
must(mappingCore,'!N2UserReviewedKardexLinks.unmatched.contains(rule.inventoryID)',
    'NO CORRESPONDE nunca se vincula en core');
must(mappingView,'!N2UserReviewedKardexLinks.unmatched.contains($0.id)',
    'NO CORRESPONDE nunca se sugiere en UI');
must(clinicalTx,'N2UserReviewedKardexLinks.candidates(for:code)',
    'resolver asociaciones de revisión masiva');
must(inventory,'DisclosureGroup("Sin lotes registrados · stock 0")',
    'visualizar los 98 productos sin lote a 0');
for(const phrase of ['address:"D"+n,value:row["initial"]',
                     'address:"E"+n,value:row["extraordinary"]',
                     'address:"G"+n,value:row["consumed"]',
                     'address:"H"+n,value:row["final"]'])
  must(officialWriter,phrase,'exportar 0 numérico sin crear lotes');
console.log('PASS: revisión masiva confirmada y stock sin lote expresado como 0.');

for (const key of [
  'N2PendingResolution.forReason(line.result)',
  'Label(projectedInCut && line.result != "Descontado"',
  'Label("Registrar existencias",systemImage:"shippingbox.fill")',
  'Label("Vincular producto",systemImage:"link")',
  'N2NativeInventoryView(initialOperation:"lot")',
  'N2OperationalMappingView(code:code,context:context',
  'N2PendingDispensingView(',
  'readCorrectionDetail(visitID:visitID)',
  'retryDispensing(visitID:visitID',
  'navigationTitle("Consumos")',
  'navigationBarBackButtonHidden(true)',
  'Label("Volver",systemImage:"chevron.left")',
  'case .reviewChronology:'
]) must(history,key,'historial con resolución contextual de consumos');
assert(!history.includes('Label(line.result,systemImage:'),
       'Historial no debe mostrar mensajes crudos FEFO en la vista principal');
assert(!history.includes('navigationTitle("Consumos de la atención")'),
       'Título de consumos no debe truncarse con cabecera grande');
must(history,'Text("Kardex R: \\(quantity.formatted())" +',
     'detalle del Kardex concatena mediante operador infijo Swift');
console.log('PASS: historial muestra causas comprensibles y acciones por estado, sin duplicación de atención.');
for(const fragment of [
  'storedResolution == .verifyCorrespondence && alreadyLinked',
  'context?.products.authorizedNursingOptions(',
  'Producto ya vinculado al Kardex',
  'history-pending-container-stock-'
]) must(history,fragment,'historial no reabre vinculación ya revisada');
for(const fragment of [
  'storedResolution == .verifyCorrespondence && alreadyLinked',
  'context.products.authorizedNursingOptions(',
  'Producto ya vinculado.',
  'pending-container-stock-'
]) must(form,fragment,'resultado evita vinculación ya confirmada');
console.log('PASS: enlaces confirmados en bloque omiten modal repetido incluso para pendientes previos.');
for(const fragment of [
  'N2PendingResolution.historicalTitle(forReason:line.result)',
  'N2PendingResolution.historicalGuidance(forReason:reason)',
  'Label("Ver detalle del historial",systemImage:"info.circle")',
  'case .explainHistorical(let reason):',
  'La atención ya está guardada. Agregar existencias ahora no demuestra el saldo anterior.',
  'Contabilizado en el corte 9–8 · sin salida física verificada',
  'Ir a Kardex · registrar stock físico actual'
]) must(history,fragment,'historial actual distingue reconstrucción del corte y salida física auditada');
for(const phrase of [
  'N2PendingResolution.historicalTitle(forReason:result)',
  'N2PendingResolution.historicalGuidance(forReason:result)'
]) must(form,phrase,'resultado de atención histórica contextual');
console.log('PASS: pendiente histórico indica causa específica y ofrece explicación segura.');

const autoCut=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2AutomaticCutAccounting.swift'),'utf8');
const nursingBuilder=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2NursingReportBuilder.swift'),'utf8');
const nursingBook=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2VerifiedNursingWorkbook.swift'),'utf8');
const indicatorBook=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2VerifiedIndicatorWorkbook.swift'),'utf8');
const nursingCore=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift'),'utf8');
const clinicalVault=fs.readFileSync(path.join(root,'native-ios/App/N2ProtectedClinicalIOSVault.swift'),'utf8');
const syntheticVault=fs.readFileSync(path.join(root,'native-ios/App/N2SyntheticTrialIOSVault.swift'),'utf8');
for(const key of [
  'N2UserReviewedKardexLinks.links',
  'N2OperationalMappings.read(snapshot)',
  'projectedClinicalLines.insert(id)',
  '"E-86","E-94","E-95"'
]) must(autoCut,key,'reconstrucción de consumo una sola vez sin frascos inferidos');
for(const key of [
  'func reconstructedCut(',
  'N2AutomaticCutAccounting.calculate(',
  'initial:rounded(opening)',
  'consumed:isKnown ? rounded(used) : 0',
  'closing:isKnown ? rounded(endCount) : 0'
]) must(nursingBuilder,key,'corte 9 a 8 desde conteo posterior');
for(const source of [nursingBook,nursingCore,clinicalVault,syntheticVault,vaultSource]) {
  must(source,'reconstructFromCount','conexión completa desde SwiftUI al núcleo protegido');
}
must(nursing,'reconstructFromCount:reportMode=="cut"','solo corte 9–8 reconstruido');
must(indicatorBook,'for link in N2UserReviewedKardexLinks.links','10 hojas admiten vínculos revisados');
must(history,'cut.projectedClinicalLines','historial distingue inclusión al corte de salida física');
console.log('PASS: corte 9–8 reconstruido y vinculado con 98 filas, 92 relaciones sin inventar movimientos.');

for(const fragment of [
  'N2PendingDispensingEvidence.read(snapshot:snapshot)',
  'let declaredHistory=',
  'historical.newContainers ??',
  'projectedClinicalLines.insert(id)'
]) must(autoCut,fragment,'apertura 1/0 histórica declarada sin alterar stock actual');
for(const fragment of [
  'Label("Declarar apertura histórica (1/0)",',
  'context.historicalOptions(for:line.code,at:detail.date)',
  'Registro clínico incorporado una sola vez al cálculo del período.',
  'cut.projectedClinicalLines'
]) must(history,fragment,'declaración histórica y estado contable separados de FEFO');
for(const fragment of [
  'let projectedCut:N2AutomaticCutAccounting.Result?',
  'isWholePeriod && periodStart==start',
  'linkMultiplicity[kardex]==1',
  'estimate.reportedUse==Double(used)',
  'estimate.received==Double(income)',
  'estimate.adjusted==0',
  'projectedClosing==Int(physicalCount)',
  'row["difference"]=0',
  'row["verifiedIncome"]=income'
]) must(indicatorBook,fragment,'proyección provisional de diez hojas sin duplicar stock');
console.log('PASS: aperturas históricas y proyección provisional 10 hojas con controles de evidencia.');

const formContext=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2NativeFormContext.swift'),'utf8');
const pendingView=fs.readFileSync(path.join(root,'native-ios/App/N2PendingDispensingView.swift'),'utf8');
must(formContext,'func historicalOptions(for code:String,at date:String)',
  'lotes agotados visibles solo para documentación histórica');
must(pendingView,'context.historicalOptions(for:medication.code,at:date)',
  'declaración anterior incluso con saldo actual 0');
must(pendingView,'Guardar declaración histórica (R=1/0)',
  'distinguir conciliación contable antigua de FEFO actual');
// The single-professional identity is already configured in Build 222.
// Historical reconciliation must not request the same responsible again.
// Keep automatic audit and clinician identity, without editable operator/motive fields.
const legacyName=source.match(/const RESPONSIBLE='([^']+)'/);
const legacyDNI=source.match(/const RESPONSIBLE_DNI='(\d{8})'/);
assert(legacyName && legacyDNI,'Build 222 debe definir profesional y DNI');
must(formContext,`public static let name="${legacyName[1]}"`,
     'nombre nativo equivalente al responsable Build 222');
must(formContext,`public static let dni="${legacyDNI[1]}"`,
     'DNI nativo equivalente al responsable Build 222');
for(const text of [
  'public var responsible:String=N2ClinicianIdentity.name',
  'public var responsibleDni:String=N2ClinicianIdentity.dni',
  'effectiveResponsibleDni'
]) must(formContext,text,'identidad en visitas y borradores, incluso recuperados');
for(const text of [
  'LabeledContent("Responsable",value:N2ClinicianIdentity.name)',
  'LabeledContent("DNI del responsable",value:N2ClinicianIdentity.dni)',
  'operatorDni:N2ClinicianIdentity.dni',
  'automaticAuditDescription(',
  'Constancia automática: DANPER registrará el lote',
  'No se solicita un motivo escrito.',
  'N2PendingDispensingEvidence.Failure.invalidEvidence',
  'N2PendingDispensingEvidence.Failure.invalidTarget',
  'N2ProtectedStoreError.staleRevision',
  'historical-opening-responsible'
]) must(pendingView,text,'identidad automática y evidencia de apertura histórica');
assert(!pendingView.includes('TextField("Responsable",text:$operatorName)'),
       'no volver a pedir el responsable en cada apertura');
assert(!pendingView.includes('TextField("Evidencia y motivo"'),
       'la conciliación rutinaria no debe exigir motivo escrito');
assert(!pendingView.includes('@State private var reason'),
       'no conservar motivo editable innecesario');

const identityEvidence=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2PendingDispensingEvidence.swift'),'utf8');
must(identityEvidence,'public let operatorDni:String?',
     'DNI de auditoría opcional para compatibilidad con declaraciones antiguas');
must(identityEvidence,'public static func automaticAuditDescription(',
     'la constancia de apertura se genera desde hechos declarados sin motivo manual');

must(indicatorBook,'string(visit["responsibleDni"]),string(visit["responsible"])',
     'DNI en AB y nombre en AC del Excel oficial');


must(history,'context.historicalOptions(for:line.code,at:detail.date)',
  'historial permite seleccionar apertura histórica de un lote agotado');
must(pendingView,'return historicalAccountingOnly || date<formatter.string(from:Date())',
  'atenciones anteriores del mismo día usan declaración histórica cuando corresponde');
must(history,'historicalAccountingOnly:',
  'historial selecciona conciliación contable en lugar de forzar FEFO actual');
console.log('PASS: lotes agotados se pueden documentar retrospectivamente sin habilitar FEFO agotado.');

const stockChoice=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2StockRegistrationChoice.swift'),'utf8');
for(const key of [
  '.alert("¿Qué representa esta cantidad?"',
  'Button("Stock inicial del día 9")',
  'Button("Stock físico que tengo hoy")',
  'showStockBasisAlert=true',
  'N2StockRegistrationChoice.resolve(basis,quantity:qty',
  'stockRegistrationBasis":basis.rawValue',
  'stockRegistrationCutStart":period.start',
  'stockRegistrationCurrentQuantity":amount.todayPhysical',
  'if basis == .opening &&',
  'current.lots.contains(where:{$0.kardexCode==material.id})'
]) must(inventory,key,'selector central de stock inicial o actual y persistencia de criterio');
for(const key of [
  'case opening = "period-opening"',
  'case countedNow = "physical-count"',
  'todayPhysical:physicallyLeft',
  'todayPhysical:quantity',
  'quantity-use+receipts+adjustments',
  'quantity+use-receipts-adjustments',
  'Failure.ambiguousHistoricalOpenings'
]) must(stockChoice,key,'lógica única de stock inicial y físico contado');
console.log('PASS: registro de lote solicita elegir inicio día 9 o conteo actual y aplica cálculo sin doble descuento.');

const containerCore=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2ContainerAccounting.swift'),'utf8');
const formData=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2NativeFormContext.swift'),'utf8');
for(const key of [
  '.alert(containerDecisionTitle,isPresented:$showContainerDecision)',
  'Button("Sí, abrí uno nuevo · Kardex 1")',
  'Button("No, usé el abierto · Kardex 0")',
  'beginContainerReview(context)',
  'recordContainerDecision(opened:true)',
  'recordContainerDecision(opened:false)',
  'containerDecisionIndex+=1',
  'Task {await confirm()}',
  'form.items[idx].closePriorContainer=opened && (alreadyOpen || earlierOpened)'
]) must(form,key,'pregunta obligatoria para cada frasco/caja al guardar atención');
for(const key of [
  'Al guardar la atención, DANPER preguntará automáticamente',
  'El volumen es opcional; nunca se infiere una apertura'
]) must(medicationRow,key,'eliminar casilla de apertura fácil de olvidar');
assert(!medicationRow.includes('DanperCheckRow(selected:$medication.approveOpening)') ||
       medicationRow.includes('Confirmo la apertura física para extraer unidades individuales'),
       'el control de frascos/cajas debe estar al guardar, no oculto en cada fila');
for(const key of [
  'previousContainerExhausted',
  'closePriorContainer:Bool=false'
]) must(formData,key,'evidencia explícita del envase anterior agotado');
for(const key of [
  'static func exhaustedByNextOpening(',
  '"kind":"containerState"',
  '"containerDisposition":"agotado"',
  '"excelQuantity":0',
  '"physicalChange":-previousRemainder',
  '(movement["physicalChange"] as? NSNumber)?.doubleValue == -removed'
]) must(containerCore,key,'cierre anterior con R=0 y diferencia física auditable');
for(const key of [
  'exhaustPrevious',
  'active.count==1',
  'pendingClosures',
  'N2ContainerAccounting.exhaustedByNextOpening(',
  'movements.append(contentsOf:pendingClosures)'
]) must(clinicalTx,key,'transición atómica de apertura nueva y agotamiento previo');
for(const needle of [
  'form.items[idx].physicalQuantity=0',
  'reusePreviouslyOpened = !opened',
  'available.first(where:{$0.openContainers>0})',
  'pending-container-stock-'
]) must(form,needle,'reutilización automática FEFO con R0 y sin modal redundante');
for(const needle of [
  'reusePreviouslyOpened:Bool=false',
  '"reusePreviouslyOpened":med.reusePreviouslyOpened'
]) must(formData,needle,'declaración explícita de envase abierto');
for(const needle of [
  'attestedReuse(',
  'reuseWithoutRecordedOpening',
  '"physicalChange":0',
  '"excelQuantity":0',
]) must(containerCore,needle,'reclasificación auditada sin inventar una apertura antigua');
for(const needle of [
  'let declaredReuse =',
  'N2ContainerAccounting.attestedReuse(',
  'selectedForAccounting',
  'movements.append(contentsOf:pendingClosures)'
]) must(clinicalTx,needle,'FEFO apertura previa con actual R0');
for(const needle of [
  'history-pending-container-stock-',
  'Ir al Kardex · comprobar envase'
]) must(history,needle,'pendiente vincula al inventario y no a cantidad física duplicada');

console.log('PASS: alertas 1/0 por cada envase, cierre anterior auditable sin doble descuento.');










const surveillanceCore=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2OccupationalVigilanceWorkbook.swift'),'utf8');
const surveillanceUI=fs.readFileSync(path.join(root,'native-ios/App/N2OccupationalVigilanceExportView.swift'),'utf8');
const clinicalSource=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift'),'utf8');
const clinicalSourceIO=fs.readFileSync(path.join(root,'native-ios/App/N2ProtectedClinicalIOSVault.swift'),'utf8');
const demoSourceIO=fs.readFileSync(path.join(root,'native-ios/App/N2SyntheticTrialIOSVault.swift'),'utf8');
const surveillanceTests=fs.readFileSync(path.join(root,'native-ios/Tests/DanperCoreTests/N2OccupationalVigilanceTests.swift'),'utf8');
for(const text of [
  'VIGILACIA OCUPACIONAL','DSUBDIVISION','OSTEOMUSCULAR',
  'Capacitacion y ejecucion de pausas activas',
  'N1rStoredZip.pack(entries)','skippedMissingIdentity'
]) must(surveillanceCore,text,'generador Excel de vigilancia de una hoja');
for(const text of [
  'vault.exportOccupationalVigilance(',
  'vigilance-export-xlsx','N2VigilanceActivity(file:item.file)'
]) must(surveillanceUI,text,'pantalla y compartir vigilancia');
for(const component of [clinicalSource,clinicalSourceIO,demoSourceIO,vaultSource])
  must(component,'exportOccupationalVigilance(','flujo de bóveda para tercer Excel');
must(kardex,'N2OccupationalVigilanceExportView()','tercer enlace en Kardex');
for(const name of [
  'testOnlyOsteomuscularSavedVisitsAndOneSheet',
  'testOnlySelectedDateAndNoDuplicateClinicalRows',
  'testNoOsteomuscularVisitsHasOnlyOriginalHeader'
]) must(surveillanceTests,name,'pruebas vigilancia');
console.log('PASS: vigilancia ocupacional de una hoja: fuente, filtro, formato y compartir conectados.');

console.log('PASS: Inventario único, atención sin doble confirmación, borrador en su paso, Kardex compacto y dos Excel.');
console.log('PASS: estructura Build 222 (4 tabs), ingreso de trabajador, perfil, revisión de alergias y alta SwiftUI presentes.');
console.log('PASS: inicio clínico, animaciones, grupos de tratamiento y Kardex aproximados a Build222.');
for(const id of ['start-empty-demo','start-sample-demo','start-import-personal-xlsx','start-restore-build222'])
  must(home,id,'origen de datos explícito');
must(home,'DanperToolLink(title:"Importar trabajadores desde Excel PERSONAL"','ruta para importar durante uso');
must(core,'activateEmptySynthetic(confirmed:Bool)','fuente de prueba vacía');
must(core,'let source=try N2EmptyDemoSnapshot.make()','fuente validada desde cero');
must(demo,'func startEmptyDemo()','inicio de prueba sin seed');
must(demo,'func startSyntheticDemo()','ejemplo ficticio separado');
for(const value of ['"workers"','"attentions"','"stockLots"','"stockMovements"'])
  must(blank,value+':[[String:Any]]()','colección vacía '+value);
must(reset,'try await N2SyntheticTrialIOSVault.shared.eraseEntireDemo','borrado limitado a demo');
must(reset,'onDeleted()','propagar verificación de borrado a inicio');
must(personal,'personal-xlsx-import-preview','vista previa de Excel');
must(personal,'open-imported-clinical-workspace','abrir bóveda clínica tras importar');
console.log('PASS: onboarding con origen explícito, demo realmente vacía, borrado verificado e importación protegida.');
console.log('PASS: nueva vía sin Excel crea solo el primer trabajador manual con autenticación y fuente vacía original.');
console.log('PASS: cabecera DANPER, búsqueda de padrón paginada, validación con foco y tratamiento compacto en B11.');
const correctionUI=fs.readFileSync(path.join(root,'native-ios/App/N2ClinicalCorrectionView.swift'),'utf8');
const correctionCore=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2ClinicalCorrections.swift'),'utf8');
const stockCore=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2NativeInventoryCommands.swift'),'utf8');
for(const needle of [
  'visitsPageSize=15',
  'ForEach(Array(savedVisits.dropFirst(safeVisitsPage*visitsPageSize).prefix(visitsPageSize)))',
  'N2RecordedVisitDetailView(visitID:visit.id',
  '¿Deseas editar esta atención?',
  'history-request-edit-'
]) must(history,needle,'Historial de atenciones paginado con acceso directo y confirmación');
for(const needle of [
  'clinical-home-draft-count-link',
  'N2NativeHistoryView(useProtectedVault:true,showWorkers:true)'
]) must(clinicalHome,needle,'Borradores pulsables y directorio separado');
for(const needle of [
  'groupedLots',
  'DisclosureGroup {',
  'inventory-edit-lot-',
  'N2LotMetadataEditor(lot:lot',
  'inventory-group-'
]) must(inventory,needle,'Inventario agrupado y edición auditada de lotes');
must(stockCore,'correctUnusedLot(snapshot:Data','corrección solo de lotes sin movimientos');
must(stockCore,'!movements.contains(where:{$0["lotId"] as? String==lotID})',
    'bloqueo de modificación de lotes utilizados');
for(const needle of [
  'itemClinicalQuantities',
  'correctedClinicalQuantity',
  'pending.insert(visitID)'
]) must(correctionCore,needle,'rectificación clínica de cantidad sin segunda dispensación');
for(const needle of [
  'correction-item-quantity-',
  'itemQuantities',
  'item.quantity'
]) must(correctionUI,needle,'corrección visual de dosis histórica');
console.log('PASS: historial 15/página, borradores, lotes agrupados y edición clínica auditada sin rehacer FEFO.');

console.log('PASS: Alta compacta con vencimiento DDMMAA; corte 9–8 resumido, movimientos diarios en Excel de Enfermeras.');
console.log('AVISO: verificación estructural, no prueba de compilación ni paridad visual completa.');
