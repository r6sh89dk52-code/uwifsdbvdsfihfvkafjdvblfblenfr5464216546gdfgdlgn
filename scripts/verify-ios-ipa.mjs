import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {unzipSync,strFromU8} from 'fflate';
import assert from 'node:assert/strict';
const version=JSON.parse(fs.readFileSync('package.json','utf8')).version;
const filename=`DanperSaludMovil-v${version}-SIN_FIRMAR.ipa`;
const bytes=fs.readFileSync(path.join('outputs',filename));
assert(bytes.length>100000,'IPA incompleto');
const hash=crypto.createHash('sha256').update(bytes).digest('hex');
assert.equal(fs.readFileSync(path.join('outputs',filename+'.sha256'),'utf8').split(/\s/)[0],hash);
const parts=unzipSync(bytes);const prefix='Payload/App.app/';
assert(parts[prefix+'Info.plist'],'Falta Info.plist');
assert(parts[prefix+'App']?.length>100000,'Falta ejecutable iOS');
const plist=JSON.parse(execFileSync('plutil',['-convert','json','-o','-',`outputs/DanperSalud.xcarchive/Products/Applications/App.app/Info.plist`],{encoding:'utf8'}));
assert.equal(plist.CFBundleIdentifier,'pe.danper.saludmovil.prototipo');
const tmp=fs.mkdtempSync(path.join(process.env.RUNNER_TEMP||'/tmp','danper-ipa-'));
try{
 const local=path.join(tmp,'Info.plist');fs.writeFileSync(local,parts[prefix+'Info.plist']);
 const packed=JSON.parse(execFileSync('plutil',['-convert','json','-o','-',local],{encoding:'utf8'}));
 assert.equal(packed.CFBundleShortVersionString,version);assert.equal(packed.CFBundleVersion,'150');
}finally{fs.rmSync(tmp,{recursive:true,force:true})}
assert(!Object.keys(parts).some(n=>/\.xlsx$|\.xls$|\.ipa$|upload\//i.test(n)),'Se incluyó un Excel o adjunto bruto');
const js=Object.entries(parts).filter(([n])=>n.startsWith(prefix+'public/')&&n.endsWith('.js'));
assert(js.some(([,b])=>strFromU8(b).includes('TB_CONSUMOS')),'Falta exportador ambulatorio');
console.log(`PASS: IPA ${version}, build 150, ejecutable, exportador, ausencia de XLSX bruto y SHA256 ${hash}`);
