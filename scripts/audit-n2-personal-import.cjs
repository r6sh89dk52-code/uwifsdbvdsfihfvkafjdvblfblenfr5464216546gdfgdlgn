#!/usr/bin/env node
'use strict';
// Static fail-closed audit of native PERSONAL import wiring.
// Does not open, copy or log any employee Excel workbook.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const base=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(base,p),'utf8');
const manifest=read('native-ios/Package.swift');
const reader=read('native-ios/Sources/DanperCore/N2PersonalWorkbookReader.swift');
const planner=read('native-ios/Sources/DanperCore/N2PersonalRosterImport.swift');
const vault=read('native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift');
const actor=read('native-ios/App/N2ProtectedClinicalIOSVault.swift');
const view=read('native-ios/App/N2NativePersonalImportView.swift');
const gate=read('native-ios/App/N2ClinicalWorkspaceView.swift');
const tests=read('native-ios/Tests/DanperCoreTests/N2PersonalWorkbookImportTests.swift');
assert(manifest.includes('ZIPFoundation.git'));
assert(reader.includes('import ZIPFoundation'));
assert(reader.includes('"PERSONAL"'));
assert(reader.includes('"xl/sharedStrings.xml"'));
assert(reader.includes('optional:true'));
assert(reader.includes('"NOMBRES"'));
assert(reader.includes('"APELLIDOS Y NOMBRES"'));
assert(reader.includes('row[col]=cellInline'));
assert(reader.includes('row[col]=shared[index]'));
assert(reader.includes('entry.uncompressedSize'));
assert(reader.includes('!target.contains("..")'));
assert(reader.includes('stats.sexConflicts'));
assert(reader.includes('stats.nameConflicts'));
for(const part of ['"attentions"','"allergies"','"stockLots"',
                   '"stockMovements"','"catalogMappings"','"deliveryIncidents"',
                   '"ambulatoryReconciliation"']) {
 assert(planner.includes(part),'Missing preserved clinical collection '+part);
}
assert(planner.includes('throw N2PersonalImportError.needsReview'));
assert(planner.includes('N1eLegacyClinicalAudit.inspect(next)'));
assert(planner.includes('N1fLosslessFieldGate.inspect(next)'));
assert(planner.includes('return (snapshot,N2PersonalImportResult('),'Missing idempotent reimport');
assert(vault.includes('public func activateInitialPersonal('));
assert(vault.includes('public func mergePersonal('));
assert(vault.includes('active.revision==expectedRevision'));
assert(actor.includes('func activateInitialPersonal('));
assert(actor.includes('func mergePersonal('));
assert(!view.includes('N2SyntheticTrialIOSVault.shared'));
assert(!view.includes('N2WorkspaceVault.demo'));
assert(view.includes('.fileImporter('));
assert(view.includes('evaluatePolicy('));
assert(view.includes('previewPersonalMerge('));
assert(view.includes('mergePersonal('));
assert(view.includes('activateInitialPersonal('));
assert(view.includes('scenePhase == .background'));
assert(gate.includes('N2NativePersonalImportView()'));
assert(tests.includes('testCompressedPERSONALWithSharedStringsAndInlineWorkers'));
assert(tests.includes('testInlineStrPERSONALWithoutOptionalSharedStrings'));
assert(tests.includes('testReimportPreservesEveryClinicalCollection'));
console.log('PASS: importador nativo PERSONAL aislado, transaccional, hoja única, validación previa y tests sintéticos presentes.');
