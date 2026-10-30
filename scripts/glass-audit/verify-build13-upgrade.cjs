'use strict';
const {execFileSync}=require('node:child_process');
const fs=require('node:fs'),assert=require('node:assert/strict');
const base='8cc144aef2a17205c1da57b7819813e0a07118b8';
const fixed=[
 'native-ios/Sources/DanperCore/N2EncryptedClinicalJournal.swift',
 'native-ios/Sources/DanperCore/N2InventoryBackupCodec.swift',
 'native-ios/Sources/DanperCore/N2SimpleInventoryMigration.swift',
 'native-ios/Sources/DanperCore/N2SimpleInventoryCommands.swift',
 'native-ios/Sources/DanperCore/N2SimpleClinicalTransaction.swift',
 'native-ios/Sources/DanperCore/N2SimpleInventoryModel.swift',
 'native-ios/Sources/DanperCore/N2ProtectedClinicalVaultCore.swift',
 'native-ios/App/N2ProtectedClinicalIOSVault.swift',
 'native-ios/App/NativeEncryptedLabVault.swift',
 'native-ios/App/N1iDemoDraftIOSVault.swift',
 'native-ios/App/N1mRealClinicalStagingIOSVault.swift',
 'native-ios/App/N2SyntheticTrialIOSVault.swift'
];
for(const file of fixed) {
 const old=execFileSync('git',['show',base+':'+file]);
 assert(old.equals(fs.readFileSync(file)), 'Build 13 storage contract changed: '+file);
}
const old=execFileSync('git',['show',base+':native-ios/project.yml'],{encoding:'utf8'});
const next=fs.readFileSync('native-ios/project.yml','utf8');
assert.equal(next,old.replace('CURRENT_PROJECT_VERSION: "13"','CURRENT_PROJECT_VERSION: "14"'));
console.log('PASS: Build 13 vault, Keychain adapters, activation, inventory schema and encrypted backup codecs unchanged; only app build number advances to 14.');
