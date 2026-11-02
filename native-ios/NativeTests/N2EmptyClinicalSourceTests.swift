import Foundation
import XCTest
@testable import DANPERNative

/// Read-only check on the harness's new empty Simulator, never a real phone.
final class N2EmptyClinicalSourceTests:XCTestCase {
    func testConfirmedEmptySourceInspectionDoesNotQueryKeychainOrCreateData() async throws {
        #if targetEnvironment(simulator)
        let vault=N2ProtectedClinicalIOSVault.shared
        guard await vault.hasStoredClinicalSource()==false else {
            XCTFail("Requires the isolated empty Simulator; never erase or replace an existing source")
            return
        }
        let before=await vault.diagnosticKeychainReadCount()
        let start=Date()
        let summary=try await vault.inspect()
        let elapsed=Date().timeIntervalSince(start)*1000
        let after=await vault.diagnosticKeychainReadCount()
        let evidence=await vault.hasStoredClinicalSource()
        XCTAssertNil(summary)
        XCTAssertEqual(after,before,"Confirmed absence must not wait for a Keychain lookup")
        XCTAssertFalse(evidence,"Inspection must never create a clinical source")
        print("SYNTHETIC_EMPTY_SOURCE_INSPECT_MS",elapsed,"KEYCHAIN_READS",after-before)
        #else
        XCTFail("Run only in the harness's empty synthetic Simulator")
        #endif
    }
}
