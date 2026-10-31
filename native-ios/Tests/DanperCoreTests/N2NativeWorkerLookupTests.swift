import XCTest
import Foundation
@testable import DanperCore

final class N2NativeWorkerLookupTests:XCTestCase {
    private var roster:[N2FormWorker] {
        [
            N2FormWorker(dni:"41728463",name:"Mariana Torres Salazar",
                         area:"Empaque",labor:"Empacador",sex:"F",
                         age:"27",ubigeo:"130101",site:"PLVENTUROSA"),
            N2FormWorker(dni:"00000001",name:"Luis Paredes Rojas",
                         area:"Producción Agrícola Palto",labor:"Operario",sex:"M",
                         age:"33",ubigeo:"",site:"LA VENTUROSA"),
            N2FormWorker(dni:"78945612",name:"Daniela Campos Vega",
                         area:"Operaciones Fresco",labor:"Auxiliar",sex:"F",
                         age:"29",ubigeo:"130102",site:"PLVENTUROSA")
        ]
    }
    func testDNIIsNumberPadCompatibleAndNotLimitedToArtificialZeroPrefix() {
        XCTAssertEqual(N2NativeWorkerLookup.numericDNI("41 728 463"),"41728463")
        XCTAssertEqual(N2NativeWorkerLookup.numericDNI("41728463abc99"),"41728463")
        XCTAssertEqual(N2NativeWorkerLookup.numericDNI(""),"")
        XCTAssertEqual(N2NativeWorkerLookup.exactDNI("41728463",in:roster)?.name,
                       "Mariana Torres Salazar")
        XCTAssertEqual(N2NativeWorkerLookup.exactDNI("00000001",in:roster)?.name,
                       "Luis Paredes Rojas")
        XCTAssertNil(N2NativeWorkerLookup.exactDNI("4172",in:roster))
        XCTAssertNil(N2NativeWorkerLookup.exactDNI("99999999",in:roster))
    }
    func testNameMatchingUsesShortInlineResultsAndWorksAcrossSites() {
        XCTAssertEqual(N2NativeWorkerLookup.nameMatches("mariana",in:roster).map(\.dni),
                       ["41728463"])
        XCTAssertEqual(N2NativeWorkerLookup.nameMatches("Campos",in:roster).map(\.dni),
                       ["78945612"])
        XCTAssertTrue(N2NativeWorkerLookup.nameMatches("m",in:roster).isEmpty)
        XCTAssertEqual(N2NativeWorkerLookup.nameMatches("a",in:roster,limit:5).count,0)
        XCTAssertEqual(N2NativeWorkerLookup.nameMatches("ar",in:roster,limit:1).count,1)
    }
    func testLargeRosterInlineLookupReturnsOnlyFiveAndFindsLateDNI() {
        let workers=(0..<9_648).map { index in
            N2FormWorker(dni:String(format:"%08d",index+1),
                         name:"Persona Ficticia \(index)",
                         area:"Área",labor:"Labor",sex:"F",
                         age:"30",ubigeo:"",site:"LA VENTUROSA")
        }
        XCTAssertEqual(workers.count,9_648)
        let first=N2NativeWorkerLookup.nameMatches("Persona",in:workers,limit:5)
        XCTAssertEqual(first.count,5)
        XCTAssertEqual(first.map(\.dni),["00000001","00000002","00000003","00000004","00000005"])
        XCTAssertEqual(N2NativeWorkerLookup.exactDNI("00009648",in:workers)?.dni,"00009648")
        XCTAssertEqual(N2NativeWorkerLookup.nameMatches("Ficticia 9647",in:workers,limit:5).map(\.dni),["00009648"])
        XCTAssertTrue(N2NativeWorkerLookup.nameMatches("",in:workers).isEmpty)
        XCTAssertTrue(N2NativeWorkerLookup.nameMatches("x",in:workers).isEmpty)
    }

    func testPersistenceOfOrdinaryDNIWithoutDemoPrefix() throws {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        let data=try Data(contentsOf:URL(fileURLWithPath:dir)
            .appendingPathComponent("n1e-clinical-stock.json"))
        let worker:[String:String]=[
            "dni":"41728463","name":"Mariana Torres Salazar",
            "area":"Empaque","labor":"Empacador",
            "site":"PLVENTUROSA","sex":"F","age":"27",
            "birthDate":"","ubigeo":"130101"
        ]
        let after=try N2SnapshotEditor.addWorker(
            snapshot:data,worker:JSONSerialization.data(withJSONObject:worker),
            at:1792278000000)
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:after) as? [String:Any])
        let roster=try XCTUnwrap(root["workers"] as? [[String:Any]])
        XCTAssertTrue(roster.contains(where:{$0["dni"] as? String=="41728463"}))
        XCTAssertThrowsError(try N2SnapshotEditor.addWorker(
            snapshot:after,worker:JSONSerialization.data(withJSONObject:worker),
            at:1792278000000))
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(after).physicalMovements,
                       try N1eLegacyClinicalAudit.inspect(data).physicalMovements)
    }

    func testGateAllowsOrdinaryEightDigitDNIAndRejectsDuplicates() {
        func messages(_ dni:String,known:Set<String>=[])->[String] {
            N2WorkerRegistrationGate.issues(dni:dni,names:"Mariana Torres Salazar",
                site:"PLVENTUROSA",isBirthDateKnown:false,birthDateValid:false,
                manuallyEnteredAge:"27",knownDNI:known,storeAvailable:true)
        }
        XCTAssertTrue(messages("41728463").isEmpty)
        XCTAssertTrue(messages("99999999").isEmpty)
        XCTAssertFalse(messages("41728463",known:["41728463"]).isEmpty)
        XCTAssertFalse(messages("4172").isEmpty)
    }
}
