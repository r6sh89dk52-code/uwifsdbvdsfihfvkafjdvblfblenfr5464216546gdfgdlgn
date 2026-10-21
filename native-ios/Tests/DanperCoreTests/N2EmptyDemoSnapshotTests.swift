import Foundation
import XCTest
@testable import DanperCore

final class N2EmptyDemoSnapshotTests:XCTestCase {
    func testFreshDemoHasNoWorkersVisitsOrStock()throws {
        let data=try N2EmptyDemoSnapshot.make()
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        for key in ["workers","attentions","stockLots","stockMovements",
                    "catalogMappings","deliveryIncidents","ambulatoryReconciliation"] {
            let records=try XCTUnwrap(root[key] as? [Any])
            XCTAssertTrue(records.isEmpty,key+" debe iniciar vacío")
        }
        XCTAssertTrue((root["allergies"] as? [String:Any])?.isEmpty==true)
        XCTAssertEqual(root["notifications"] as? Bool,false)
        let audit=try N1eLegacyClinicalAudit.inspect(data)
        XCTAssertEqual(audit.workers,0)
        XCTAssertEqual(audit.attentions,0)
        XCTAssertEqual(audit.physicalMovements,0)
    }
    func testEmptyDemoDeterministicButDoesNotContainOldSample()throws {
        let first=try N2EmptyDemoSnapshot.make()
        let second=try N2EmptyDemoSnapshot.make()
        XCTAssertEqual(first,second)
        let source=try XCTUnwrap(String(data:first,encoding:.utf8))
        XCTAssertFalse(source.contains("00000001"))
        XCTAssertFalse(source.contains("Mariana Torres"))
        XCTAssertFalse(source.contains("stockLots\":[{"))
    }
}
