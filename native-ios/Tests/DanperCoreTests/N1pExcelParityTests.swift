import Foundation
import XCTest
@testable import DanperCore

final class N1pExcelParityTests:XCTestCase {
    private func fixture(_ name:String) throws -> Data {
        guard let root=ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"] else {
            throw XCTSkip("Synthetic fixture generator required")
        }
        return try Data(contentsOf:URL(fileURLWithPath:root)
                        .appendingPathComponent(name))
    }
    private func verify(_ name:String) throws -> N1pExcelParityReport {
        try N1pExcelParityAudit.inspect(
            snapshot:fixture("n1p-"+name+"-source.json"),
            reference:fixture("n1p-"+name+"-expected.json"))
    }
    private func changed(_ name:String,_ mutate:(inout [String:Any])->Void) throws -> Data {
        var document=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1p-"+name+"-expected.json")) as? [String:Any])
        mutate(&document)
        return try JSONSerialization.data(withJSONObject:document,options:[.sortedKeys])
    }
    func testTypeScriptOfficialTenSheetWorkbookAndFEFOProvisionalRows() throws {
        let audit=try verify("stock")
        XCTAssertEqual(audit.sheets,10)
        XCTAssertEqual(audit.columns,30)
        XCTAssertEqual(audit.visits,5)
        XCTAssertEqual(audit.rows,5)
        XCTAssertEqual(audit.linkedDeliveries,4)
        XCTAssertEqual(audit.pendingDeliveries,1)
        XCTAssertEqual(audit.confirmedZeroRows,1)
        XCTAssertEqual(audit.workbookSHA256.count,64)
        XCTAssertFalse(audit.canActivate)
        XCTAssertFalse(audit.canClaimOfficialReconciledExport)
    }
    func testSixSameDayVisitsAndTwoLinesShareClinicalFrequency() throws {
        let report=try verify("frequency")
        XCTAssertEqual(report.visits,6)
        XCTAssertEqual(report.rows,7)
        XCTAssertEqual(report.pendingDeliveries,2)
        XCTAssertEqual(report.linkedDeliveries,0)
        XCTAssertEqual(report.confirmedZeroRows,0)
        XCTAssertFalse(report.canActivate)
    }
    func testChangingWorkbookQuantityR0ToOneIsRejected() throws {
        let expected=try changed("stock"){root in
            var plan=root["plan"] as! [String:Any]
            var rows=plan["lines"] as! [[String:Any]]
            var cells=rows[3]["cells"] as! [Any]
            cells[17]=1
            rows[3]["cells"]=cells
            plan["lines"]=rows
            root["plan"]=plan
        }
        XCTAssertThrowsError(try N1pExcelParityAudit.inspect(
            snapshot:fixture("n1p-stock-source.json"),reference:expected)) {
            XCTAssertEqual($0 as? N1pExcelParityError,.wrongClinicalQuantity)
        }
    }
    func testLosingLeadingZeroFromDniRejected() throws {
        let expected=try changed("stock"){root in
            var plan=root["plan"] as! [String:Any]
            var rows=plan["lines"] as! [[String:Any]]
            var cells=rows[0]["cells"] as! [Any]
            cells[7]="1"
            rows[0]["cells"]=cells
            plan["lines"]=rows
            root["plan"]=plan
        }
        XCTAssertThrowsError(try N1pExcelParityAudit.inspect(
            snapshot:fixture("n1p-stock-source.json"),reference:expected))
    }
    func testDuplicateOrIncorrectFrequencyRejected() throws {
        let expected=try changed("frequency"){root in
            var plan=root["plan"] as! [String:Any]
            var rows=plan["lines"] as! [[String:Any]]
            var cells=rows[2]["cells"] as! [Any]
            cells[18]="PRIMERA"
            rows[2]["cells"]=cells
            plan["lines"]=rows
            root["plan"]=plan
        }
        XCTAssertThrowsError(try N1pExcelParityAudit.inspect(
            snapshot:fixture("n1p-frequency-source.json"),reference:expected)) {
            XCTAssertEqual($0 as? N1pExcelParityError,.wrongFrequency)
        }
    }
    func testTenSheetsAndThirtyColumnsMustRemainExact() throws {
        let expected=try changed("stock"){root in
            var book=root["template"] as! [String:Any]
            var sheets=book["sheets"] as! [String]
            sheets.removeLast()
            book["sheets"]=sheets
            root["template"]=book
        }
        XCTAssertThrowsError(try N1pExcelParityAudit.inspect(
            snapshot:fixture("n1p-stock-source.json"),reference:expected)) {
            XCTAssertEqual($0 as? N1pExcelParityError,.invalidReference)
        }
    }
    func testDroppedColumnAndRowReorderingRejected() throws {
        let wrong=try changed("stock"){root in
            var plan=root["plan"] as! [String:Any]
            var rows=plan["lines"] as! [[String:Any]]
            var cells=rows[0]["cells"] as! [Any]
            cells.removeLast()
            rows[0]["cells"]=cells
            plan["lines"]=rows
            root["plan"]=plan
        }
        XCTAssertThrowsError(try N1pExcelParityAudit.inspect(
            snapshot:fixture("n1p-stock-source.json"),reference:wrong)) {
            XCTAssertEqual($0 as? N1pExcelParityError,.wrongColumn)
        }
        let reordered=try changed("stock"){root in
            var plan=root["plan"] as! [String:Any]
            var rows=plan["lines"] as! [[String:Any]]
            rows.swapAt(0,1)
            plan["lines"]=rows
            root["plan"]=plan
        }
        XCTAssertThrowsError(try N1pExcelParityAudit.inspect(
            snapshot:fixture("n1p-stock-source.json"),reference:reordered))
    }
    func testNoInventedMovementForProvisionalPending() throws {
        let expected=try changed("stock"){root in
            var plan=root["plan"] as! [String:Any]
            plan["pendingDeliveries"]=0
            root["plan"]=plan
        }
        XCTAssertThrowsError(try N1pExcelParityAudit.inspect(
            snapshot:fixture("n1p-stock-source.json"),reference:expected)) {
            XCTAssertEqual($0 as? N1pExcelParityError,.wrongStatus)
        }
    }
    func testChangedClinicalRecordDoesNotMatchSourceDigest() throws {
        let source=try fixture("n1p-stock-source.json")
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:source) as? [String:Any])
        var visits=root["attentions"] as! [[String:Any]]
        visits[0]["diagnosis"]="REGISTRO CAMBIADO"
        root["attentions"]=visits
        let altered=try JSONSerialization.data(withJSONObject:root)
        XCTAssertThrowsError(try N1pExcelParityAudit.inspect(
            snapshot:altered,reference:fixture("n1p-stock-expected.json"))) {
            XCTAssertEqual($0 as? N1pExcelParityError,.invalidReference)
        }
    }
    func testPhysicalLedgerTamperingRejectedEvenIfExpectedUnchanged() throws {
        let source=try fixture("n1p-stock-source.json")
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:source) as? [String:Any])
        var movement=root["stockMovements"] as! [[String:Any]]
        movement[0]["excelQuantity"]=99
        root["stockMovements"]=movement
        let altered=try JSONSerialization.data(withJSONObject:root)
        XCTAssertThrowsError(try N1pExcelParityAudit.inspect(
            snapshot:altered,reference:fixture("n1p-stock-expected.json")))
    }
}
