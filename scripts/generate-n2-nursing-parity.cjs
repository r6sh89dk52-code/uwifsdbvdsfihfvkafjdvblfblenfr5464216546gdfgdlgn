'use strict';
// Reference comes directly from build222 TypeScript, entirely fabricated
// snapshot N1e and the 98 official (non-donated) nursing catalog entries.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {load}=require('./ambulatory-test-helpers.cjs');
const dir=process.env.DANPER_N1_FIXTURE_DIR;
assert(dir&&path.isAbsolute(dir));
const snapshot=JSON.parse(fs.readFileSync(path.join(dir,'n1e-clinical-stock.json'),'utf8'));
const catalog=load('src/kardexCatalog.ts').kardexCatalog;
const report=load('src/dailyKardex.ts');
const ledger={lots:snapshot.stockLots,movements:snapshot.stockMovements};
const scenarios=[
 {kind:'day',date:'2026-10-13'},
 {kind:'day',date:'2026-10-14'},
 {kind:'day',date:'2026-10-15'},
 {kind:'range',start:'2026-10-13',end:'2026-10-15'}
].map(s=>({...s,expected:s.kind==='day'
 ?report.buildDailyReport(ledger,s.date)
 :report.buildKardexRangeReport(ledger,s.start,s.end)}));
assert.equal(catalog.length,98);
for(const c of scenarios)assert.equal(c.expected.rows.length,98);
fs.writeFileSync(path.join(dir,'n2-nursing-parity.json'),
 JSON.stringify({catalog,scenarios}));
console.log('PASS N2 nursing parity fixtures:',scenarios.map(s=>
 s.kind+':'+(s.date||s.start+'..'+s.end)+':known='+
 s.expected.rows.filter(r=>r.stockKnown).length).join(' '));
