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
    func testOnlyDemoNamedTemporaryExportsMayBeRemoved() {
        let uuid="5D5DEB70-E95D-4174-A588-93AF76CD17D9"
        XCTAssertTrue(N2SyntheticResetScope.canEraseDemoTempFolder(
            named:"danper-n2-demo-kardex-"+uuid))
        XCTAssertTrue(N2SyntheticResetScope.canEraseDemoTempFolder(
            named:"danper-n2-demo-indicator-"+uuid))
        XCTAssertTrue(N2SyntheticResetScope.canEraseDemoTempFolder(
            named:"danper-n2-demo-encrypted-share-"+uuid))
        for name in [
            "danper-n2-clinical-kardex-"+uuid,
            "danper-n2-clinical-indicator-"+uuid,
            "danper-n2-encrypted-share-"+uuid,
            "danper-n2-demo-kardex-../../CLINICAL",
            "danper-n2-demo-indicator-bad-id",
            "DANPER-N2-CLINICAL-VAULT"
        ] {
            XCTAssertFalse(N2SyntheticResetScope.canEraseDemoTempFolder(named:name),
                           "No borrar archivos ajenos: \(name)")
        }
    }
}
