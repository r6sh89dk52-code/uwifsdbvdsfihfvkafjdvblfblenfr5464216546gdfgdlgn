'use strict';
// Officially reviewed TS associations, emitted only to a runner temp folder.
// No clinical backup or employee data is processed.
const assert=require('node:assert/strict'),path=require('node:path'),fs=require('node:fs');
const {load}=require('./ambulatory-test-helpers.cjs');
const root=process.env.DANPER_N1_FIXTURE_DIR;
assert(root && path.isAbsolute(root));
const associations=load('src/reviewedKardexAssociations.ts').reviewedAssociations;
assert.equal(associations.length,86);
assert.equal(new Set(associations.map(x=>x.kardexCode)).size,86);
assert.equal(associations.filter(x=>x.clinicalCode==='16024400').length,2);
assert.ok(!associations.some(x=>x.kardexCode==='E-68'));
fs.writeFileSync(path.join(root,'n2-reviewed-approved.json'),JSON.stringify(associations));
console.log('PASS N2: only 86 officially reviewed associations, no unsupported nylon.');
