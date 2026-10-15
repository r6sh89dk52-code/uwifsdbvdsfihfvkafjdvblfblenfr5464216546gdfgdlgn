const assert=require('node:assert/strict'),fs=require('node:fs');
const {load}=require('./ambulatory-test-helpers.cjs');
const{DANPER_WORKSITES}=load('src/danperWorksites.ts');
const{organizationDirectory,findOfficialArea,suggestOfficialAreas,normalizeArea}=load('src/organizationDirectory.ts');
const db=organizationDirectory();
assert.deepEqual(Object.keys(db.societies).sort(),['LA VENTUROSA','PLVENTUROSA']);
assert.equal(db.societies['LA VENTUROSA'],'1003');
assert.equal(db.societies['PLVENTUROSA'],'1001');
assert.equal(DANPER_WORKSITES.length,2);
assert.equal(db.areas['LA VENTUROSA'].length,31);
assert.equal(db.areas['PLVENTUROSA'].length,124);
assert.equal(findOfficialArea('LA VENTUROSA','SERVICIOS DE SALUD')?.code,'20000136');
assert.equal(findOfficialArea('LA VENTUROSA','SERVICIOS DE SALUD')?.society,'1003');
assert.equal(findOfficialArea('PLVENTUROSA','SERVICIOS DE SALUD')?.society,'1001');
assert.equal(findOfficialArea('PLVENTUROSA','SERVICIOS DE SALUD')?.code,'20000066');
assert.equal(findOfficialArea('LA VENTUROSA','  servicios de salud  ')?.code,'20000136');
assert.equal(findOfficialArea('PLVENTUROSA','ÁREA PERSONALIZADA'),undefined);
assert.equal(findOfficialArea('INVALIDA','SERVICIOS DE SALUD'),undefined);
assert.deepEqual(suggestOfficialAreas('LA VENTUROSA','s',5),[]);
assert(suggestOfficialAreas('PLVENTUROSA','salud',5).length>0);
assert(suggestOfficialAreas('PLVENTUROSA','a',5).length===0);
assert(suggestOfficialAreas('PLVENTUROSA','OPERACIONES',5).length<=5);
assert.equal(normalizeArea('  áREa     mixta'),'AREA MIXTA');
const main=fs.readFileSync('src/main.tsx','utf8'),ui=fs.readFileSync('src/OfficialAreaField.tsx','utf8');
for(const piece of ['OfficialAreaField className="workerFieldArea"','site={active.worker.site}',
  'site={workerForm.site}','onChange={area=>setWorkerForm({...workerForm,area})}',
  'validDanperWorksite(w.site)','workerNeedsProfileSave(w:Worker)']){
 assert(main.includes(piece),'registration integration: '+piece);
}
for(const piece of ['suggestOfficialAreas(site,value,5)','onChange(e.target.value)','onClick={()=>{onChange(item.area)','Área libre: se guardará tal como la escribiste','match.group','suggestionScrollDelta','window.visualViewport']){
 assert(ui.includes(piece),'suggestion interface: '+piece);
}
assert(main.indexOf('Sede del trabajador')<main.indexOf('OfficialAreaField className="workerFieldArea"'),
 'site must appear above dependent area suggestions in clinical form');
assert(main.indexOf('<label className="workerFieldSite">Sede<select')<main.indexOf('OfficialAreaField site={workerForm.site}'),
 'site must appear above area autocomplete in staff profile');
const rows=fs.readFileSync('src/ambulatoryRows.ts','utf8');
assert(rows.includes("const cells:ExportValue[]=[rowSubdivision,a.worker.area||'','',''"),'area text must survive if no official code');
const book=fs.readFileSync('src/ambulatoryExcel.ts','utf8');
assert(book.includes("VLOOKUP(CONCATENATE(VLOOKUP(A${row},'@subuo'!"),'original official organization codes still come from verified source');
assert(book.includes("IFERROR("),'unknown org code must not be fabricated');
const workflow=fs.readFileSync('.github/workflows/ios-ipa.yml','utf8');
assert(workflow.includes("if: github.event_name == 'workflow_dispatch'"),'avoid Mac PR builds');
console.log('PASS: exact embedded official @subuo/@uo, site-specific 31/124 areas, free text without forced code, scoped suggestions and original Excel formulas.');
