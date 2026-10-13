// Run using TypeScript installed by `npm install`, without an additional test framework.
const fs=require('node:fs');const path=require('node:path');const assert=require('node:assert/strict');
const ts=require('typescript');const vm=require('node:vm');
const filepath=path.join(__dirname,'..','src','workerRules.ts');
const src=fs.readFileSync(filepath,'utf8');
const compiled=ts.transpileModule(src,{fileName:filepath,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},reportDiagnostics:true});
assert.equal((compiled.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).length,0);
const sandboxModule={exports:{}};vm.runInNewContext(compiled.outputText,{module:sandboxModule,exports:sandboxModule.exports,require}, {filename:'workerRules.js'});
const {compileWorkers,reconcileWorkers,normalizeDni}=sandboxModule.exports;
const rows=[['DNI','NOMBRES','FECHA DE NACIMIENTO','EDAD MANUAL','EDAD AUTOMATIZADA','SEXO','UBIGEO','AREA','CARGO'],['00001234','APELLIDO UNO',null,26,26,'F','CHEPÉN','','OPERARIO'],['00001234','APELLIDO UNO',null,'','','','', 'CAMPO',''],['12345678','APELLIDO DOS',null,29,29,'M','', 'PACKING', 'AUXILIAR'],['abc','INCORRECTO'],['11111111','']];
const parsed=compileWorkers(rows);
assert.equal(parsed.stats.valid,2);assert.equal(parsed.stats.duplicates,1);assert.equal(parsed.stats.invalidDni,1);assert.equal(parsed.stats.withoutName,1);
assert.equal(parsed.workers[0].dni,'00001234');assert.equal(parsed.workers[0].area,'CAMPO');
const manual={dni:'00001234',name:'NOMBRE CORREGIDO',area:'AREA MANUAL',labor:'',sex:'',age:'',ubigeo:'',source:'manual'};
const merge=reconcileWorkers([manual],parsed.workers);
assert.equal(merge.stats.added,1);assert.equal(merge.stats.merged,1);assert.equal(merge.stats.manualPreserved,1);
assert.equal(merge.workers.find(w=>w.dni==='00001234').name,'NOMBRE CORREGIDO');
assert.equal(merge.workers.find(w=>w.dni==='00001234').area,'AREA MANUAL');
assert.equal(merge.workers.find(w=>w.dni==='00001234').labor,'OPERARIO');
assert.equal(normalizeDni('00123456'),'00123456');assert.equal(normalizeDni('1E+07'),'');
assert.throws(()=>compileWorkers([['ID','NOMBRE'],['00000001','TEST']]),/encabezados/);
console.log('PASS: pruebas básicas de normalización, duplicados, importación y conciliación.');

// v0.4: independent suggestion for each product, contextual supplies and manual correction.
const procedureFile=path.join(__dirname,'..','src','procedureRules.ts');
const procedureSrc=fs.readFileSync(procedureFile,'utf8');
const procedureJs=ts.transpileModule(procedureSrc,{fileName:procedureFile,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},reportDiagnostics:true});
assert.equal((procedureJs.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).length,0);
const procMod={exports:{}};vm.runInNewContext(procedureJs.outputText,{module:procMod,exports:procMod.exports}, {filename:'procedureRules.js'});
const {inferProcedure,procedureDetail}=procMod.exports;
const injectable=inferProcedure({name:'DICLOFENACO AMPOLLA 75 MG'},[]);
assert.equal(injectable.procedure,'INYECTABLE');
const syringe=inferProcedure({name:'JERINGA 5 CC'},[injectable]);
assert.equal(syringe.procedure,'INYECTABLE');
const needle=inferProcedure({name:'AGUJA 21G X 100 UND'},[injectable,syringe]);
assert.equal(needle.procedure,'INYECTABLE');
const tablet=inferProcedure({name:'PARACETAMOL TABLETA 500 MG'},[injectable,syringe,needle]);
assert.equal(tablet.procedure,'TRATAMIENTO ORAL','Oral tablet should not inherit prior injectable');
assert.equal(inferProcedure({name:'JERINGA 5 CC'},[]).procedure,'','Supply without relevant context needs explicit selection');
assert.equal(inferProcedure({name:'GASA ESTERILIZADA'},[],['CURACION DE HERIDA']).procedure,'CURACION DE HERIDA');
assert.equal(inferProcedure({name:'GASA ESTERILIZADA'},[injectable],['CURACION DE HERIDA']).procedure,'','Ambiguous use must not be guessed');
assert.equal(procedureDetail('INYECTABLE'),'INSUMOS');
assert.equal(procedureDetail('TRATAMIENTO ORAL'),'-');
const appSrc=fs.readFileSync(path.join(__dirname,'..','src','main.tsx'),'utf8');
assert.ok(!appSrc.includes('Procedimiento activo para vincular insumos'));
assert.ok(!appSrc.includes('setActiveProcedure'));
assert.ok(appSrc.includes('CURACION DE HERIDA'));
console.log('PASS: clasificación independiente v0.4, insumos contextualizados, curación y controles de UI.');

// v0.5: textual allergy warnings and ergonomic ordering; not a clinical safety engine.
const allergyFile=path.join(__dirname,'..','src','allergyRules.ts');
const allergyJs=ts.transpileModule(fs.readFileSync(allergyFile,'utf8'),{fileName:allergyFile,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022},reportDiagnostics:true});
assert.equal((allergyJs.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).length,0);
const allergyMod={exports:{}};vm.runInNewContext(allergyJs.outputText,{module:allergyMod,exports:allergyMod.exports},{filename:'allergyRules.js'});
const {medicationAllergyMatches}=allergyMod.exports;
assert.equal(medicationAllergyMatches('DICLOFENACO AMPOLLA','diclofenaco').length,1);
assert.equal(medicationAllergyMatches('PARACETAMOL TABLETA','penicilina').length,0);
assert.equal(medicationAllergyMatches('PARACETAMOL TABLETA','').length,0);
assert.equal(medicationAllergyMatches('ACIDO ACETILSALICILICO','ácido acetilsalicílico').length,1);
assert.ok(appSrc.indexOf('Alergias del trabajador')<appSrc.indexOf('Medicamentos e insumos <span'), 'Allergy review must precede medication selector');
assert.ok(appSrc.indexOf('Alergias del trabajador')<appSrc.indexOf('Procedimientos independientes'), 'Allergy review must precede procedures');
assert.ok(appSrc.includes('role="group" aria-label="Estado de alergias"'));
assert.ok(appSrc.includes('className="itemSummary"'));
assert.ok(appSrc.includes('className="registerDock"'));
assert.ok(!appSrc.includes('Procedimiento activo para vincular insumos'));
assert.ok(appSrc.includes('InferProcedure')===false); // keep the original per-product inferProcedure
console.log('PASS: v0.5 alergias antes de tratamientos, coincidencias textuales y medicamentos compactos.');
