'use strict';
// Static guardrail only. It does NOT replace Swift/Xcode UI or clinical tests.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const source=fs.readFileSync(path.join(root,'src/main.tsx'),'utf8');
const home=fs.readFileSync(path.join(root,'native-ios/App/NativeRootView.swift'),'utf8');
const form=fs.readFileSync(path.join(root,'native-ios/App/N2NativeClinicalFormView.swift'),'utf8');
const editor=fs.readFileSync(path.join(root,'native-ios/App/N2NativeWorkerEditorView.swift'),'utf8');
const kardex=fs.readFileSync(path.join(root,'native-ios/App/N2Build222KardexHub.swift'),'utf8');
const inventory=fs.readFileSync(path.join(root,'native-ios/App/N2NativeInventoryView.swift'),'utf8');
const catalog=fs.readFileSync(path.join(root,'native-ios/Sources/DanperCore/N2NativeCatalogIndex.swift'),'utf8');
const indicator=fs.readFileSync(path.join(root,'native-ios/App/N2VerifiedIndicatorExportView.swift'),'utf8');
const nursing=fs.readFileSync(path.join(root,'native-ios/App/N2VerifiedNursingExportView.swift'),'utf8');
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

const history=fs.readFileSync(path.join(root,'native-ios/App/N2NativeHistoryView.swift'),'utf8');
const theme=fs.readFileSync(path.join(root,'native-ios/App/DanperUITheme.swift'),'utf8');
const firstWorker=fs.readFileSync(path.join(root,'native-ios/App/N2FirstManualWorkerView.swift'),'utf8');
const must=(data,needle,label)=>assert(data.includes(needle),`Falta ${label}: ${needle}`);
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
  '"Revisar lote o apertura"','"Volver a comprobar pendientes"'
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
console.log('PASS: pendientes con una sola acción pertinente: stock, vínculo, lote o cronología.');
for (const key of [
  'N2PendingResolution.forReason(line.result)',
  'Label(resolution.summary,systemImage:',
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
console.log('PASS: historial muestra causas comprensibles y acciones por estado, sin duplicación de atención.');


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
console.log('PASS: Alta compacta con vencimiento DDMMAA; corte 9–8 resumido, movimientos diarios en Excel de Enfermeras.');
console.log('AVISO: verificación estructural, no prueba de compilación ni paridad visual completa.');
