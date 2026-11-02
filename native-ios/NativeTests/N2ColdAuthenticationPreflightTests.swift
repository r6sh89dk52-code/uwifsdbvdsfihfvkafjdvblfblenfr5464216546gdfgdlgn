import Foundation
import XCTest
import LocalAuthentication

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
    func testRealDeviceOwnerPolicyCanBeCancelledAfterColdLaunch() async {
        #if targetEnvironment(simulator)
        for attempt in 1...2 {
            let context=LAContext()
            let result=Outcome(),finished=expectation(description:"Real policy cancellation")
            // Neither synchronous LA IPC nor an XCTest wait may occupy the
            // host's main thread: CoreAuthUI needs that thread to present.
            // Schedule cancellation independently BEFORE making the request.
            let cancel=DispatchWorkItem {
                print("SYNTHETIC_POLICY_INVALIDATE",attempt)
                context.invalidate()
            }
            DispatchQueue.global(qos:.userInitiated).asyncAfter(deadline:.now()+12,execute:cancel)
            DispatchQueue.global(qos:.userInitiated).async {
                print("SYNTHETIC_POLICY_AVAILABILITY",attempt)
                var availabilityError:NSError?
                guard context.canEvaluatePolicy(.deviceOwnerAuthentication,error:&availabilityError) else {
                    XCTFail("Simulator device-owner policy unavailable: "+String(describing:availabilityError))
                    result.record(false,availabilityError);finished.fulfill();return
                }
                print("SYNTHETIC_POLICY_EVALUATE",attempt)
                context.evaluatePolicy(.deviceOwnerAuthentication,
                    localizedReason:"Comprobación sintética de cancelación; no autoriza acceso clínico") { authenticated,error in
                    result.record(authenticated,error)
                    let issue=error as NSError?
                    print("SYNTHETIC_POLICY_CALLBACK",attempt,issue?.domain ?? "none",issue?.code ?? 0)
                    finished.fulfill()
                }
            }
            await fulfillment(of:[finished],timeout:18)
            cancel.cancel()
            let outcome=result.read()
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
