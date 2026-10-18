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
