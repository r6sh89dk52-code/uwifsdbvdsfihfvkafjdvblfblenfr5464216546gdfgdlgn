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
 // Legacy sample content is NOT packaged into the operational iOS app.
 // This removes a stale generated fixture only from the project's bundle
 // resources, NOT an installed user's encrypted vault or any employee record.
 fs.rmSync(path.join(output,'n2-synthetic-clinical.json'),{force:true});
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
 assert.equal((swiftSource.match(/N2OfficialArea\(site:/g)||[]).length,155,
              'El catálogo Swift debe contener exactamente las 155 áreas verificadas');
 assert(swiftSource.includes('N2OfficialArea(site:"PLVENTUROSA"'));
 assert(swiftSource.includes('N2OfficialArea(site:"LA VENTUROSA"'));
 console.log('PASS Swift compilado: '+organization.length+' áreas verificadas.');
 console.log('PASS áreas oficiales: Fundo La Venturosa 31; PL Venturosa 124.');
 assert.deepEqual(fs.readdirSync(output).sort(),[
  'n1s-indicator-plan.json','n1s-indicator-template-store.zip',
  'n1s-nursing-plan.json','n1s-nursing-template-store.zip',
  'n2-ambulatory-products.json',
  'n2-nursing-catalog.json','n2-approved-mappings.json',
  'n2-organization-areas.json'
 ].sort());
 console.log('PASS: eight sanitized templates/catalog resources. No bundled worker or patient dataset.');
} finally {
 fs.rmSync(temporary,{recursive:true,force:true});
}

