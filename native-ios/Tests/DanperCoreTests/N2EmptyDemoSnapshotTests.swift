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
        // A genuinely empty demo must NOT become an admissible Build 222 backup.
        XCTAssertThrowsError(try N1BackupAdmission.preview(data:data))
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(data))
        XCTAssertTrue(N2EmptyDemoSnapshot.matches(data))
        let audit=try N1eLegacyClinicalAudit.inspect(data,allowEmptySynthetic:true)
        XCTAssertEqual(audit.workers,0)
        XCTAssertEqual(audit.attentions,0)
        XCTAssertEqual(audit.physicalMovements,0)
    }
    func testWhitelistingRejectsAnythingOtherThanTheExactBlankSource()throws {
        let original=try N2EmptyDemoSnapshot.make()
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:original) as? [String:Any])
        root["workers"]=[["dni":"00000001","name":"Dato agregado"]]
        let modified=try JSONSerialization.data(withJSONObject:root)
        XCTAssertFalse(N2EmptyDemoSnapshot.matches(modified))
        root["workers"]=[[String:String]]()
        root["unrecognizedClinicalField"]="must-not-skip-audit"
        let extra=try JSONSerialization.data(withJSONObject:root)
        XCTAssertFalse(N2EmptyDemoSnapshot.matches(extra))
    }
    func testBlankRosterCanReceiveItsFirstManualWorker()throws {
        let blank=try N2EmptyDemoSnapshot.make()
        let emptyIndex=try N2NativeSnapshotReader.read(blank)
        XCTAssertTrue(emptyIndex.roster.isEmpty)
        XCTAssertTrue(emptyIndex.visits.isEmpty)
        let employee=try JSONSerialization.data(withJSONObject:[
            "dni":"00000006",
            "name":"Trabajador De Ejemplo"
        ])
        let next=try N2SnapshotEditor.addWorker(
            snapshot:blank,worker:employee,at:1_791_000_000_000)
        let after=try N2NativeSnapshotReader.read(next)
        XCTAssertEqual(after.roster.count,1)
        XCTAssertEqual(after.roster.first?.dni,"00000006")
        XCTAssertTrue(after.visits.isEmpty)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(next).workers,1)
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
