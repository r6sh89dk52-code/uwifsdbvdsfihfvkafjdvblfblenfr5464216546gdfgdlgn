// iOS keyboard / diagnosis dropdown regression: pure viewport geometry, DOM wiring, accessibility.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ts=require('typescript');
const vm=require('node:vm');
const source=fs.readFileSync('src/diagnosisKeyboardLayout.ts','utf8');
const t=ts.transpileModule(source,{fileName:'diagnosisKeyboardLayout.ts',reportDiagnostics:true,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
assert.equal((t.diagnostics||[]).filter(x=>x.category===ts.DiagnosticCategory.Error).length,0);
const built={};
vm.runInNewContext(t.outputText,{exports:built});
const {suggestionScrollDelta,suggestionMaxHeight}=built;
assert.equal(suggestionScrollDelta({top:400,bottom:670},{offsetTop:0,height:480}),204,'scroll dropdown above iOS keyboard');
assert.equal(suggestionScrollDelta({top:100,bottom:250},{offsetTop:0,height:480}),0,'visible dropdown must not jump');
assert.equal(suggestionScrollDelta({top:400,bottom:670},{offsetTop:40,height:480}),164,'visualViewport top offset considered');
assert.equal(suggestionScrollDelta({top:400,bottom:670},{offsetTop:0,height:900}),0,'keyboard closed should not scroll');
assert.equal(suggestionScrollDelta({top:400,bottom:670},{offsetTop:0,height:480},20),210,'visible safety gap respected');
assert.equal(suggestionScrollDelta({top:400,bottom:670},{offsetTop:0,height:0}),0,'zero viewport fails safely');
assert.equal(suggestionMaxHeight(380),133,'small visual viewport compact list');
assert.equal(suggestionMaxHeight(500),175,'viewport-adaptive list');
assert.equal(suggestionMaxHeight(900),208,'large viewport cap');
assert.equal(suggestionMaxHeight(200),120,'at least two suggestions on small viewport');
const main=fs.readFileSync('src/main.tsx','utf8'),css=fs.readFileSync('src/diagnosisKeyboard.css','utf8');
for(const clause of [
 "import './diagnosisKeyboard.css'",
 "from './diagnosisKeyboardLayout'",
 "ref={diagnosisInputRef}",
 "ref={diagnosisSuggestionsRef}",
 "window.visualViewport",
 "viewport?.addEventListener('resize',reveal",
 "viewport?.addEventListener('scroll',reveal",
 "window.scrollBy({top:delta,behavior:'auto'})",
 "suggestionScrollDelta({top:bounds.top,bottom:bounds.bottom},geometry)",
 "suggestionMaxHeight(geometry.height)",
 "diagnosisDropdownOpen&&<div ref={diagnosisSuggestionsRef}",
 "diagnosisKeyboardScrollRoom",
 "diagnosisMatches.map(d=><button",
 "patch({diagnosis:d});setDiagnosisSuggestionsVisible(false)",
 "diagnosisMatches.length>0",
 "normalize(active?.diagnosis||'').length>=2"
])assert(main.includes(clause),'wiring missing: '+clause);
for(const clause of ['max-height:208px','overflow-y:auto','min-height:46px',':has([data-clinical-field="clinical-diagnosis"] textarea:focus)','height:min(46vh,410px)','prefers-reduced-motion:reduce'])assert(css.includes(clause),'CSS guard missing: '+clause);
assert(!main.includes("setDiagnosisSuggestionsVisible(false)}} placeholder="),'diagnosis textarea should not hide suggestions on typing');
const parse=ts.transpileModule(main,{fileName:'main.tsx',reportDiagnostics:true,compilerOptions:{jsx:ts.JsxEmit.ReactJSX,module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022,moduleResolution:ts.ModuleResolutionKind.Bundler,resolveJsonModule:true}});
assert.deepEqual(parse.diagnostics.filter(d=>d.category===ts.DiagnosticCategory.Error).map(d=>ts.flattenDiagnosticMessageText(d.messageText,' ')),[],'valid TSX');
console.log('PASS: iPhone visual-viewport scroll, keyboard resize, capped suggestions, preserved selection and TSX.');
