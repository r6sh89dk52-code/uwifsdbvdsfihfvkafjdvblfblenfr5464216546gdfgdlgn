import Foundation
import XCTest
@testable import DanperCore

/// N1q exclusively tests outputs from real TypeScript code using synthetic
/// data and spreadsheet generated in memory on the Linux CI runner.
final class N1qReconciliationParityTests:XCTestCase {
    private func read(_ file:String) throws -> Data {
        guard let directory=ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"] else {
            throw XCTSkip("N1q synthetic fixture directory unavailable")
        }
        return try Data(contentsOf:URL(fileURLWithPath:directory)
                .appendingPathComponent(file))
    }
    private func original() throws -> Data {
        try read("n1e-clinical-stock.json")
    }
    private func reference(_ mode:String) throws -> Data {
        try read("n1q-"+mode+"-expected.json")
    }
    private func report(_ mode:String) throws -> N1qParityReport {
        try N1qReconciliationParityAudit.inspect(snapshot:original(),
                                                reference:reference(mode))
    }
    private func mutated(_ mode:String,
                         change:(inout [String:Any])->Void) throws -> Data {
        let input=try reference(mode)
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:input) as? [String:Any])
        change(&root)
        return try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys])
    }
    private func rejects(_ mode:String,reference altered:Data,
                         expected:N1qAuditError?=nil,
                         file:StaticString=#filePath,line:UInt=#line) throws {
        XCTAssertThrowsError(try N1qReconciliationParityAudit.inspect(
            snapshot:original(),reference:altered),file:file,line:line) { error in
                if let expected {
                    XCTAssertEqual(error as? N1qAuditError,expected,file:file,line:line)
                }
            }
    }
    func testReconciledReviewedWorkbookThreeMaterialKinds() throws {
        let r=try report("reviewed")
        XCTAssertTrue(r.reviewed)
        XCTAssertEqual(r.products,432)
        XCTAssertEqual(r.verifiedOpenings,3)
        XCTAssertEqual(r.verifiedCounts,3)
        XCTAssertEqual(r.receipts,3)
        XCTAssertEqual(r.physicalClinicalLines,2)
        XCTAssertEqual(r.rowsWithFormulas,432)
        XCTAssertEqual(r.workbookSHA256.count,64)
        XCTAssertFalse(r.canActivate)
        XCTAssertFalse(r.isNativeWorkbookExporter)
    }
    func testBeforeReviewReceiptTotalMustRemainUnknownNotZero() throws {
        let r=try report("unreviewed")
        XCTAssertFalse(r.reviewed)
        XCTAssertEqual(r.receipts,3)
        XCTAssertEqual(r.verifiedOpenings,3)
        XCTAssertFalse(r.canActivate)
    }
    func testVoidedReviewRestoresUnreviewedStateWithoutDeletingReceipts() throws {
        let r=try report("voided")
        XCTAssertFalse(r.reviewed)
        XCTAssertEqual(r.receipts,3)
        XCTAssertEqual(r.verifiedCounts,3)
    }
    func testMissingVersusMeasuredZeroStockDetected() throws {
        let wrong=try mutated("reviewed"){root in
            var by=root["byCode"] as! [String:[String:Any]]
            var material=by["16000001"]!
            material["opening"]=0 // Unknown must never turn into measured zero.
            by["16000001"]=material;root["byCode"]=by
        }
        try rejects("reviewed",reference:wrong,expected:.invalidReconciliation)
    }
    func testInventedClosingBalanceIsRejected() throws {
        let wrong=try mutated("reviewed"){root in
            var by=root["byCode"] as! [String:[String:Any]]
            var row=by["16000182"]!
            row["closing"]=999;by["16000182"]=row;root["byCode"]=by
        }
        try rejects("reviewed",reference:wrong,expected:.invalidReconciliation)
    }
    func testTotalReceiptMustNotExistBeforeReview() throws {
        let wrong=try mutated("unreviewed"){root in
            var by=root["byCode"] as! [String:[String:Any]]
            var row=by["16000182"]!
            row["receipts"]=0;by["16000182"]=row;root["byCode"]=by
        }
        try rejects("unreviewed",reference:wrong,expected:.invalidReconciliation)
    }
    func testIncorrectRESUFormulaDetected() throws {
        let wrong=try mutated("reviewed"){root in
            var book=root["workbook"] as! [String:Any]
            var samples=book["formulaSamples"] as! [[String:Any]]
            var row=samples[0]["resu"] as! [String:String]
            row["F"]="SUM(0)";samples[0]["resu"]=row
            book["formulaSamples"]=samples;root["workbook"]=book
        }
        try rejects("reviewed",reference:wrong,expected:.invalidFormula)
    }
    func testUnreviewedINGRESOSXFormulaMustBeAbsent() throws {
        let wrong=try mutated("unreviewed"){root in
            var book=root["workbook"] as! [String:Any]
            var samples=book["formulaSamples"] as! [[String:Any]]
            var row=samples[0]["ingresos"] as! [String:String]
            row["X"]="SUM(H3,L3,P3,T3)"
            samples[0]["ingresos"]=row
            book["formulaSamples"]=samples;root["workbook"]=book
        }
        try rejects("unreviewed",reference:wrong,expected:.invalidFormula)
    }
    func testFirstReceiptDocumentMismatchInXlsxEvidenceDetected() throws {
        let wrong=try mutated("reviewed"){root in
            var book=root["workbook"] as! [String:Any]
            var entries=book["physicalCells"] as! [[String:Any]]
            let index=entries.firstIndex{($0["code"] as? String)=="16000182"}!
            var income=entries[index]["income"] as! [String:String]
            income["K"]="INCORRECTO";entries[index]["income"]=income
            book["physicalCells"]=entries;root["workbook"]=book
        }
        try rejects("reviewed",reference:wrong,expected:.invalidWorkbookCell)
    }
    func testDuplicateReceiptEventMustNotBeAccepted() throws {
        let wrong=try mutated("reviewed"){root in
            var events=root["events"] as! [[String:Any]]
            events.append(events[3])
            root["events"]=events
        }
        try rejects("reviewed",reference:wrong,expected:.invalidEvents)
    }
    func testTooManyReceiptsForOfficialTemplateRejected() throws {
        let wrong=try mutated("unreviewed"){root in
            var events=root["events"] as! [[String:Any]]
            for i in 0..<4 {
                var copy=events[3]
                copy["id"]="FAKE-ADD-"+String(i)
                copy["document"]="FAKE-DOC-"+String(i)
                copy["date"]="2026-10-20"
                copy["at"]=1_800_000_000_000+i*1000
                events.append(copy)
            }
            root["events"]=events
        }
        try rejects("unreviewed",reference:wrong,expected:.invalidEvents)
    }
    func testTamperedOriginalPhysicalMovementCannotPassSourceIntegrity() throws {
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(with:original()) as? [String:Any])
        var moves=snapshot["stockMovements"] as! [[String:Any]]
        moves[0]["excelQuantity"]=99
        snapshot["stockMovements"]=moves
        let data=try JSONSerialization.data(withJSONObject:snapshot)
        XCTAssertThrowsError(try N1qReconciliationParityAudit.inspect(
            snapshot:data,reference:reference("reviewed"))) {
                XCTAssertEqual($0 as? N1qAuditError,.alteredSource)
            }
    }
    func testLostSheetOrMaterialCatalogDetected() throws {
        let wrong=try mutated("reviewed"){root in
            var book=root["workbook"] as! [String:Any]
            var sheets=book["sheets"] as! [String]
            sheets.removeLast();book["sheets"]=sheets
            root["workbook"]=book
        }
        try rejects("reviewed",reference:wrong,expected:.invalidReference)
        let catalog=try mutated("reviewed"){root in
            var products=root["catalog"] as! [[String:Any]]
            products[0]["code"]=products[1]["code"]
            root["catalog"]=products
        }
        try rejects("reviewed",reference:catalog,expected:.invalidCatalog)
    }
}
