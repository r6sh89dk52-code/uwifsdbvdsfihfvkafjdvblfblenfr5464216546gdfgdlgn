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
 // Workbook references and an explicitly fictional clinical example are
 // bundled only in this evaluation build, never in the production bundle.
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
 const synthetic=JSON.parse(fs.readFileSync(path.join(temporary,'n1e-clinical-stock.json'),'utf8'));
 assert.equal(synthetic.workers.length,5);
 assert(synthetic.workers.every(w=>w.name.startsWith('PERSONA FICTICIA ')&&/^0000000[1-5]$/.test(w.dni)));
 assert(synthetic.attentions.every(a=>a.worker.name.startsWith('PERSONA FICTICIA ')));
 // Replace unnatural display placeholders only in the packaged synthetic iOS fixture.
 // This does not mutate existing installed vaults or production/legacy backups.
 const fictionalNames={
  '00000001':'Mariana Torres Salazar',
  '00000002':'Luis Paredes Rojas',
  '00000003':'Daniela Campos Vega',
  '00000004':'Carlos Mendoza Ruiz',
  '00000005':'Valeria Ríos Medina'
 };
 for(const worker of synthetic.workers) {
  assert(fictionalNames[worker.dni]);
  worker.name=fictionalNames[worker.dni];
 }
 for(const visit of synthetic.attentions) {
  assert(visit.worker && fictionalNames[visit.worker.dni]);
  visit.worker.name=fictionalNames[visit.worker.dni];
 }
 assert.equal(synthetic.stockLots.length,5);
 assert.equal(synthetic.stockMovements.length,synthetic.stockMovements.filter(m=>m.dispenseRef).length);
 // Two explicitly fictional site-scoped supplies for evaluating new visits.
 // Existing unscoped lots and historical movements are never relabelled.
 const example=synthetic.stockLots.find(l=>l.code==='E-22');
 assert(example);
 for(const [suffix,site] of [['fundo','LA VENTUROSA'],['planta','PLVENTUROSA']]) {
  synthetic.stockLots.push({...example,id:'FICTICIO-'+suffix,lot:'FICTICIO-'+suffix,
   site,expires:'2028-12-31',container:'unidad',catalogUnit:'UND',
   unitsPerContainer:1,sealedContainers:0,looseUnits:20,openedRemaining:0});
 }
 fs.writeFileSync(path.join(output,'n2-synthetic-clinical.json'),JSON.stringify(synthetic));
 const {load}=require('./ambulatory-test-helpers.cjs');
 const products=require('../src/products.json');
 const nurseCatalog=load('src/kardexCatalog.ts').kardexCatalog;
 const approved=load('src/reviewedKardexAssociations.ts').reviewedAssociations;
 assert.equal(products.length,432);
 assert.equal(nurseCatalog.length,98);
 assert.equal(approved.length,86);
 assert(!approved.some(a=>a.kardexCode==='E-68'));
 fs.writeFileSync(path.join(output,'n2-ambulatory-products.json'),JSON.stringify(products));
 fs.writeFileSync(path.join(output,'n2-nursing-catalog.json'),JSON.stringify(nurseCatalog));
 fs.writeFileSync(path.join(output,'n2-approved-mappings.json'),JSON.stringify(approved));
 const organization=require('./n2-official-area-catalog.cjs').result;
 const countFor=site=>organization.filter(area=>area.site===site).length;
 assert.equal(countFor('LA VENTUROSA'),31,'Faltan áreas oficiales del fundo');
 assert.equal(countFor('PLVENTUROSA'),124,'Faltan áreas oficiales de PL Venturosa');
 const organizationJSON=JSON.stringify(organization);
 // Two packaging paths: legacy folder resource and a root-level XcodeGen
 // JSON resource included by the App source group. Both contain the same
 // canonical codes sourced from the official ten-sheet workbook.
 const organizationFolderFile=path.join(output,'n2-organization-areas.json');
 const organizationRootFile=path.join(root,'native-ios','App','DANPEROfficialAreas.json');
 fs.writeFileSync(organizationFolderFile,organizationJSON);
 fs.writeFileSync(organizationRootFile,organizationJSON);
 assert.equal(fs.readFileSync(organizationFolderFile,'utf8'),
              fs.readFileSync(organizationRootFile,'utf8'),
              'Las dos copias del catálogo organizativo deben coincidir');
 // Compile-time catalog: XcodeGen will include this Swift source in the app
 // target. The app no longer depends on how folder-reference JSON is copied.
 const swiftQuote=value=>{
  const quoted=JSON.stringify(String(value));
  assert(!quoted.includes('\\u0000'),'Organizational labels cannot contain NUL');
  return quoted;
 };
 const swiftData=organization.map(entry=>
  '        N2OfficialArea(site:'+swiftQuote(entry.site)+
  ',area:'+swiftQuote(entry.area)+
  ',code:'+swiftQuote(entry.code)+')').join(',\n');
 const swiftSource=[
  '// GENERATED — DO NOT EDIT. Official areas only, no staff or patient data.',
  '// Source: verified 10-sheet DANPER workbook @subuo + @uo.',
  'import DanperCore',
  'enum N2GeneratedOfficialAreas {',
  '    static let entries:[N2OfficialArea]=[',
  swiftData,
  '    ]',
  '}',
  ''
 ].join('\n');
 const swiftPath=path.join(root,'native-ios','App','N2GeneratedOfficialAreas.swift');
 fs.writeFileSync(swiftPath,swiftSource);
 assert(swiftSource.includes('N2OfficialArea(site:"PLVENTUROSA"'));
 assert(swiftSource.includes('N2OfficialArea(site:"LA VENTUROSA"'));
 console.log('PASS Swift compilado: '+organization.length+' áreas verificadas.');
 console.log('PASS áreas oficiales: Fundo La Venturosa 31; PL Venturosa 124.');
 assert.deepEqual(fs.readdirSync(output).sort(),[
  'n1s-indicator-plan.json','n1s-indicator-template-store.zip',
  'n1s-nursing-plan.json','n1s-nursing-template-store.zip',
  'n2-synthetic-clinical.json','n2-ambulatory-products.json',
  'n2-nursing-catalog.json','n2-approved-mappings.json',
  'n2-organization-areas.json'
 ].sort());
 console.log('PASS: nine sanitized preview resources; no real worker or patient data.');
} finally {
 fs.rmSync(temporary,{recursive:true,force:true});
}

