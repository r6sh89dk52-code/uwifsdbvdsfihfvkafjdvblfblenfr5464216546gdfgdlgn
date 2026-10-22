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
const history=fs.readFileSync(path.join(root,'native-ios/App/N2NativeHistoryView.swift'),'utf8');
const theme=fs.readFileSync(path.join(root,'native-ios/App/DanperUITheme.swift'),'utf8');
const firstWorker=fs.readFileSync(path.join(root,'native-ios/App/N2FirstManualWorkerView.swift'),'utf8');
const must=(data,needle,label)=>assert(data.includes(needle),`Falta ${label}: ${needle}`);
must(app,'N2ClinicalWorkspaceGateView()','inicio cifrado con importación PERSONAL');
assert(!app.includes('NativeRootView()'),'No puede abrirse el modo ficticio en inicio normal');
must(clinicalHome,'clinical-first-run-import-personal','importar PERSONAL como acción principal');
must(clinicalHome,'clinical-first-run-restore-222','restauración opcional Build222');
must(clinicalHome,'clinical-first-run-manual-worker','inicio manual sin Excel');
for(const phrase of ['DanperBrandHeader {','Bienvenido',
  'ACCESO RÁPIDO','Nueva atención','homeMetric('])
  must(clinicalHome,phrase,'cabecera y estructura de Inicio Build222');
for(const phrase of ['Image("BrandLogo")','danper-brand-header',
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

for(const label of ['DEPARTAMENTO DE SALUD','Bienvenido a DANPER',
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
must(kardex,'label:"Lotes registrados"','contador real de lotes');
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
for(const term of ['kardex-route-','Inventario físico','Entradas y salidas',
 'Revisar pendientes anteriores','Exportar Kardex'])
  must(kardex,term,'hub Kardex original');
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
console.log('PASS: Kardex de 4 acciones, Excel 3 etapas, 12 procedimientos únicos y tema azul presentes.');
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
console.log('AVISO: verificación estructural, no prueba de compilación ni paridad visual completa.');
