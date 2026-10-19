import XCTest
import Foundation
@testable import DanperCore

final class N2WorkerCorrectionParityTests:XCTestCase {
    func testCorrectionKeepsDNIHistoryAndStockImmutable()throws {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        let source=try Data(contentsOf:URL(fileURLWithPath:dir)
            .appendingPathComponent("n1e-clinical-stock.json"))
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:source) as? [String:Any])
        let roster=try XCTUnwrap(root["workers"] as? [[String:Any]])
        var worker=try XCTUnwrap(roster.first)
        let dni=try XCTUnwrap(worker["dni"] as? String)
        worker["area"]="Servicio de Salud"
        worker["labor"]="Responsable del tópico"
        let corrected=try N2SnapshotEditor.correctWorker(
            snapshot:source,dni:dni,
            worker:JSONSerialization.data(withJSONObject:worker),
            at:1792350000000)
        let after=try XCTUnwrap(JSONSerialization.jsonObject(with:corrected) as? [String:Any])
        let people=try XCTUnwrap(after["workers"] as? [[String:Any]])
        XCTAssertEqual(people.first?["dni"] as? String,dni)
        XCTAssertEqual(people.first?["area"] as? String,"Servicio de Salud")
        XCTAssertEqual(people.count,roster.count)
        for key in ["attentions","stockLots","stockMovements",
                    "ambulatoryReconciliation","allergies","deliveryIncidents"] {
            let a=try JSONSerialization.data(withJSONObject:root[key]!,options:[.sortedKeys])
            let z=try JSONSerialization.data(withJSONObject:after[key]!,options:[.sortedKeys])
            XCTAssertEqual(a,z,"Una corrección de PERSONAL nunca altera: \(key)")
        }
        let audits=try XCTUnwrap(after["nativeWorkerCorrections"] as? [[String:Any]])
        XCTAssertEqual(audits.last?["dni"] as? String,dni)
        XCTAssertEqual(audits.last?["at"] as? Int64,1792350000000)
        let repeated=try N2SnapshotEditor.correctWorker(
            snapshot:corrected,dni:dni,
            worker:JSONSerialization.data(withJSONObject:worker),at:1792350001000)
        XCTAssertEqual(repeated,corrected,"No duplicar una corrección idéntica")
        var illegal=worker
        illegal["dni"]="12345678"
        XCTAssertThrowsError(try N2SnapshotEditor.correctWorker(snapshot:source,
             dni:dni,worker:JSONSerialization.data(withJSONObject:illegal),
             at:1792350000000))
    }
}
