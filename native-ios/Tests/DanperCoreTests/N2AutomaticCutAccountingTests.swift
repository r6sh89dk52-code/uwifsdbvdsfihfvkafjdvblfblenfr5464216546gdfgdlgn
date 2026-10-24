import Foundation
import XCTest
@testable import DanperCore

final class N2AutomaticCutAccountingTests:XCTestCase {
    private func source(_ name:String)throws->Data {
        let folder=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:folder,isDirectory:true)
            .appendingPathComponent(name))
    }
    func testSavedClinicalItemsCountExactlyOnceEvenWhenNoLotWasKnown()throws {
        let result=try N2AutomaticCutAccounting.calculate(
            snapshot:source("n1e-clinical-stock.json"),
            mappings:source("n2-reviewed-approved.json"),
            through:"2026-10-22")
        XCTAssertEqual(result.start,"2026-10-09")
        XCTAssertEqual(result.end,"2026-10-22")
        let tablets=try XCTUnwrap(result.rows.first{$0.code=="E-22"})
        // 5 + 12 confirmed via FEFO; 1000 saved clinically before stock
        // was available. They must appear only once, not be thrown away.
        XCTAssertEqual(tablets.clinicalUnits,1017)
        XCTAssertEqual(tablets.reportedUse,1017)
        XCTAssertEqual(tablets.unlinkedItems,1)
        XCTAssertEqual(tablets.usesByDay["2026-10-14"],1017)
        XCTAssertEqual(tablets.usesByDay["2026-10-15"] ?? 0,0)
        // There is one opened container (R=1) and one reuse (R=0).
        let packages=try XCTUnwrap(result.rows.first{$0.code=="E-57"})
        XCTAssertEqual(packages.clinicalUnits,3)
        XCTAssertEqual(packages.reportedUse,1)
        XCTAssertEqual(packages.unknownContainerOpenings,0)
    }
    func testCurrentStockIsNotDebitedAgainDuringReadOnlyReconstruction()throws {
        let input=try source("n1e-clinical-stock.json")
        _=try N2AutomaticCutAccounting.calculate(
            snapshot:input,mappings:source("n2-reviewed-approved.json"),
            through:"2026-10-22")
        let again=try N2AutomaticCutAccounting.calculate(
            snapshot:input,mappings:source("n2-reviewed-approved.json"),
            through:"2026-10-22")
        let tablets=try XCTUnwrap(again.rows.first{$0.code=="E-22"})
        XCTAssertEqual(tablets.reportedUse,1017)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(input).physicalMovements,
                       try N1eLegacyClinicalAudit.inspect(input).physicalMovements)
    }

    func testReconstructedNursingCutUsesRecordedBalanceAndClinicalUseOnce()throws {
        let snapshot=try source("n1e-clinical-stock.json")
        let mappings=try source("n2-reviewed-approved.json")
        let projection=try N2AutomaticCutAccounting.calculate(
            snapshot:snapshot,mappings:mappings,through:"2026-10-22")
        let nursing=try source("n2-nursing-parity.json")
        let manifest=try XCTUnwrap(JSONSerialization.jsonObject(with:nursing) as? [String:Any])
        let catalog=try JSONSerialization.data(withJSONObject:manifest["catalog"]!)
        let report=try N2NursingReportBuilder.reconstructedCut(
            snapshot:snapshot,catalog:catalog,mappings:mappings,
            start:"2026-10-09",end:"2026-10-22")
        XCTAssertEqual(report.rows.count,98)
        XCTAssertEqual(report.date,"2026-10-09")
        XCTAssertEqual(report.periodEnd,"2026-10-22")
        let tablets=try XCTUnwrap(report.rows.first{$0.code=="E-22"})
        let projected=try XCTUnwrap(projection.rows.first{$0.code=="E-22"})
        XCTAssertEqual(tablets.consumed,projected.reportedUse)
        XCTAssertEqual(tablets.initial,projected.opening ?? 0)
        XCTAssertEqual(tablets.closing,projected.currentCount ?? 0)
        XCTAssertEqual(tablets.total-tablets.consumed,tablets.closing,accuracy:0.001)
        let packaged=try XCTUnwrap(report.rows.first{$0.code=="E-57"})
        XCTAssertEqual(packaged.consumed,1) // One declared opening, subsequent reuse = 0.
        // Repeating a read-only reconstruction must never edit source events.
        let again=try N2NursingReportBuilder.reconstructedCut(
            snapshot:snapshot,catalog:catalog,mappings:mappings,
            start:"2026-10-09",end:"2026-10-22")
        XCTAssertEqual(report.rows,again.rows)
    }
    func testReconstructionRejectsRangesWithoutNinthDayOpening()throws {
        let snapshot=try source("n1e-clinical-stock.json")
        let nursing=try source("n2-nursing-parity.json")
        let parsed=try XCTUnwrap(JSONSerialization.jsonObject(with:nursing) as? [String:Any])
        let catalog=try JSONSerialization.data(withJSONObject:parsed["catalog"]!)
        XCTAssertThrowsError(try N2NursingReportBuilder.reconstructedCut(
            snapshot:snapshot,catalog:catalog,
            mappings:source("n2-reviewed-approved.json"),
            start:"2026-10-10",end:"2026-10-22"))
    }
    func testEndBeforeNinthSelectsPreviousMonthlyCut()throws {
        let result=try N2AutomaticCutAccounting.calculate(
            snapshot:source("n1e-clinical-stock.json"),
            mappings:source("n2-reviewed-approved.json"),
            through:"2026-11-08")
        XCTAssertEqual(result.start,"2026-10-09")
    }
}
