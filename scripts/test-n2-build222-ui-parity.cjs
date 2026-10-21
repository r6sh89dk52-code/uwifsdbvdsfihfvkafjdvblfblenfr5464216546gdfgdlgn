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
const must=(data,needle,label)=>assert(data.includes(needle),`Falta ${label}: ${needle}`);
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
console.log('PASS: estructura Build 222 (4 tabs), ingreso de trabajador, perfil, revisión de alergias y alta SwiftUI presentes.');
console.log('AVISO: verificación estructural, no prueba de compilación ni paridad visual completa.');
