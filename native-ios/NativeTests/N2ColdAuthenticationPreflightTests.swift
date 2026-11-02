import Foundation
import XCTest
import LocalAuthentication
import UIKit

/// Simulator preparation only. No sensor match, fake success, private UI
/// launch or production authentication change is permitted here.
final class N2ColdAuthenticationPreflightTests:XCTestCase {
    private final class Outcome:@unchecked Sendable {
        private let lock=NSLock()
        private var value=(received:false,authenticated:false,cancelled:false)
        func record(_ authenticated:Bool,_ error:Error?) {
            lock.lock();defer{lock.unlock()}
            value=(true,authenticated,(error as? LAError)?.code == .appCancel)
        }
        func read()->(received:Bool,authenticated:Bool,cancelled:Bool) {
            lock.lock();defer{lock.unlock()};return value
        }
    }
    @MainActor
    func testRealDeviceOwnerPolicyCanBeCancelledAfterColdLaunch() async {
        #if targetEnvironment(simulator)
        guard let scene=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene})
            .first(where:{$0.activationState == .foregroundActive}) else {
            XCTFail("The isolated native test host needs a foreground scene");return
        }
        // Snapshot cases install temporary windows. Give this interactive test
        // its own visible scene/window and restore the previous key window.
        let previous=scene.windows.first(where:{$0.isKeyWindow})
        let window=UIWindow(windowScene:scene)
        window.rootViewController=UIViewController()
        window.makeKeyAndVisible()
        defer{window.isHidden=true;previous?.makeKey()}
        await Task.yield()
        XCTAssertTrue(window.isKeyWindow)
        XCTAssertEqual(UIApplication.shared.applicationState,.active)
        for attempt in 1...2 {
            let context=LAContext()
            let result=Outcome(),finished=expectation(description:"Real policy cancellation")
            print("SYNTHETIC_POLICY_AVAILABILITY",attempt,Thread.isMainThread)
            var availabilityError:NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication,error:&availabilityError) else {
                XCTFail("Simulator device-owner policy unavailable: "+String(describing:availabilityError));return
            }
            // Cancellation is independent of the UI executor. The test awaits
            // asynchronously; it must never block the host's main run loop.
            let cancel=DispatchWorkItem {
                print("SYNTHETIC_POLICY_INVALIDATE",attempt)
                context.invalidate()
                print("SYNTHETIC_POLICY_INVALIDATE_RETURNED",attempt)
            }
            DispatchQueue.global(qos:.userInitiated).asyncAfter(deadline:.now()+12,execute:cancel)
            // Exercise the same async API/UI executor as the app, rather than
            // initiating an interactive request on an unrelated global queue.
            let request=Task { @MainActor in
                print("SYNTHETIC_POLICY_EVALUATE",attempt,Thread.isMainThread)
                do {
                    let authenticated=try await context.evaluatePolicy(.deviceOwnerAuthentication,
                        localizedReason:"Comprobación sintética de cancelación; no autoriza acceso clínico")
                    result.record(authenticated,nil)
                    print("SYNTHETIC_POLICY_CALLBACK",attempt,"none",0)
                } catch {
                    result.record(false,error)
                    let issue=error as NSError
                    print("SYNTHETIC_POLICY_CALLBACK",attempt,issue.domain,issue.code)
                }
                finished.fulfill()
            }
            await fulfillment(of:[finished],timeout:18)
            cancel.cancel();request.cancel()
            let outcome=result.read()
            withExtendedLifetime(context){}
            guard outcome.received else{return} // fulfillment already failed
            XCTAssertFalse(outcome.authenticated,"Preflight must never authenticate the synthetic user")
            if outcome.cancelled {return}
            // A first cold launch can hit the OS's five-second UI watchdog.
            // Preserve that callback and allow one fresh, genuine request.
            try? await Task.sleep(nanoseconds:2_000_000_000)
        }
        XCTFail("No genuine app-cancel callback after two bounded policy requests")
        #else
        XCTFail("Synthetic preparation requires an isolated Simulator; never run on a clinical iPhone")
        #endif
    }
}
