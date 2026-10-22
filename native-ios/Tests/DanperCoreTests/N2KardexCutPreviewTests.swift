import Foundation
import XCTest
@testable import DanperCore

final class N2KardexCutPreviewTests:XCTestCase {
    func testCurrentFivePlusThreeUsedReturnsEightAtOctoberNinth()throws {
        let result=try N2KardexCutPreview.calculate(
            asOf:"2026-10-22",measured:5,verifiedUsed:3,laterReceipts:0)
        XCTAssertEqual(result.period.start,"2026-10-09")
        XCTAssertEqual(result.period.end,"2026-11-08")
        XCTAssertEqual(result.estimatedOpening,8)
        XCTAssertTrue(result.requiresOperatorReconciliation)
    }
    func testReceiptsReduceOpeningInsteadOfDoubleCounting()throws {
        let preview=try N2KardexCutPreview.calculate(
            asOf:"2026-10-22",measured:5,verifiedUsed:3,laterReceipts:2)
        XCTAssertEqual(preview.estimatedOpening,6)
    }
    func testSignedPhysicalAdjustmentsAreNotInvented()throws {
        let preview=try N2KardexCutPreview.calculate(
            asOf:"2026-10-22",measured:5,verifiedUsed:3,
            laterReceipts:0,signedAdjustments:-1,pendingHistory:true)
        XCTAssertEqual(preview.estimatedOpening,9)
        XCTAssertTrue(preview.pendingHistory)
    }
    func testMonthlyNinthBoundary()throws {
        XCTAssertEqual(try N2KardexCutPreview.period(for:"2026-11-08").start,
                       "2026-10-09")
        XCTAssertEqual(try N2KardexCutPreview.period(for:"2026-11-09").start,
                       "2026-11-09")
        XCTAssertEqual(try N2KardexCutPreview.period(for:"2027-01-05").start,
                       "2026-12-09")
        XCTAssertEqual(try N2KardexCutPreview.period(for:"2027-01-05").end,
                       "2027-01-08")
    }
    func testRejectsImpossibleOrUnaccountedOpening()throws {
        XCTAssertThrowsError(try N2KardexCutPreview.period(for:"2026-02-30"))
        XCTAssertThrowsError(try N2KardexCutPreview.calculate(
            asOf:"2026-10-22",measured:2,verifiedUsed:1,laterReceipts:5))
        XCTAssertThrowsError(try N2KardexCutPreview.calculate(
            asOf:"2026-10-22",measured:.nan,verifiedUsed:2,laterReceipts:0))
    }
}
