// Keyboard popup geometry and iPhone UI regression. Synthetic geometry only.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const ts=require('typescript');
const vm=require('node:vm');
const moduleSource=fs.readFileSync('src/diagnosisKeyboardLayout.ts','utf8');
const compiled=ts.transpileModule(moduleSource,{fileName:'diagnosisKeyboardLayout.ts',reportDiagnostics:true,compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}});
assert.equal((compiled.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).length,0);
const exposed={};vm.runInNewContext(compiled.outputText,{exports:exposed});
const {diagnosisPopoverPosition,diagnosisInputClearance}=exposed;
const viewport={height:540,width:390,offsetTop:0,offsetLeft:0};
const input={left:22,top:265,bottom:375,width:346};
const first=diagnosisPopoverPosition(viewport,input,{x:0,y:850},2);
assert(first,'open keyboard must show suggestions');
assert.equal(first.top,850+540-first.maxHeight-10,'popup must be above visual keyboard');
assert.equal(first.left,22);
assert.equal(first.width,346);
assert(first.maxHeight>=125,'at least two entries visible on normal phone');
assert.equal(diagnosisInputClearance(375,first.visibleTop),0,'do not jump if textarea already clear');
const overlayed=diagnosisPopoverPosition({height:455,width:390,offsetTop:25,offsetLeft:0},input,{x:0,y:900},7);
assert(overlayed,'compact viewport needs popup');
assert.equal(overlayed.top,900+25+455-overlayed.maxHeight-10,'visual viewport vertical offset respected');
assert(overlayed.maxHeight<=Math.round(455*.37),'list height must adapt to small keyboard viewport');
assert(diagnosisInputClearance(440,overlayed.visibleTop)>0,'avoid covering insertion area');
const narrow=diagnosisPopoverPosition({height:330,width:300,offsetTop:0,offsetLeft:0},{left:270,top:50,bottom:140,width:340},{x:0,y:0},2);
assert(narrow.left+narrow.width<=300,'popup clamped to right edge');
assert(narrow.left>=12,'popup clamped to left edge');
assert.equal(diagnosisPopoverPosition({height:0,width:390,offsetTop:0,offsetLeft:0},input,{x:0,y:0},2),null,'unknown keyboard geometry fails closed');
assert.equal(diagnosisPopoverPosition(viewport,input,{x:0,y:0},0),null,'no matches: no popup');
const main=fs.readFileSync('src/main.tsx','utf8');
const css=fs.readFileSync('src/diagnosisKeyboard.css','utf8');
const required=[
 'import{createRoot,createPortal}', 'diagnosisPopoverPosition(v,',
 'diagnosisInputClearance(input.bottom,popup.visibleTop)',
 'document.activeElement!==diagnosisInputRef.current',
 'diagnosisDropdownOpen&&diagnosisPopover&&createPortal(',
 "onPointerDown={e=>e.preventDefault()}",
 "onClick={()=>{patch({diagnosis:d});setDiagnosisSuggestionsVisible(false);diagnosisInputRef.current?.blur()}}",
 "onFocus={()=>{setDiagnosisEditing(true);setDiagnosisSuggestionsVisible(true)}}",
 "onBlur={()=>{setDiagnosisEditing(false);setDiagnosisSuggestionsVisible(false)}}",
 "' diagnosisKeyboardEditing'",
 "vv?.addEventListener('resize',schedule",
 "window.addEventListener('scroll',schedule",
 'window.cancelAnimationFrame(raf)',
 "style={{position:'absolute',top:diagnosisPopover.top",
 "role=\"group\" aria-label=\"Sugerencias de diagnóstico\"",
 "patch({diagnosis:e.target.value});setDiagnosisSuggestionsVisible(true)",
];
for(const item of required)assert(main.includes(item),'missing portal behavior '+item);
assert(!main.includes('diagnosisKeyboardScrollRoom'),'broken in-flow spacer must be removed');
assert(!main.includes('ref={diagnosisSuggestionsRef}'),'suggestions must not live inside transformed form');
for(const c of ['body > .diagnosisFloatingSuggestions','z-index:1100','min-height:48px','diagnosisKeyboardEditing .registerDock','diagnosisKeyboardEditing .appTabBar','display:none!important','max-height:124px','prefers-reduced-motion:reduce']){
 assert(css.includes(c),'missing layout safety '+c);
}
const parse=ts.transpileModule(main,{fileName:'main.tsx',reportDiagnostics:true,compilerOptions:{jsx:ts.JsxEmit.ReactJSX,module:ts.ModuleKind.ESNext,target:ts.ScriptTarget.ES2022,moduleResolution:ts.ModuleResolutionKind.Bundler,resolveJsonModule:true}});
assert.deepEqual(parse.diagnostics.filter(d=>d.category===ts.DiagnosticCategory.Error).map(x=>ts.flattenDiagnosticMessageText(x.messageText,' ')),[],'new JSX must parse');
console.log('PASS: detached keyboard-safe diagnosis popup, 2 options, viewport geometry, hidden dock+tabs, free text & selection.');
