import Foundation
import XCTest
@testable import DanperCore

final class N1sCombinedOfficialExcelTests:XCTestCase {
    private func dir() throws -> URL {
        guard let path=ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"]
        else {throw XCTSkip("Only generated synthetic and sanitized Excel fixtures")}
        return URL(fileURLWithPath:path,isDirectory:true)
    }
    private func fixture(_ name:String) throws -> Data {
        try Data(contentsOf:dir().appendingPathComponent(name))
    }
    private func manifest(_ name:String) throws -> [String:Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with:fixture(name)) as? [String:Any])
    }
    private func write(_ file:String,_ data:Data) throws {
        try data.write(to:dir().appendingPathComponent(file),options:.atomic)
    }
    func testIndicatorTenSheets432MaterialsAndAllReconciliationCalculationsWrittenBySwift() throws {
        let first=try fixture("n1s-indicator-template-store.zip")
        let plan=try fixture("n1s-indicator-plan.json")
        let result=try N1sFullExcelWriter.exportIndicator(base:first,manifest:plan)
        XCTAssertEqual(result.sheetCount,10)
        XCTAssertEqual(result.writtenRows,2)
        XCTAssertFalse(result.canUseClinicalData)
        XCTAssertGreaterThan(result.xlsx.count,50_000)
        XCTAssertEqual(result.xlsx,try N1sFullExcelWriter.exportIndicator(base:first,manifest:plan).xlsx)
        XCTAssertEqual(first,try fixture("n1s-indicator-template-store.zip"))
        try write("n1s-indicator-native.xlsx",result.xlsx)
    }
    func testNursingOriginalWorkbook98RowsPlusPrintSettings() throws {
        let result=try N1sNursingExcelWriter.export(
            base:fixture("n1s-nursing-template-store.zip"),
            manifest:fixture("n1s-nursing-plan.json"))
        XCTAssertEqual(result.sheetCount,1)
        XCTAssertEqual(result.writtenRows,98)
        XCTAssertFalse(result.canUseClinicalData)
        XCTAssertTrue(try N1rStoredZip.unpack(result.xlsx).contains{
            $0.name=="xl/printerSettings/printerSettings2.bin"
        })
        try write("n1s-nursing-native.xlsx",result.xlsx)
    }
    func testUnreviewedCannotBePresentedAsOfficialWorkbook() throws {
        var plan=try manifest("n1s-indicator-plan.json")
        plan["reviewed"]=false
        let payload=try JSONSerialization.data(withJSONObject:plan)
        XCTAssertThrowsError(try N1sFullExcelWriter.exportIndicator(
            base:fixture("n1s-indicator-template-store.zip"),manifest:payload)) {
            XCTAssertEqual($0 as? N1sExcelError,.unreviewedOfficial)
        }
    }
    func testMissingOrFalseClinicalQuantityCannotBecomeConfirmedZero() throws {
        var plan=try manifest("n1s-indicator-plan.json")
        var values=plan["plan"] as! [String:Any]
        var lines=values["lines"] as! [[String:Any]]
        var cells=lines[0]["cells"] as! [Any]
        cells[17]=""  // physical unknown is not R=0
        lines[0]["cells"]=cells
        values["lines"]=lines;plan["plan"]=values
        XCTAssertThrowsError(try N1sFullExcelWriter.exportIndicator(
            base:fixture("n1s-indicator-template-store.zip"),
            manifest:JSONSerialization.data(withJSONObject:plan))) {
            XCTAssertEqual($0 as? N1sExcelError,.missingVerifiedQuantity)
        }
    }
    func testNoInventedMaterialOrDropped432Catalog() throws {
        var plan=try manifest("n1s-indicator-plan.json")
        var products=plan["catalog"] as! [[String:Any]]
        products.removeLast();plan["catalog"]=products
        XCTAssertThrowsError(try N1sFullExcelWriter.exportIndicator(
            base:fixture("n1s-indicator-template-store.zip"),
            manifest:JSONSerialization.data(withJSONObject:plan)))
    }
    func testUnknownPackageWithoutExplicitConfirmedUseRejected() throws {
        let unknown=N1sContainerUse(remaining:99,sealed:1,containerSize:100,
                                   quantityPerVisit:1,quantityVerified:false,openingApproved:false)
        XCTAssertThrowsError(try N1sContainerUseRule.consume(unknown)) {
            XCTAssertEqual($0 as? N1sContainerRuleError,.unverifiedUse)
        }
    }
    func test100mLIs100VisitsOnlyAtVerifiedOneMilliliterPerVisit() throws {
        var remaining=0.0,sealed=2
        for index in 0..<100 {
            let approved=index==0
            let input=N1sContainerUse(remaining:remaining,sealed:sealed,
                containerSize:100,quantityPerVisit:1,
                quantityVerified:true,openingApproved:approved)
            let next=try N1sContainerUseRule.consume(input)
            XCTAssertFalse(next.requiresOpeningConsent)
            XCTAssertEqual(next.excelR,index==0 ? 1 : 0)
            remaining=next.nextRemaining
            sealed=next.nextSealed
        }
        XCTAssertEqual(remaining,0)
        XCTAssertEqual(sealed,1)
        let next=N1sContainerUse(remaining:remaining,sealed:sealed,
                     containerSize:100,quantityPerVisit:1,
                     quantityVerified:true,openingApproved:false)
        let paused=try N1sContainerUseRule.consume(next)
        XCTAssertTrue(paused.requiresOpeningConsent)
        XCTAssertEqual(paused.nextSealed,1)
        XCTAssertEqual(paused.nextRemaining,0)
        let allowed=try N1sContainerUseRule.consume(N1sContainerUse(
            remaining:0,sealed:1,containerSize:100,quantityPerVisit:1,
            quantityVerified:true,openingApproved:true))
        XCTAssertEqual(allowed.excelR,1)
        XCTAssertEqual(allowed.nextSealed,0)
        XCTAssertEqual(allowed.nextRemaining,99)
    }
    func test100mLAtTwoMillilitersPerUseOnlyLasts50Visits() throws {
        var remainder=0.0,stock=1
        for i in 0..<50 {
            let state=try N1sContainerUseRule.consume(N1sContainerUse(
               remaining:remainder,sealed:stock,containerSize:100,
               quantityPerVisit:2,quantityVerified:true,
               openingApproved:i==0))
            remainder=state.nextRemaining
            stock=state.nextSealed
        }
        XCTAssertEqual(remainder,0)
        XCTAssertEqual(stock,0)
        XCTAssertThrowsError(try N1sContainerUseRule.consume(N1sContainerUse(
            remaining:0,sealed:0,containerSize:100,quantityPerVisit:2,
            quantityVerified:true,openingApproved:true))) {
            XCTAssertEqual($0 as? N1sContainerRuleError,.insufficientStock)
        }
    }
    func testTwoContainersNeededInSingleUseRequiresExplicitApprovalAndReportsTwoOpenings() throws {
        let requested=N1sContainerUse(remaining:20,sealed:2,containerSize:100,
              quantityPerVisit:150,quantityVerified:true,openingApproved:false)
        XCTAssertTrue(try N1sContainerUseRule.consume(requested).requiresOpeningConsent)
        let approved=try N1sContainerUseRule.consume(N1sContainerUse(
            remaining:20,sealed:2,containerSize:100,quantityPerVisit:150,
            quantityVerified:true,openingApproved:true))
        XCTAssertEqual(approved.excelR,2)
        XCTAssertEqual(approved.nextRemaining,70)
        XCTAssertEqual(approved.nextSealed,0)
    }
    func testAvoidUnboundedOrNegativeContainerVolumes() throws {
        XCTAssertThrowsError(try N1sContainerUseRule.consume(N1sContainerUse(
            remaining:120,sealed:1,containerSize:100,quantityPerVisit:1,
            quantityVerified:true,openingApproved:true)))
        XCTAssertThrowsError(try N1sContainerUseRule.consume(N1sContainerUse(
            remaining:1,sealed:1,containerSize:100,quantityPerVisit:0,
            quantityVerified:true,openingApproved:true)))
    }
    func testNursingWrongRowCountOrDonatedProductRejected() throws {
        var input=try manifest("n1s-nursing-plan.json")
        var rows=input["rows"] as! [[String:Any]]
        rows[0]["donated"]=true
        input["rows"]=rows
        XCTAssertThrowsError(try N1sNursingExcelWriter.export(
            base:fixture("n1s-nursing-template-store.zip"),
            manifest:JSONSerialization.data(withJSONObject:input)))
    }
}
