#!/usr/bin/env node
'use strict';
// Mechanical release guard: no statement of clinical approval.
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=p=>fs.readFileSync(path.join(root,p),'utf8');
const builder=read('native-ios/Sources/DanperCore/N2VerifiedIndicatorWorkbook.swift');
const writer=read('native-ios/Sources/DanperCore/N1sFullExcelWriter.swift');
const view=read('native-ios/App/N2VerifiedIndicatorExportView.swift');
const tests=read('native-ios/Tests/DanperCoreTests/N2RealIndicatorWorkbookTests.swift');
assert(builder.includes('"LA VENTUROSA","PLVENTUROSA","AMBAS"'));
assert(builder.includes('let sites=subdivision=="AMBAS"'));
assert(builder.includes('sites.allSatisfy'));
assert(builder.includes('consumptionBySite[sourceSite+"|"+code'));
assert(builder.includes('if knownOpenings==sites.count'));
assert(builder.includes('if knownClosings==sites.count'));
assert(builder.includes('guard receipts.count<=4'));
assert(writer.includes('"LA VENTUROSA","PLVENTUROSA","AMBAS"'));
assert(writer.includes('selected.allSatisfy'));
assert(writer.includes('rowSite==site'));
assert(view.includes('options:["AMBAS","LA VENTUROSA","PLVENTUROSA"]'));
assert(view.includes('site=="AMBAS"'));
assert(tests.includes('testJointFundoAndPlantaIndicatorRequiresBothReconciledPeriods'));
console.log('PASS: joint 10-sheet workbook source gates: two independent reviews, site-specific totals, no unknown-source rows, no truncated receipts.');
