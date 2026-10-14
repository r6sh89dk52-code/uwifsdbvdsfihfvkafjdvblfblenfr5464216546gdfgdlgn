const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),ts=require('typescript');
const {webcrypto}=require('node:crypto');const keys=new Map();
let native=true,locked=false;const SecureStorage={
 async setKeyPrefix(){},async setSynchronize(){},async setDefaultKeychainAccess(){},
 async getItem(k){if(locked)throw Error('Keychain inaccessible');return keys.get(k)??null},
 async setItem(k,v){keys.set(k,v)}
};
const compiled=ts.transpileModule(fs.readFileSync('src/localAppLock.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
const unit={exports:{}};vm.runInNewContext(compiled,{module:unit,exports:unit.exports,
 require:name=>{
 if(name==='@capacitor/core')return {Capacitor:{isNativePlatform:()=>native,getPlatform:()=>native?'ios':'web'}};
 if(name==='@aparajita/capacitor-secure-storage')return {SecureStorage,KeychainAccess:{whenUnlockedThisDeviceOnly:1}};
 throw Error(name);
 },crypto:{subtle:webcrypto.subtle,getRandomValues:x=>webcrypto.getRandomValues(x)},Uint8Array,ArrayBuffer,TextEncoder,Promise,Date,Error,JSON,Number,
 btoa:s=>Buffer.from(s,'latin1').toString('base64'),atob:s=>Buffer.from(s,'base64').toString('latin1')
},{filename:'localAppLock.js'});
(async()=>{
 const lock=unit.exports;
 assert.equal(await lock.appLockEnabled(),false);
 await assert.rejects(lock.enableAppLock('1234567'),/12/);
 await lock.enableAppLock('UnaClaveUnicaMuySegura2026');
 assert.equal(await lock.appLockEnabled(),true);
 assert.ok(!JSON.stringify([...keys]).includes('UnaClaveUnicaMuySegura2026'),'never stores plaintext passphrase');
 assert.equal(await lock.unlockAppLock('ClaveEquivocada2026'),false);
 assert.equal(await lock.unlockAppLock('UnaClaveUnicaMuySegura2026'),true);
 for(let i=0;i<10;i++)assert.equal(await lock.unlockAppLock('MalMalMalMalMal'),false);
 await assert.rejects(lock.unlockAppLock('UnaClaveUnicaMuySegura2026'),/15 minutos/,'rate limit applies even to correct passphrase');
 keys.set('local-ui-lock-attempts-v1','10:'+(Date.now()-2000));
 assert.equal(await lock.unlockAppLock('UnaClaveUnicaMuySegura2026'),true,'cooldown expires');
 await assert.rejects(lock.disableAppLock('ContraseñaIncorrecta'),/incorrecta/);
 await lock.disableAppLock('UnaClaveUnicaMuySegura2026');
 assert.equal(await lock.appLockEnabled(),false);
 locked=true;await assert.rejects(lock.appLockEnabled(),/Keychain inaccessible/,'fail closed if Keychain unavailable');
 locked=false;
 native=false;assert.equal(await lock.appLockEnabled(),false);
 console.log('PASS: iPhone app lock, verified passphrase, wrong password, cooldown, explicit disable, Keychain failure and browser bypass.');
})().catch(e=>{console.error(e);process.exitCode=1});
