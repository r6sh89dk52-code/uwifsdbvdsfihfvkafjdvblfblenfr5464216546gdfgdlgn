'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),read=p=>fs.readFileSync(path.join(root,p),'utf8');
const app=read('native-ios/App/DANPERNativeApp.swift'),ui=read('native-ios/App/DanperPremiumUI.swift'),theme=read('native-ios/App/DanperUITheme.swift');
const inventory=read('native-ios/App/N2SimpleInventoryView.swift'),presentation=read('native-ios/App/N2InventoryPresentation.swift'),glass=read('native-ios/App/DanperPremiumPresentation.swift');
for(const [asset,hash] of [['ClinicalPortrait','c43917268ce67191a70e2b6549747229b3e7414b21c951bf4432d3257f177291'],['ClinicalAvatar','caf85b6e0704edc7663ed4da677e1a1db796f11d6b29a34056a0001c6a82f4c1']]) {
 const bytes=fs.readFileSync(path.join(root,`native-ios/App/Assets.xcassets/${asset}.imageset/${asset}.png`));
 assert.equal(crypto.createHash('sha256').update(bytes).digest('hex'),hash,asset+' must be the exact supplied asset');
}
assert(app.includes('Image("ClinicalPortrait")'));assert(ui.includes('Image("ClinicalAvatar")'));assert(app.includes('Image(systemName:"faceid")'));
assert(!app.includes('Image("AccessHero")'));assert(!ui.includes('Text("Bienvenido")'));assert(!app.includes('Text("Bienvenido")'));
for(const marker of ['shape.fill(.ultraThinMaterial)','accessibilityReduceTransparency','DanperBackdrop','struct DanperGlassAction'])assert(glass.includes(marker),marker);
assert(!glass.includes('surface.opacity(0.78)'),'Do not cover the material with nearly opaque paint');
assert(theme.includes('danperGlassSurface(cornerRadius:20)'));
assert(theme.includes('accessibilityHidden(true)'),'Decorative bell is not a fake action');
for(const marker of ['case all="Todos",medications="Medicamentos",supplies="Insumos"','authorizedNursingOptions','expiryWarningDays=30','p.name,p.code,p.unit','Pendiente de verificar'])assert(presentation.includes(marker),marker);
assert(!/applySimple|activateSimple|\.shared/.test(presentation),'Presentation helpers cannot write or reach a vault');
for(const marker of ['.safeAreaInset(edge:.top','glass-inventory-filter','simple-inventory-search','N2GlassInventoryRow','product.quantity==0','Sin existencias','product.unit','glass-expiry-','simple-stock-','simple-receipt','simple-outflow','simple-count','simple-expiry'])assert(inventory.includes(marker),marker);
for(const file of ['NativeRootView','N2ClinicalWorkspaceView']) {
 const source=read('native-ios/App/'+file+'.swift');
 assert.deepEqual([...source.matchAll(/\.tabItem\s*\{\s*Label\("([^"]+)"/g)].map(m=>m[1]),['Inicio','Historial','Borradores','Ajustes']);
 assert(source.includes('Button("Ver todas",systemImage:"chevron.right") {tab=3}'));
 for(const destination of ['N2Build222KardexHub()','DanperStatisticsView()','DanperExportsView()','N2NativeHistoryView(useProtectedVault:true,showWorkers:true)'])assert(source.includes(destination));
}
console.log('PASS: exact portrait/avatar hashes; native Face ID; real dark Material; no welcome block; unchanged four tabs/tools; catalog-only filters, inline search and expiry/zero-stock presentation. Runtime tests are separate.');
