import XCTest
import LocalAuthentication

/// A failed simulator enrollment is an environment failure, never an auth bypass.
final class N2BiometricEnvironmentTests:XCTestCase {
    func testIsolatedSimulatorActuallyOffersFaceID() {
        #if targetEnvironment(simulator)
        let context=LAContext()
        var error:NSError?
        XCTAssertTrue(context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,error:&error),String(describing:error))
        XCTAssertEqual(context.biometryType,.faceID)
        #else
        XCTFail("Synthetic validation requires the dedicated iPhone Simulator")
        #endif
    }
}
