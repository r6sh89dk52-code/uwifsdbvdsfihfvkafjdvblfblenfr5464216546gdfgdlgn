import XCTest
import Foundation
@testable import DanperCore

final class N2WorkerBirthDateEntryTests:XCTestCase {
    func testAutomaticDateMaskAcceptsEightDigitsAndPastedSpacing() {
        XCTAssertEqual(N2WorkerBirthDateEntry.format("1"),"1")
        XCTAssertEqual(N2WorkerBirthDateEntry.format("18"),"18")
        XCTAssertEqual(N2WorkerBirthDateEntry.format("181"),"18/1")
        XCTAssertEqual(N2WorkerBirthDateEntry.format("1810"),"18/10")
        XCTAssertEqual(N2WorkerBirthDateEntry.format("18101999"),"18/10/1999")
        XCTAssertEqual(N2WorkerBirthDateEntry.format("18 10 1999"),"18/10/1999")
        XCTAssertEqual(N2WorkerBirthDateEntry.format("18/10/1999"),"18/10/1999")
        XCTAssertEqual(N2WorkerBirthDateEntry.format("181019991122"),"18/10/1999")
        XCTAssertEqual(N2WorkerBirthDateEntry.isoDate("18/10/1999"),"1999-10-18")
        XCTAssertNil(N2WorkerBirthDateEntry.isoDate("18/10/19"))
    }
    func testValidationOfRealDatesAndAge() {
        XCTAssertEqual(N2WorkerBirthDateEntry.validatedISO("18101999",on:"2026-10-18"),"1999-10-18")
        XCTAssertEqual(N2WorkerAge.years(birthDate:"1999-10-18",on:"2026-10-18"),27)
        XCTAssertEqual(N2WorkerBirthDateEntry.validatedISO("29/02/2004",on:"2026-10-18"),"2004-02-29")
        XCTAssertNil(N2WorkerBirthDateEntry.validatedISO("29022023",on:"2026-10-18"))
        XCTAssertNil(N2WorkerBirthDateEntry.validatedISO("32121999",on:"2026-10-18"))
        XCTAssertNil(N2WorkerBirthDateEntry.validatedISO("18102027",on:"2026-10-18"))
        XCTAssertNil(N2WorkerBirthDateEntry.validatedISO("00001999",on:"2026-10-18"))
    }
    func testManualAgeOptionalButLimitedAndNeverFabricatesBirthDate() {
        XCTAssertNil(N2WorkerBirthDateEntry.manualAge(""))
        XCTAssertEqual(N2WorkerBirthDateEntry.manualAge("0"),0)
        XCTAssertEqual(N2WorkerBirthDateEntry.manualAge("36"),36)
        XCTAssertEqual(N2WorkerBirthDateEntry.manualAge("120"),120)
        XCTAssertNil(N2WorkerBirthDateEntry.manualAge("121"))
        XCTAssertNil(N2WorkerBirthDateEntry.manualAge("-1"))
        XCTAssertNil(N2WorkerBirthDateEntry.manualAge("abc"))
        XCTAssertNil(N2WorkerBirthDateEntry.manualAge("36.5"))
        XCTAssertNil(N2WorkerBirthDateEntry.manualAge("0036"))
    }
    func testManualWorkerAgeIsSavedWithoutBirthDate() throws {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        let input=try Data(contentsOf:URL(fileURLWithPath:dir)
            .appendingPathComponent("n1e-clinical-stock.json"))
        let worker:[String:String]=[
            "dni":"00000009","name":"Mariana Torres Salazar",
            "area":"Operaciones Fresco","labor":"Empacador",
            "site":"PLVENTUROSA","sex":"F","age":"36",
            "birthDate":"","ubigeo":""
        ]
        let json=try JSONSerialization.data(withJSONObject:worker)
        let result=try N2SnapshotEditor.addWorker(snapshot:input,worker:json,
                                                   at:1792278000000)
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:result) as? [String:Any])
        let people=try XCTUnwrap(root["workers"] as? [[String:Any]])
        let stored=try XCTUnwrap(people.first(where:{$0["dni"] as? String=="00000009"}))
        XCTAssertEqual(stored["age"] as? String,"36")
        XCTAssertEqual(stored["birthDate"] as? String,"")
        var invalid=worker
        invalid["age"]="125"
        XCTAssertThrowsError(try N2SnapshotEditor.addWorker(snapshot:input,
            worker:JSONSerialization.data(withJSONObject:invalid),at:1792278000000)) {
            XCTAssertEqual($0 as? N2SnapshotEditError,.invalidWorker)
        }
    }
}
