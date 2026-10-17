// Frozen oracle from build222 09fef294, never the new Swift implementation.
const fs=require('node:fs'),path=require('node:path'),ts=require('typescript');
const oracle=fs.readFileSync(path.join(__dirname,'fixtures/build222-procedureRules.ts'),'utf8');
const code=ts.transpileModule(oracle,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
const mod={exports:{}};new Function('exports','module',code)(mod.exports,mod);
const products=require('../src/products.json');
const names=[...products.map(p=>p.name),'cápsula de prueba','AMPOLLA','jeringa','gasa','NYLON CON AGUJA','AGUJA ODONTOLOGICA','AGUJA ACUPUNTURA','ALCOHOL','pomada','gotas oculares'];
const contexts=[[],['INYECTABLE'],['CURACION DE HERIDA'],['SUTURAS'],['INYECTABLE','CURACION DE HERIDA'],['OBSERVACION'],['INYECTABLE','INYECTABLE']];
const rows=names.flatMap(name=>contexts.map(context=>({name,context,...mod.exports.inferProcedure({name},[],context)})));
const root=process.env.DANPER_N1_FIXTURE_DIR;if(!root)throw Error('Missing synthetic fixture directory');
fs.writeFileSync(path.join(root,'n2-procedure-parity.json'),JSON.stringify(rows));
console.log('Frozen build222 procedure oracle: '+rows.length+' cases, '+products.length+' catalog products');
