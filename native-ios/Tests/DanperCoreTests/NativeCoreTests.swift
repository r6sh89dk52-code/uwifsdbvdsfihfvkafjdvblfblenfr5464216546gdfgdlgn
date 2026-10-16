import XCTest
import Foundation
@testable import DanperCore

final class NativeCoreTests: XCTestCase {
    private func lot(_ id: String, _ exp: String, _ units: Double, code: String = "E-22") -> NativeStockLot {
        NativeStockLot(id: id, code: code, name: "SINTÉTICO", expires: exp,
                       catalogUnit: "UND", container: "unidad", unitsPerContainer: 1,
                       sealedContainers: 0, looseUnits: units, openedRemaining: 0)
    }

    func testFEFOAcrossLotsOneClinicalIssue() {
        let plan = FEFOPreview.plan(lots: [lot("later","2027-01-01",7),
                                           lot("first","2026-11-01",2)],
                                    kardexCode:"E-22",clinicalUnit:"UND",
                                    physicalQuantity:5,atLocalDate:"2026-10-16")
        XCTAssertTrue(plan.isReady)
        XCTAssertEqual(plan.issues.map(\.lotID), ["first","later"])
        XCTAssertEqual(plan.issues.map(\.physicalAmount), [2,3])
        XCTAssertEqual(plan.totalR, 5)
    }

    func testExpiredLotExcluded() {
        let plan = FEFOPreview.plan(lots:[lot("expired","2026-10-15",7),
                                          lot("valid","2027-01-01",2)],
                                    kardexCode:"E-22",clinicalUnit:"UND",
                                    physicalQuantity:1,atLocalDate:"2026-10-16")
        XCTAssertEqual(plan.issues.map(\.lotID), ["valid"])
    }

    func testFractionalUNDIsSkipped() {
        let plan = FEFOPreview.plan(lots:[lot("earlier","2026-10-20",0.5),
                                          lot("whole","2027-01-01",3)],
                                    kardexCode:"E-22",clinicalUnit:"UND",
                                    physicalQuantity:2,atLocalDate:"2026-10-16")
        XCTAssertTrue(plan.isReady)
        XCTAssertEqual(plan.issues.map(\.lotID), ["whole"])
        XCTAssertEqual(plan.totalR,2)
    }

    func testBoxOpenAndReuseAreOneAndZero() {
        let first = NativeStockLot(id:"a",code:"E-57",name:"CAJA",
             expires:"2027-01-01",catalogUnit:"CJA",container:"caja",
             unitsPerContainer:100,sealedContainers:1,looseUnits:0,openedRemaining:0)
        let opened = NativeStockLot(id:"a",code:"E-57",name:"CAJA",
             expires:"2027-01-01",catalogUnit:"CJA",container:"caja",
             unitsPerContainer:100,sealedContainers:0,looseUnits:0,openedRemaining:99)
        XCTAssertEqual(FEFOPreview.plan(lots:[first],kardexCode:"E-57",
            clinicalUnit:"CJA",physicalQuantity:1,atLocalDate:"2026-10-16").totalR,1)
        XCTAssertEqual(FEFOPreview.plan(lots:[opened],kardexCode:"E-57",
            clinicalUnit:"CJA",physicalQuantity:1,atLocalDate:"2026-10-16").totalR,0)
    }

    func testUnknownQuantityDoesNotInventMovement() {
        let p = FEFOPreview.plan(lots:[lot("a","2027-01-01",2)],
                     kardexCode:"E-22",clinicalUnit:"UND",
                     physicalQuantity:nil,atLocalDate:"2026-10-16")
        XCTAssertFalse(p.isReady)
        XCTAssertTrue(p.issues.isEmpty)
    }

    func testClinicalHistoryAndPhysicalMovementsRemainDistinct() throws {
        let data = """
          {"workers":[{"dni":"00000001"}],
           "attentions":[{"id":"A","status":"saved",
            "items":[{"id":"one","quantity":2},{"id":"two","quantity":1}]}],
           "allergies":{},"stockLots":[],"stockMovements":[]}
        """.data(using:.utf8)!
        let count = try LegacySnapshotReader.inspect(data)
        XCTAssertEqual(count.attentions,1)
        XCTAssertEqual(count.unmappedAttentionConsumptions,2)
        XCTAssertEqual(count.stockMovements,0)
    }

    func testMalformedSnapshotRejected() {
        XCTAssertThrowsError(try LegacySnapshotReader.inspect(Data("{}".utf8)))
    }
}
