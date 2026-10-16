'use strict';
// Generate ONLY fictional encrypted fixtures using the real TS production module.
// No patient information or original user backup is read or committed.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('typescript');
const {webcrypto, createHash} = require('node:crypto');

const output = process.env.DANPER_N1_FIXTURE_DIR;
if (!output || !path.isAbsolute(output)) throw Error('Expected absolute DANPER_N1_FIXTURE_DIR');
fs.mkdirSync(output, {recursive: true});
const src = fs.readFileSync('src/portableBackup.ts', 'utf8');
const code = ts.transpileModule(src, {compilerOptions: {
  module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022
}}).outputText;
const moduleRef = {exports: {}};
vm.runInNewContext(code, {
  module: moduleRef, exports: moduleRef.exports, TextEncoder, TextDecoder,
  Uint8Array, ArrayBuffer, Promise, Date, JSON, Object, Array, String, Number, Error,
  crypto: {subtle: webcrypto.subtle, getRandomValues: value => webcrypto.getRandomValues(value)},
  atob: value => Buffer.from(value, 'base64').toString('latin1'),
  btoa: value => Buffer.from(value, 'latin1').toString('base64')
});
const encrypt = moduleRef.exports.encryptPortableBackup;
const password = 'N1-SINTETICO-EXCLUSIVO-2026!';
const snapshot = {
  attentions: [{id:'ATT-FICTICIA-1',status:'saved',
    items:[{id:'I-UNO',quantity:2},{id:'I-DOS',quantity:3}]}],
  workers: [{dni:'00000001',name:'TRABAJADOR FICTICIO 1'},
            {dni:'00000002',name:'TRABAJADOR FICTICIO 2'}],
  allergies: {'00000001': {state:'unknown'}},
  notifications: true,
  stockLots: [{id:'LOTE-FICTICIO',code:'E-22',quantity:5}],
  stockMovements: [{id:'MOV-FICTICIO',
    dispenseRef:{attentionId:'ATT-FICTICIA-1',itemId:'I-UNO'}}],
  catalogMappings: [{id:'MAP-FICTICIO'}],
  deliveryIncidents: [{id:'INC-FICTICIO'}],
  ambulatoryReconciliation: [{id:'CONC-FICTICIO'}]
};
(async () => {
  const encrypted = await encrypt(snapshot, password);
  const obj = JSON.parse(encrypted);
  const sourceKey = await webcrypto.subtle.importKey('raw',
    new TextEncoder().encode(password), 'PBKDF2', false, ['deriveKey']);
  const key = await webcrypto.subtle.deriveKey({
    name: 'PBKDF2', salt: Buffer.from(obj.salt, 'base64'),
    iterations: 310000, hash: 'SHA-256'
  }, sourceKey, {name:'AES-GCM',length:256}, false, ['decrypt']);
  const plain = Buffer.from(await webcrypto.subtle.decrypt({
    name:'AES-GCM', iv:Buffer.from(obj.nonce,'base64')
  }, key, Buffer.from(obj.data,'base64')));
  if (JSON.stringify(JSON.parse(plain.toString('utf8')).snapshot) !== JSON.stringify(snapshot))
    throw Error('Roundtrip mismatch');
  fs.writeFileSync(path.join(output, 'synthetic.danperbackup'), encrypted);
  const tampered = {...obj};
  const payload = Buffer.from(obj.data, 'base64');
  payload[payload.length - 1] ^= 1; // authenticated tag corruption
  tampered.data = payload.toString('base64');
  fs.writeFileSync(path.join(output, 'tampered.danperbackup'), JSON.stringify(tampered));
  fs.writeFileSync(path.join(output, 'downgraded.danperbackup'),
    JSON.stringify({...obj, iterations:1}));
  fs.writeFileSync(path.join(output, 'synthetic.meta.json'), JSON.stringify({
    plaintextSHA256: createHash('sha256').update(plain).digest('hex'),
    plaintextByteCount: plain.byteLength
  }));
  console.log('PASS: TS v0.21.12 backup fixture generated and JS decrypted it; synthetic records only.');
})().catch(e=>{console.error(e); process.exitCode = 1});
