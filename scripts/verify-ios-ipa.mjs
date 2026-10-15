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
const plist=JSON.parse(execFileSync('plutil',['-convert','json','-o','-',`outputs/DanperSalud.xcarchive/Products/Applications/App.app/Info.plist`],{encoding:'utf8'}));
assert.equal(plist.CFBundleIdentifier,'pe.danper.saludmovil.prototipo');
const tmp=fs.mkdtempSync(path.join(process.env.RUNNER_TEMP||'/tmp','danper-ipa-'));
try{
 const local=path.join(tmp,'Info.plist');fs.writeFileSync(local,parts[prefix+'Info.plist']);
 const packed=JSON.parse(execFileSync('plutil',['-convert','json','-o','-',local],{encoding:'utf8'}));
 assert.equal(packed.CFBundleShortVersionString,version);assert.equal(packed.CFBundleVersion,'214');
 assert.equal(packed.CFBundleIdentifier,'pe.danper.saludmovil.prototipo');
 assert(typeof packed.NSFaceIDUsageDescription==='string'&&packed.NSFaceIDUsageDescription.includes('Face ID'),
  'El IPA carece de NSFaceIDUsageDescription');
 const name=packed.CFBundleExecutable;
 assert.equal(typeof name,'string');assert(!name.includes('/')&&!name.includes('..'),'Nombre de ejecutable inválido');
 const executable=parts[prefix+name];assert(executable?.length>=32,'Falta ejecutable iOS');
 const header=Buffer.from(executable.subarray(0,32));
 assert.equal(header.readUInt32LE(0),0xfeedfacf,'El ejecutable no es Mach-O 64 bits');
 assert.equal(header.readUInt32LE(4),0x0100000c,'El ejecutable no es ARM64 para iPhone');
 assert.equal(header.readUInt32LE(12),2,'El Mach-O no es un ejecutable');
}finally{fs.rmSync(tmp,{recursive:true,force:true})}
assert(!Object.keys(parts).some(n=>/\.xlsx$|\.xls$|\.ipa$|upload\//i.test(n)),'Se incluyó un Excel o adjunto bruto');
const embedded=parts[prefix+'public/internal/kardex-template.bin'];
assert(embedded?.length>8000,'El IPA no contiene el Kardex de Enfermería');
assert.equal(crypto.createHash('sha256').update(embedded).digest('hex'),'4e6948b331be7e2ef5f24a9d26d4fa76197db1701cdd47a858523d398d6ca07e');
const js=Object.entries(parts).filter(([n])=>n.startsWith(prefix+'public/')&&n.endsWith('.js'));
assert(js.some(([,b])=>strFromU8(b).includes('TB_CONSUMOS')),'Falta exportador ambulatorio');
console.log(`PASS: IPA ${version}, build 214, ejecutable, exportador, ausencia de XLSX bruto y SHA256 ${hash}`);
