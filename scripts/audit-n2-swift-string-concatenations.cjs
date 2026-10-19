#!/usr/bin/env node
'use strict';
// Prevent the repeated Swift Xcode 'operator + is not a postfix unary operator'
// regressions where an unparenthesized SwiftUI multiline string ends with '+'.
// Safe source lint: no clinical records or artifacts are accessed or changed.
const fs=require('node:fs');
const path=require('node:path');
const files=[
  'native-ios/App/N2NativeClinicalFormView.swift',
  'native-ios/App/N2VerifiedIndicatorExportView.swift',
  'native-ios/App/N2VerifiedNursingExportView.swift',
  'native-ios/App/N2DemoResetView.swift',
  'native-ios/App/N2NativeBackupExportView.swift'
];
let failed=0;
for(const name of files) {
  const data=fs.readFileSync(path.resolve(__dirname,'..',name),'utf8');
  for(const [index,line] of data.split(/\r?\n/).entries()) {
    if(line.trimEnd().endsWith('+')) {
      console.error(name+':'+(index+1)+': dangling operator + across lines; use Swift interpolation or intermediate constants');
      failed++;
    }
  }
}
if(failed)process.exit(1);
console.log('PASS: reviewed native clinical/export Swift files contain no trailing multiline + expressions.');
