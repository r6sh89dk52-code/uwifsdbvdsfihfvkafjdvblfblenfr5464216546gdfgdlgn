import XCTest
import Foundation
@testable import DanperCore

final class N2WorkerRegistrationGateTests:XCTestCase {
    private func issues(dni:String="00000006",
                        name:String="Mariana Torres Salazar",
                        birthdayKnown:Bool=false,
                        birthdayValid:Bool=false,
                        age:String="",known:Set<String>=[],
                        available:Bool=true)->[String] {
        N2WorkerRegistrationGate.issues(
            dni:dni,names:name,site:"PLVENTUROSA",
            isBirthDateKnown:birthdayKnown,birthDateValid:birthdayValid,
            manuallyEnteredAge:age,knownDNI:known,storeAvailable:available)
    }
    func testEligibleManualWorkerHasNoSilentBlocker() {
        XCTAssertTrue(issues(age:"36").isEmpty)
        XCTAssertTrue(issues(age:"").isEmpty)
        XCTAssertTrue(issues(birthdayKnown:true,birthdayValid:true).isEmpty)
    }
    func testEveryBlockingConditionExplainsItself() {
        XCTAssertTrue(issues(dni:"").contains(where:{$0.contains("DNI")}))
        XCTAssertTrue(issues(dni:"12345678").isEmpty)
        XCTAssertTrue(issues(dni:"87654321").isEmpty)
        XCTAssertTrue(issues(dni:"0000001").contains(where:{$0.contains("ocho")}))
        XCTAssertTrue(issues(name:"Ana").contains(where:{$0.contains("nombres")}))
        XCTAssertTrue(issues(age:"121").contains(where:{$0.contains("120")}))
        XCTAssertTrue(issues(birthdayKnown:true,birthdayValid:false)
                        .contains(where:{$0.contains("fecha")}))
        XCTAssertTrue(issues(known:["00000006"]).contains(where:{$0.contains("existe")}))
        XCTAssertTrue(issues(available:false).contains(where:{$0.contains("local")}))
    }
    func testCanRetryStaleRegistrationWithoutChangingPastClinicalData() throws {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        let original=try Data(contentsOf:URL(fileURLWithPath:dir)
            .appendingPathComponent("n1e-clinical-stock.json"))
        let user:[String:String]=[
            "dni":"00000006","name":"Mariana Torres Salazar",
            "area":"Empaque","labor":"Empacador",
            "site":"PLVENTUROSA","sex":"F","age":"36",
            "birthDate":"","ubigeo":""
        ]
        let bytes=try JSONSerialization.data(withJSONObject:user)
        let newSnapshot=try N2SnapshotEditor.addWorker(snapshot:original,worker:bytes,
                                                       at:1792278000000)
        let before=try XCTUnwrap(JSONSerialization.jsonObject(with:original) as? [String:Any])
        let after=try XCTUnwrap(JSONSerialization.jsonObject(with:newSnapshot) as? [String:Any])
        for name in ["attentions","stockLots","stockMovements","allergies","ambulatoryReconciliation"] {
            let baseline=try JSONSerialization.data(withJSONObject:before[name]!,
                                                        options:[.sortedKeys])
            let result=try JSONSerialization.data(withJSONObject:after[name]!,
                                                      options:[.sortedKeys])
            XCTAssertEqual(baseline,result,"Unrelated records changed: \(name)")
        }
        let roster=try XCTUnwrap(after["workers"] as? [[String:Any]])
        XCTAssertEqual(roster.last?["dni"] as? String,"00000006")
    }
}
