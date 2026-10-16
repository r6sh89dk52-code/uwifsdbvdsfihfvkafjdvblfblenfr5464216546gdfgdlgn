'use strict';
// Builds reproducible, entirely synthetic, non-patient bundles for the iOS
// preview. Generates no IPA and NEVER copies clinical backups or source XLSX
// files containing historical employee information.
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),os=require('node:os');
const {execFileSync}=require('node:child_process');
const root=path.resolve(__dirname,'..');
const temporary=fs.mkdtempSync(path.join(os.tmpdir(),'danper-n1s-synthetic-'));
const output=path.join(root,'native-ios','App','N1sDemoResources');
const sequence=[
 'generate-native-compat-fixtures.cjs',
 'generate-n1e-clinical-fixtures.cjs',
 'generate-n1f-lossless-fixtures.cjs',
 'generate-n1h-clinical-parity.cjs',
 'generate-n1p-excel-parity.cjs',
 'generate-n1q-reconciliation-fixtures.cjs',
 'generate-n1r-stored-xlsx-template.cjs',
 'generate-n1s-official-excel-fixtures.cjs'
];
try{
 for(const name of sequence) execFileSync(process.execPath,[path.join('scripts',name)],{
  cwd:root,env:{...process.env,DANPER_N1_FIXTURE_DIR:temporary},
  stdio:'inherit',timeout:180000
 });
 // The template files have no patient history. Only these four items are
 // copied: no original workbooks, synthetic snapshots, or TS reference exports.
 fs.mkdirSync(output,{recursive:true});
 for(const kind of ['indicator','nursing']){
  const prefix='n1s-'+kind;
  const input=JSON.parse(fs.readFileSync(path.join(temporary,prefix+'-plan.json'),'utf8'));
  assert(kind==='indicator' ? input.catalog.length===432&&input.rows===2 : input.rows.length===98);
  input.demoFixtureOnly=true;
  input.demoFixtureTag='DANPER_N1S_SYNTHETIC_2026';
  input.demoKind=kind;
  fs.copyFileSync(path.join(temporary,prefix+'-template-store.zip'),
    path.join(output,prefix+'-template-store.zip'));
  fs.writeFileSync(path.join(output,prefix+'-plan.json'),JSON.stringify(input));
 }
 assert.equal(fs.readdirSync(output).length,4,'only four synthetic resources allowed');
 console.log('PASS: four sanitized synthetic N1s iOS demo resources; no backup or patient data.');
} finally {
 fs.rmSync(temporary,{recursive:true,force:true});
}
