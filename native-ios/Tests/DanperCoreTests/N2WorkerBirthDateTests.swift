import XCTest
import Foundation
@testable import DanperCore

final class N2WorkerBirthDateTests:XCTestCase {
    func testAgeChangesAtBirthdayAndOnClinicalDate() {
        XCTAssertEqual(N2WorkerAge.years(birthDate:"2000-10-19",on:"2026-10-18"),25)
        XCTAssertEqual(N2WorkerAge.years(birthDate:"2000-10-19",on:"2026-10-19"),26)
        XCTAssertEqual(N2WorkerAge.years(birthDate:"2000-10-19",on:"2027-10-19"),27)
    }
    func testInvalidOrFutureBirthdatesNeverInventAge() {
        XCTAssertNil(N2WorkerAge.years(birthDate:"2027-01-01",on:"2026-10-18"))
        XCTAssertNil(N2WorkerAge.years(birthDate:"2026-02-30",on:"2026-10-18"))
        XCTAssertNil(N2WorkerAge.years(birthDate:"1899-01-01",on:"2026-10-18"))
        XCTAssertNil(N2WorkerAge.years(birthDate:"19/10/2000",on:"2026-10-18"))
        XCTAssertEqual(N2WorkerAge.years(birthDate:"2004-02-29",on:"2026-02-28"),21)
        XCTAssertEqual(N2WorkerAge.years(birthDate:"2004-02-29",on:"2026-03-01"),22)
    }
    func testFreeTextAreaAndBirthdayPreserveInventoryAndExportableWorker()throws {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        let input=try Data(contentsOf:URL(fileURLWithPath:dir)
            .appendingPathComponent("n1e-clinical-stock.json"))
        let worker:[String:String]=[
            "dni":"00000009","name":"Mariana Torres Salazar",
            "area":"Área creada por el usuario","labor":"Auxiliar",
            "site":"LA VENTUROSA","birthDate":"2000-10-19",
            "age":"25","sex":"","ubigeo":""
        ]
        let json=try JSONSerialization.data(withJSONObject:worker)
        let result=try N2SnapshotEditor.addWorker(snapshot:input,worker:json,
                                                    at:1792278000000)
        let origin=try XCTUnwrap(JSONSerialization.jsonObject(with:input) as? [String:Any])
        let updated=try XCTUnwrap(JSONSerialization.jsonObject(with:result) as? [String:Any])
        let workers=try XCTUnwrap(updated["workers"] as? [[String:Any]])
        XCTAssertEqual(workers.count,6)
        XCTAssertEqual(workers.last?["name"] as? String,"Mariana Torres Salazar")
        XCTAssertEqual(workers.last?["area"] as? String,"Área creada por el usuario")
        XCTAssertEqual(workers.last?["birthDate"] as? String,"2000-10-19")
        for name in ["attentions","stockMovements","stockLots","ambulatoryReconciliation"] {
            let a=try JSONSerialization.data(withJSONObject:origin[name]!)
            let b=try JSONSerialization.data(withJSONObject:updated[name]!)
            XCTAssertEqual(try JSONSerialization.jsonObject(with:a) as? NSArray,
                           try JSONSerialization.jsonObject(with:b) as? NSArray)
        }
    }
}
