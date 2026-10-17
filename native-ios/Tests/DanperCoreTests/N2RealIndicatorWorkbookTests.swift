import Foundation
import XCTest
@testable import DanperCore

final class N2RealIndicatorWorkbookTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:dir).appendingPathComponent(name))
    }
    func testPlantSiteUsesSameOfficialTenSheetTemplateAfterReview() throws {
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-reviewed-expected.json")) as? [String:Any])
        let events:[[String:Any]]=[
          ["id":"n2-pl-open","kind":"opening","subdivision":"PLVENTUROSA",
           "code":"16000182","date":"2026-10-09","at":1791504000000,
           "quantity":22,"reason":"Conteo verificado",
           "document":"","expires":"","periodEnd":"","voidOf":""],
          ["id":"n2-pl-count","kind":"count","subdivision":"PLVENTUROSA",
           "code":"16000182","date":"2026-11-08","at":1794182400000,
           "quantity":10,"reason":"Conteo verificado",
           "document":"","expires":"","periodEnd":"","voidOf":""],
          ["id":"n2-pl-review","kind":"review","subdivision":"PLVENTUROSA",
           "code":"","date":"2026-10-09","at":1794182400100,
           "quantity":0,"reason":"Cierre revisado",
           "document":"","expires":"","periodEnd":"2026-11-08","voidOf":""]
        ]
        snapshot["ambulatoryReconciliation"]=events
        let raw=try JSONSerialization.data(withJSONObject:snapshot)
        let catalog=try JSONSerialization.data(withJSONObject:proof["catalog"]!)
        let x=try N2VerifiedIndicatorWorkbook.export(
            snapshot:raw,products:catalog,
            mappings:fixture("n2-reviewed-approved.json"),
            template:fixture("n1s-indicator-template-store.zip"),
            start:"2026-10-09",end:"2026-11-08",
            subdivision:"PLVENTUROSA",
            selectedVisitIDs:Set(["planta-open","planta-tablet-carton"]))
        XCTAssertEqual(x.visits,2)
        XCTAssertEqual(x.rows,2)
        XCTAssertEqual(x.missingOpening,431)
        XCTAssertEqual(x.missingClosingCount,431)
    }
    func testReviewedPeriodVoidedRequiresNewClosingReview()throws {
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-voided-expected.json")) as? [String:Any])
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        snapshot["ambulatoryReconciliation"]=proof["events"]!
        let source=try JSONSerialization.data(withJSONObject:snapshot)
        let products=try JSONSerialization.data(withJSONObject:proof["catalog"]!)
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:source,products:products,
            mappings:fixture("n2-reviewed-approved.json"),
            template:fixture("n1s-indicator-template-store.zip"),
            start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",
            selectedVisitIDs:Set(["fundo-unit","fundo-reuse"]))) {
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,
                           .unreviewedPeriod)
        }
    }
    func testTenSheetWriterRejectsUnreviewedAndPendingPhysical()throws {
        let expected=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-reviewed-expected.json")) as? [String:Any])
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        let catalog=try JSONSerialization.data(withJSONObject:expected["catalog"]!)
        let template=try fixture("n1s-indicator-template-store.zip")
        let mappings=try fixture("n2-reviewed-approved.json")
        let ids=Set(try XCTUnwrap(expected["selectedVisitIDs"] as? [String]))
        let unreviewed=try JSONSerialization.data(withJSONObject:snapshot)
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:unreviewed,products:catalog,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",selectedVisitIDs:ids)) {
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,.unreviewedPeriod)
        }
        snapshot["ambulatoryReconciliation"]=expected["events"]!
        let active=try JSONSerialization.data(withJSONObject:snapshot)
        let result=try N2VerifiedIndicatorWorkbook.export(
            snapshot:active,products:catalog,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",selectedVisitIDs:ids)
        XCTAssertEqual(result.rows,2)
        XCTAssertEqual(result.visits,2)
        XCTAssertEqual(result.missingOpening,429)
        XCTAssertEqual(result.missingClosingCount,429)
        XCTAssertTrue(result.xlsx.starts(with:[0x50,0x4B,0x03,0x04]))
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:active,products:catalog,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",
            selectedVisitIDs:ids.union(["pending-stock"]))) {
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,.unverifiedDelivery)
        }
    }
}
