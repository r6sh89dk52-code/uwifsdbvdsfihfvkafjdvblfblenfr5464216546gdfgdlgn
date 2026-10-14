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
 assert.ok(withLock.includes('if success {'),'remember success even if app is temporarily inactive');
 assert.ok(!withLock.includes('if success && UIApplication.shared.applicationState == .active'),'inactive Face ID success must not be rejected');
 assert.ok(withLock.includes('UIApplication.didEnterBackgroundNotification'),'true background must revoke authorization');
 assert.ok(withLock.includes('danperAuthGeneration += 1'),'invalidate old background-era callbacks');
 assert.ok(withLock.includes('guard generation == danperAuthGeneration else { return }'),'stale authentication must not unlock a reopened app');
 assert.ok(withLock.includes('danperAuthContext?.invalidate()'),'revoke in-flight Face ID when actually backgrounded');
 const resignSection=withLock.split('@objc private func danperAuthWillResign')[1].split('@objc private func danperAuthDidEnterBackground')[0];
 assert.ok(!resignSection.includes('danperAuthUnlocked = false'),'temporary Face ID interruption must not relock');
 assert.ok(resignSection.includes('danperAddLockOverlay'),'privacy cover remains during Face ID transitions');
 const foregroundSection=withLock.split('@objc private func danperAuthDidBecomeActive')[1].split('private func danperAppWindows')[0];
 assert.ok(foregroundSection.includes('if danperAuthUnlocked'),'successful inactive authentication must resume without new prompt');
 assert.ok(foregroundSection.includes('} else if !danperAuthAttemptInFlight'),'no duplicate Face ID prompt while a request is in flight');
 const visibleSection=withLock.split('@objc private func danperAuthWindowVisible')[1].split('@objc private func danperAuthWillResign')[0];
 assert.ok(visibleSection.includes('if danperAuthUnlocked'),'newly visible window must not lock an unlocked session');

 assert.ok(withLock.includes('viewWithTag(danperNativeLockTag)?.removeFromSuperview()'),'success unlocks');
 assert.ok(withLock.includes('Autenticación cancelada'),'cancel stays locked with retry');
 const workflow=fs.readFileSync('.github/workflows/ios-ipa.yml','utf8');
 assert.ok(workflow.includes('node scripts/install-ios-access-lock.mjs'),'CI must install native app lock before xcode');
 const build=fs.readFileSync('scripts/build-ios-ipa.sh','utf8');
 assert.ok(build.includes('NSFaceIDUsageDescription'),'Face ID usage reason mandatory');
 const verifier=fs.readFileSync('scripts/verify-ios-ipa.mjs','utf8');
 assert.ok(verifier.includes('NSFaceIDUsageDescription'),'shipped IPA must be inspected for Face ID key');
 console.log('PASS: native Face ID lifecycle inactive-success, no prompt loop, real background re-lock, stale callback rejection, passcode fallback and Swift injection.');
}
run().catch(e=>{console.error(e);process.exitCode=1});
