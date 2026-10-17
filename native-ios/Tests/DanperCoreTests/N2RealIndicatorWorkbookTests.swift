import Foundation
import XCTest
@testable import DanperCore

final class N2RealIndicatorWorkbookTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:dir).appendingPathComponent(name))
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
