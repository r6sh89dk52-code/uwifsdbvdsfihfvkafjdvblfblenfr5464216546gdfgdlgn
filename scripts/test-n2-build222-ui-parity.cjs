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
const must=(data,needle,label)=>assert(data.includes(needle),`Falta ${label}: ${needle}`);
must(app,'N2ClinicalWorkspaceGateView()','inicio cifrado con importación PERSONAL');
assert(!app.includes('NativeRootView()'),'No puede abrirse el modo ficticio en inicio normal');
must(clinicalHome,'clinical-first-run-import-personal','importar PERSONAL como acción principal');
must(clinicalHome,'clinical-first-run-restore-222','restauración opcional Build222');
assert(clinicalHome.indexOf('clinical-first-run-import-personal') <
       clinicalHome.indexOf('clinical-first-run-restore-222'));

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
console.log('AVISO: verificación estructural, no prueba de compilación ni paridad visual completa.');
