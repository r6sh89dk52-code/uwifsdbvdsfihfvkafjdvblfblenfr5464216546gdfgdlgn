const assert=require('node:assert/strict');
const fs=require('node:fs');
async function run(){
 const {installGestureInAppDelegate}=await import('./install-ios-gesture.mjs');
 const {installAccessInAppDelegate,ACCESS_MARKER}=await import('./install-ios-access-lock.mjs');
 const fixture=`import UIKit
import Capacitor
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return true
  }
}`;
 const withGesture=installGestureInAppDelegate(fixture);
 const withLock=installAccessInAppDelegate(withGesture);
 assert.ok(withLock.includes(ACCESS_MARKER));
 assert.equal(installAccessInAppDelegate(withLock),withLock,'native injection idempotent');
 assert.throws(()=>installAccessInAppDelegate(fixture),/primero instalar el gesto nativo/,'must install after known Capacitor gesture patch');
 assert.ok(withLock.includes('import LocalAuthentication'),'native iOS LA framework required');
 assert.ok(withLock.includes('LAPolicy = .deviceOwnerAuthentication'),'Face ID + device passcode fallback');
 assert.ok(!withLock.includes('deviceOwnerAuthenticationWithBiometrics'),'passcode fallback must not be omitted');
 assert.ok(withLock.includes('UIApplication.willResignActiveNotification'),'lock must cover app switcher');
 assert.ok(withLock.includes('UIApplication.didBecomeActiveNotification'),'re-authenticate on resume');
 assert.ok(withLock.includes('UIWindow.didBecomeVisibleNotification'),'lock during initial loading');
 assert.ok(withLock.includes('UIColor.systemBackground'),'overlay fully hides sensitive content');
 assert.ok(withLock.includes('guard context.canEvaluatePolicy(policy'),'do not unlock device without authentication');
 assert.ok(withLock.includes('if success && UIApplication.shared.applicationState == .active'),'unlock only after real iOS success');
 assert.ok(withLock.includes('viewWithTag(danperNativeLockTag)?.removeFromSuperview()'),'success unlocks');
 assert.ok(withLock.includes('Autenticación cancelada'),'cancel stays locked with retry');
 const workflow=fs.readFileSync('.github/workflows/ios-ipa.yml','utf8');
 assert.ok(workflow.includes('node scripts/install-ios-access-lock.mjs'),'CI must install native app lock before xcode');
 const build=fs.readFileSync('scripts/build-ios-ipa.sh','utf8');
 assert.ok(build.includes('NSFaceIDUsageDescription'),'Face ID usage reason mandatory');
 const verifier=fs.readFileSync('scripts/verify-ios-ipa.mjs','utf8');
 assert.ok(verifier.includes('NSFaceIDUsageDescription'),'shipped IPA must be inspected for Face ID key');
 console.log('PASS: iOS native biometric/passcode lock initial launch, background, resume, cancel/failure, idempotent Swift injection, Face ID plist.');
}
run().catch(e=>{console.error(e);process.exitCode=1});
