#!/usr/bin/env node
'use strict';
// The build 222 source is the compatibility authority. This guard validates
// native contract and workflow structure; only XCTest + a user's original
// .danperbackup can prove actual successful restoration.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const original=read('src/portableBackup.ts');
const native=read('native-ios/App/PortableBackupInspector.swift');
const gate=read('native-ios/App/N2NativeActivationView.swift');
const core=read('native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift');
const workspace=read('native-ios/App/N2ClinicalWorkspaceView.swift');
const tests=read('native-ios/NativeTests/N2PortableBackupInteropTests.swift');
const patterns=[
 ['DANPER-SALUD-PORTABLE-BACKUP','DANPER-SALUD-PORTABLE-BACKUP'],
 ['PBKDF2-SHA256','PBKDF2-SHA256'],
 ['AES-256-GCM','AES-256-GCM'],
 ['310000','310_000'],
 ['schema:1','"schema"']
];
for(const [one,two] of patterns){
 assert(original.includes(one),'build 222 format changed: '+one);
 assert(native.includes(two),'B11 reader not compatible: '+two);
}
assert(original.includes('salt=b64(salt)')===false); // No invented alternate envelope.
assert(original.includes('salt:b64(salt)'));
assert(original.includes('nonce:b64(iv)'));
assert(original.includes('data:b64(new Uint8Array(encrypted))'));
assert(native.includes('Data(base64Encoded: record.salt)'));
assert(native.includes('Data(base64Encoded: record.nonce)'));
assert(native.includes('Data(base64Encoded: record.data)'));
assert(native.includes('AES.GCM.open('));
assert(native.includes('expectedEncryptedSHA256'));
assert(native.includes('sha==expectedEncryptedSHA256'));
assert(native.includes('N1lRealSnapshotGate.audit(raw,destination:.verifiedEmpty)'));
assert(native.includes('checked.physicalMovements==audit.manifest.movements'));
assert(native.includes('saved.pendingClinicalLines==audit.unresolvedClinicalConsumptions'));
assert(gate.includes('PortableBackupInspector.review('));
assert(gate.includes('PortableBackupInspector.activateProtectedSource('));
assert(gate.includes('.confirmationDialog('));
assert(gate.includes('confirming=true'));
assert(gate.includes('evaluatePolicy('));
assert(gate.includes('summary==nil'));
assert(gate.includes('review?.canRestore==true'));
assert(!gate.includes('N2SyntheticTrialIOSVault.shared'));
assert(core.includes('guard try journal.recover() == nil'));
assert(core.includes('N2ProtectedStoreError.targetNotEmpty'));
assert(core.includes('active.snapshot==plaintext'));
assert(workspace.includes('N2SimpleRestoreView(kind:.complete).environment(\\.n2WorkspaceVault,.clinical)'));
assert(workspace.includes('clinical-first-run-restore-222'));
assert(workspace.includes('N2NativePersonalImportView()'));
const restore=read('native-ios/App/N2SimpleMigrationViews.swift');
for(const key of ['inspectSimpleBackup','recoverPortableSource','restoreSimpleClinical','SHA256.hash(data:archive)','evaluatePolicy','clearSecrets()']) assert(restore.includes(key),key);
for(const key of ['targetNotEmpty','verifySimpleBackupDomain','N1lRealSnapshotGate.audit']) assert(core.includes(key),key);
assert(tests.includes('testBuild222EncryptedSourceReviewCannotBeChangedBeforeRestore'));
assert(tests.includes('testFullSyntheticClinicalBackupPreservesPhysicalHistoryAcrossReview'));
console.log('PASS: contrato cifrado build 222 compatible con lector B11; vista previa independiente, SHA, fuente vacía, contadores y recuperación segura.');
