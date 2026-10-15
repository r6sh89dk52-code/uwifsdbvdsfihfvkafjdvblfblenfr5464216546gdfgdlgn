// v0.21.5: verify scroll resets, transparent official brand, secure welcome and runner budget.
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const ts=require('typescript');
const get=p=>fs.readFileSync(p,'utf8');
const main=get('src/main.tsx'),kardex=get('src/KardexWorkspace.tsx');
const logo=get('src/DanperBrandLogo.tsx');
const polish=get('src/visualPolish.css');
const native=get('scripts/install-ios-access-lock.mjs');
const action=get('.github/workflows/ios-ipa.yml');
assert(main.includes('useLayoutEffect(()=>{'),'reset must occur after render and before paint');
assert(main.includes('},[page]);'),'top-level view navigation reset');
assert(main.includes('window.scrollTo({top:0,left:0,behavior:\'auto\'})'),'jump without noticeable animation');
assert(main.includes('window.cancelAnimationFrame(frame)'),'avoid animation-frame leak');
assert(main.includes('<DanperBrandLogo/>'),'official transparent logo in header');
assert(kardex.includes('useLayoutEffect(()=>'),'Kardex submodule scroll reset');
assert(kardex.includes('},[section]);'),'submodule change dependency');
assert(!kardex.includes('kardexMenuLabel'),'no redundant duplicate Kardex navigation');
assert(kardex.includes('Tu Kardex, paso a paso'),'four guided links retained');
assert(kardex.includes("navigate('inventory')"));
assert(kardex.includes("navigate('movements')"));
assert(kardex.includes("navigate('deliveries')"));
assert(kardex.includes("navigate('reports')"));
for(const cls of ['brand-logo-crop','brand-logo-fallback','--danper-red:#e3182d','scroll-padding-top:0','safe-area-inset-top','prefers-reduced-motion:reduce'])assert(polish.includes(cls),cls);
assert(logo.includes('officialLogo'),'original logo only');
assert(logo.includes('await img.decode()'),'decode before canvas processing');
assert(logo.includes('canvas.toDataURL'),'render cropped logo once');
assert(logo.includes('disposed=true'),'no late updates after unmount');
const compiled=ts.transpileModule(logo,{fileName:'DanperBrandLogo.tsx',reportDiagnostics:true,compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}});
assert.deepEqual((compiled.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).map(d=>ts.flattenDiagnosticMessageText(d.messageText,' ')),[]);
const moduleExports={};
const stubs={
 'react':{useEffect(){},useState(){}},
 './branding/danper-logo-oficial.png':{default:'data:mock'},
 'react/jsx-runtime':{jsx(){},jsxs(){}}
};
vm.runInNewContext(compiled.outputText,{exports:moduleExports,require:(p)=>{if(!(p in stubs))throw Error(p);return stubs[p]},Uint8ClampedArray,Math,Image:class{}});
const alpha=moduleExports.wordmarkAlpha,clean=moduleExports.cleanWordmarkPixels;
assert.equal(alpha(0,0),0,'red-only background becomes transparent');
assert.equal(alpha(255,255),255,'white original text stays opaque');
assert(alpha(80,90)>0&&alpha(80,90)<255,'antialias preserved');
const px=clean(new Uint8ClampedArray([255,0,0,255,255,255,255,255]));
assert.equal(px[3],0,'red bg keyed out');
assert.equal(px[7],255,'white lettering stays');
assert.equal(px[4],255);
for(const item of ['private func danperCleanWordmark','CIFilter(name: "CIColorMatrix")','private func danperAddLockOverlay','let hero = UIView()','hero.backgroundColor = red','let lower = UIView()','sections.axis = .vertical','button.setTitle("Ingresar con Face ID"','UIView.animate(withDuration: 1.75','CGAffineTransform(scaleX: 1.025, y: 1.025)','UIAccessibility.isReduceMotionEnabled','danperAuthGeneration += 1','LAPolicy = .deviceOwnerAuthentication']){
 assert(native.includes(item),item);
}
assert(action.includes("if: github.event_name == 'workflow_dispatch' || (github.event_name == 'push' && github.ref == 'refs/heads/main')"),'macOS cannot automatically run on pull request');
assert(action.includes('runs-on: macos-15'),'explicit Mac approval still possible');
assert(main.includes("import './visualPolish.css'"),'load new styles last');
assert(!main.includes('diagnosisFloatingSuggestions'),'discarded keyboard popover must remain excluded');
for(const path of ['src/main.tsx','src/KardexWorkspace.tsx']){
 const q=ts.transpileModule(get(path),{fileName:path,reportDiagnostics:true,compilerOptions:{module:ts.ModuleKind.ESNext,jsx:ts.JsxEmit.ReactJSX,target:ts.ScriptTarget.ES2022}});
 assert.deepEqual((q.diagnostics||[]).filter(d=>d.category===ts.DiagnosticCategory.Error).map(d=>ts.flattenDiagnosticMessageText(d.messageText,' ')),[],path+' TSX valid');
}
console.log('PASS: visual polish, native secure welcome, scroll reset, authentic logo alpha and PR-safe macOS budget.');
