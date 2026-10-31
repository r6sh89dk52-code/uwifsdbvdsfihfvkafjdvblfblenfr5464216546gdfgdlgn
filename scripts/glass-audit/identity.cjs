'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const bundle='pe.danper.saludmovil.native.iloaderpreview';
const expectedBuild=process.env.DANPER_EXPECTED_BUILD||'14';
assert(['14','15'].includes(expectedBuild),'Explicit audited build required');
const spec=fs.readFileSync('native-ios/project.yml','utf8');
assert(spec.includes('PRODUCT_BUNDLE_IDENTIFIER: '+bundle+'\n'));
assert(!spec.includes('native.preview'));assert(spec.includes('MARKETING_VERSION: "0.4.2"'));assert(spec.includes('CURRENT_PROJECT_VERSION: "'+expectedBuild+'"'));
assert(!/CODE_SIGN_ENTITLEMENTS|keychain-access-groups|com\.apple\.security\.application-groups/.test(spec));
const suffixes=['n1','n1i.demo-only','n1m.real-staging','n2.clinical','n2.synthetic'];
const files=['NativeEncryptedLabVault','N1iDemoDraftIOSVault','N1mRealClinicalStagingIOSVault','N2ProtectedClinicalIOSVault','N2SyntheticTrialIOSVault'];
for(let i=0;i<files.length;i++){
 const s=fs.readFileSync('native-ios/App/'+files[i]+'.swift','utf8');
 assert(s.includes('"'+bundle+'.'+suffixes[i]+'"'),files[i]);assert(!s.includes('pe.danper.saludmovil.native.preview.'));
 assert(s.includes('kSecAttrAccessibleWhenUnlockedThisDeviceOnly'));assert(!s.includes('kSecAttrAccessGroup'));assert(s.includes('.applicationSupportDirectory'));
}
const app=fs.readFileSync('native-ios/App/DANPERNativeApp.swift','utf8');assert(app.includes('evaluatePolicy'));assert(app.includes('.deviceOwnerAuthentication'));
console.log('PASS: separate app/test identities, five distinct Keychain services, device-only unlocked policy, sandbox-relative containers, no shared groups; iLoader signing still requires physical validation.');
