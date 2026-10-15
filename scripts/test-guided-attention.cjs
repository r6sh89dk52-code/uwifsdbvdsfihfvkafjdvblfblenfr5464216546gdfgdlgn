// Clinical UI stage-mount regression tests. No real patient data.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ts=require('typescript');
const s=fs.readFileSync('src/main.tsx','utf8');
const css=fs.readFileSync('src/attentionStepper.css','utf8');
const pkg=JSON.parse(fs.readFileSync('package.json','utf8'));
const result=ts.transpileModule(s,{fileName:'main.tsx',reportDiagnostics:true,compilerOptions:{jsx:ts.JsxEmit.ReactJSX,module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022,moduleResolution:ts.ModuleResolutionKind.Bundler,resolveJsonModule:true}});
const errors=result.diagnostics.filter(d=>d.category===ts.DiagnosticCategory.Error);
assert.deepEqual(errors.map(x=>ts.flattenDiagnosticMessageText(x.messageText,' ')),[],'JSX must remain parseable');
assert.equal(pkg.version,'0.21.5');
assert(s.includes('const[registerStep,setRegisterStep]=useState<ClinicalStage>(0)'),'4-step state');
assert(s.includes('setRegisterStep(0);setActive(v);'),'each new or resumed attention begins at worker');
assert(s.includes('function selectRegisterStep(step:ClinicalStage)'),'stage switch');
const ordered=[
  {start:'{registerStep===0&&<><section id="attention-worker"',title:'Trabajador'},
  {start:'{registerStep===1&&<><section className="panel allergyPanel"',title:'Alergias'},
  {start:'{registerStep===2&&<><section className="panel"><h3><ClipboardList',title:'Procedimientos'},
  {start:'{registerStep===3&&<><div className="clinicalReview"',title:'Resultado'}
];
let prev=0;
for(const o of ordered){
 const p=s.indexOf(o.start);
 assert(p>prev,'step '+o.title+' must be conditionally mounted in correct order');
 prev=p;
}
const allergy=s.indexOf('<section className="panel allergyPanel"');
const clinical=s.indexOf('<section id="attention-clinical"');
const procedures=s.indexOf('Procedimientos independientes');
const treatment=s.indexOf('<section id="attention-treatment"');
const resultPanel=s.indexOf('<section id="attention-result"');
assert(allergy<clinical&&clinical<procedures&&procedures<treatment&&treatment<resultPanel,'clinical sequence');
assert(s.includes("registerAllergyCheckpoint"),'treatment must summarize allergy status');
assert(s.includes('selectRegisterStep(1)}>Revisar'),'direct return to allergy assessment');
assert(s.includes("allergyData?.substances?.trim()"),'documented allergy details must remain visible');
assert(s.includes('registerStep>0&&<button'),'back only after first step');
assert(s.includes("registerStep<3?<button"),'next on steps 1-3');
assert(s.includes("onClick={()=>void save()}"),'existing clinical save action preserved on final step');
assert(s.includes("persist(active,'draft');setMessage('Borrador guardado.')"),'manual draft preserved');
for(const step of [0,1,2,3]){
 assert(s.includes('aria-current={registerStep==='+step+"?'step':undefined}"),'accessible current step '+step);
}
for(const msg of ['Confirma fecha y hora válidas.','Revisa la cantidad y confirma el procedimiento de cada producto.','Ingresa un DNI de 8 dígitos.','Ingresa el diagnóstico presuntivo o descripción.']){
 assert(s.includes(msg),'original clinical guard retained: '+msg);
}
for(const needle of ['aria-live="polite"','min-height:40px','safe-area-inset-top','prefers-reduced-motion:reduce','registerAllergyCheckpoint']){
 assert(css.includes(needle)||s.includes(needle),'required accessible UI '+needle);
}
const lock=fs.readFileSync('scripts/install-ios-access-lock.mjs','utf8');
assert(lock.includes('didEnterBackground')||lock.includes('danperAuth'),'native Face ID lock untouched');
console.log('PASS: four exclusive clinical stages, allergy checkpoint, draft persistence, save guards, adaptive styling and TSX parse.');
