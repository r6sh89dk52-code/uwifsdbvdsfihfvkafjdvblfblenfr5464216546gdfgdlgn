'use strict';
const fs=require('node:fs'),path=require('node:path'),{spawnSync}=require('node:child_process');
const out=process.env.DANPER_AUDIT_OUT;if(!out)throw Error('Set DANPER_AUDIT_OUT');fs.mkdirSync(out,{recursive:true});
const base=require('../../package.json').scripts['test:logic'].split(' && ').map(s=>s.replace(/^node /,''));
if(base.length!==50)throw Error('Review changed JavaScript baseline count');
const additional=[
 'test-n2-build222-ui-parity','test-n2-premium-redesign','test-n2-simple-inventory-v2','test-n2-glass-clinical',
 'audit-n2-workspace-routing','test-n2-workspace-routing','audit-n2-build222-backup-restore','audit-n2-swift-string-concatenations',
 'audit-n2-personal-import','audit-n2-joint-indicator','test-n1s-one-click-container-consent','glass-audit/identity'
].map(x=>'scripts/'+x+'.cjs');
const results=[];
for(const [group,files] of [['javascript-50',base],['additional-12',additional]])for(const file of files){
 const r=spawnSync(process.execPath,[file],{encoding:'utf8',maxBuffer:32*1024*1024});
 fs.writeFileSync(path.join(out,file.replaceAll('/','_')+'.log'),(r.stdout||'')+(r.stderr||'')+(r.error||''));
 results.push({group,file,exit:r.status});console.log(r.status===0?'PASS':'FAIL',file);
}
fs.writeFileSync(path.join(out,'javascript-results.json'),JSON.stringify(results,null,2));
if(results.some(x=>x.exit!==0))process.exitCode=1;
