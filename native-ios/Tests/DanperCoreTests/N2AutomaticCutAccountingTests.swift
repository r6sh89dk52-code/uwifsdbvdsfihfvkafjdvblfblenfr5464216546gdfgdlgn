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
    func testEndBeforeNinthSelectsPreviousMonthlyCut()throws {
        let result=try N2AutomaticCutAccounting.calculate(
            snapshot:source("n1e-clinical-stock.json"),
            mappings:source("n2-reviewed-approved.json"),
            through:"2026-11-08")
        XCTAssertEqual(result.start,"2026-10-09")
    }
}
