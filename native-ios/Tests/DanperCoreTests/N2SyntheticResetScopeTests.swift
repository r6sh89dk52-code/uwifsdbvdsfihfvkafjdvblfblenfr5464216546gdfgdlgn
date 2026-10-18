import Foundation
import XCTest
@testable import DanperCore

final class N2SyntheticResetScopeTests:XCTestCase {
    func testOnlyExactFictitiousVaultMayBeErased() {
        let support=URL(fileURLWithPath:"/Users/test/Library/Application Support",
                        isDirectory:true)
        let demo=support.appendingPathComponent("DANPER-N2-SYNTHETIC-VAULT",
                                                 isDirectory:true)
        XCTAssertTrue(N2SyntheticResetScope.canErase(support:support,target:demo))
        let denied=[
            support,
            support.appendingPathComponent("DANPER-N2-CLINICAL-VAULT"),
            support.appendingPathComponent("DANPER-N2-SYNTHETIC-VAULT-copy"),
            support.appendingPathComponent("N1mRealClinicalStagingVault"),
            support.deletingLastPathComponent(),
            URL(fileURLWithPath:"/tmp/DANPER-N2-SYNTHETIC-VAULT")
        ]
        for path in denied {
            XCTAssertFalse(N2SyntheticResetScope.canErase(support:support,target:path),
                           "La limpieza no debe acceder a \(path.path)")
        }
        XCTAssertEqual(N2SyntheticResetScope.confirmation,"BORRAR PRUEBAS")
    }
    func testSimilarNamesAndOtherAppSupportNeverPass() {
        let a=URL(fileURLWithPath:"/tmp/appOne",isDirectory:true)
        let b=URL(fileURLWithPath:"/tmp/appTwo",isDirectory:true)
        let aDemo=a.appendingPathComponent(N2SyntheticResetScope.directoryName)
        let bDemo=b.appendingPathComponent(N2SyntheticResetScope.directoryName)
        XCTAssertTrue(N2SyntheticResetScope.canErase(support:a,target:aDemo))
        XCTAssertFalse(N2SyntheticResetScope.canErase(support:a,target:bDemo))
    }
}
