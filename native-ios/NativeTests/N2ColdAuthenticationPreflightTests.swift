import Foundation
import XCTest
import LocalAuthentication

/// Simulator preparation only. No sensor match, fake success, private UI
/// launch or production authentication change is permitted here.
final class N2ColdAuthenticationPreflightTests:XCTestCase {
    private final class Outcome:@unchecked Sendable {
        private let lock=NSLock()
        private var value=(authenticated:false,cancelled:false)
        func record(_ authenticated:Bool,_ error:Error?) {
            lock.lock();defer{lock.unlock()}
            value=(authenticated,(error as? LAError)?.code == .appCancel)
        }
        func read()->(authenticated:Bool,cancelled:Bool) {
            lock.lock();defer{lock.unlock()};return value
        }
    }
    func testRealDeviceOwnerPolicyCanBeCancelledAfterColdLaunch() {
        #if targetEnvironment(simulator)
        for attempt in 1...2 {
            let context=LAContext()
            var availabilityError:NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthentication,error:&availabilityError) else {
                XCTFail("Simulator device-owner policy unavailable: "+String(describing:availabilityError));return
            }
            let result=Outcome(),finished=expectation(description:"Real policy cancellation")
            context.evaluatePolicy(.deviceOwnerAuthentication,
                localizedReason:"Comprobación sintética de cancelación; no autoriza acceso clínico") { authenticated,error in
                result.record(authenticated,error)
                let issue=error as NSError?
                print("SYNTHETIC_POLICY_CALLBACK",attempt,issue?.domain ?? "none",issue?.code ?? 0)
                finished.fulfill()
            }
            let cancel=DispatchWorkItem{context.invalidate()}
            DispatchQueue.main.asyncAfter(deadline:.now()+12,execute:cancel)
            let completion=XCTWaiter.wait(for:[finished],timeout:18)
            cancel.cancel();context.invalidate()
            XCTAssertEqual(completion,.completed,"The real policy must complete within its bounded preflight")
            guard completion == .completed else{return}
            let outcome=result.read()
            XCTAssertFalse(outcome.authenticated,"Preflight must never authenticate the synthetic user")
            if outcome.cancelled {return}
            // A first cold launch can hit the OS's five-second UI watchdog.
            // Preserve that callback and allow one fresh, genuine request.
            Thread.sleep(forTimeInterval:2)
        }
        XCTFail("No genuine app-cancel callback after two bounded policy requests")
        #else
        XCTFail("Synthetic preparation requires an isolated Simulator; never run on a clinical iPhone")
        #endif
    }
}
