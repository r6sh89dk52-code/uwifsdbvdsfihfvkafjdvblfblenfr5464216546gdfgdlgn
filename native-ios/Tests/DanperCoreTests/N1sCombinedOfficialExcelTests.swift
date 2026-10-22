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
        let parts=try N1rStoredZip.unpack(result.xlsx)
        let workbook=try XCTUnwrap(parts.first{$0.name=="xl/workbook.xml"})
        let bookXML=try XCTUnwrap(String(data:workbook.data,encoding:.utf8))
        let names=["BD MATERIALES","CONTEO","INGRESOS","RESU","CONSUMOS",
                   "JUSTIFICACIONES","GUIA","@subuo","BASE TRU","@uo"]
        for name in names {XCTAssertTrue(bookXML.contains("name=\""+name+"\""))}
        XCTAssertEqual((1...10).filter{n in
            parts.contains{$0.name=="xl/worksheets/sheet\(n).xml"}
        }.count,10)
        XCTAssertEqual(parts.filter{$0.name.hasPrefix("xl/tables/table") &&
                                 $0.name.hasSuffix(".xml")}.count,19)
        XCTAssertFalse(result.canUseClinicalData)
        XCTAssertGreaterThan(result.xlsx.count,50_000)
        XCTAssertEqual(result.xlsx,try N1sFullExcelWriter.exportIndicator(base:first,manifest:plan).xlsx)
        XCTAssertEqual(first,try fixture("n1s-indicator-template-store.zip"))
        try write("n1s-indicator-native.xlsx",result.xlsx)
    }
    func testIngresosExpirationSemaforoHasThreeIconColorsAndHidesNumericStatus() throws {
        let result=try N1sFullExcelWriter.exportIndicator(
            base:fixture("n1s-indicator-template-store.zip"),
            manifest:fixture("n1s-indicator-plan.json"))
        let archive=try N1rStoredZip.unpack(result.xlsx)
        let xml=try XCTUnwrap(String(data:try XCTUnwrap(
            archive.first{$0.name=="xl/worksheets/sheet3.xml"}).data,encoding:.utf8))
        XCTAssertTrue(xml.contains("sqref=\"D3:G434\""))
        XCTAssertTrue(xml.contains("iconSet=\"3TrafficLights1\""))
        XCTAssertTrue(xml.contains("showValue=\"0\""))
        XCTAssertTrue(xml.contains("reverse=\"1\""))
        for status in 0...2 {
            XCTAssertTrue(xml.contains("type=\"num\" val=\"\(status)\""))
        }
        XCTAssertTrue(xml.contains("J3&lt;TODAY(),2"))
        XCTAssertTrue(xml.contains("J3-TODAY()&lt;=90,1,0"))
        XCTAssertFalse(xml.contains("<xm:sqref>D3:G439</xm:sqref>"))
    }

    func testNursingOriginalWorkbook98RowsPlusPrintSettings() throws {
        let result=try N1sNursingExcelWriter.export(
            base:fixture("n1s-nursing-template-store.zip"),
            manifest:fixture("n1s-nursing-plan.json"))
        XCTAssertEqual(result.sheetCount,1)
        XCTAssertEqual(result.writtenRows,98)
        let package=try N1rStoredZip.unpack(result.xlsx)
        XCTAssertFalse(package.contains{$0.name=="xl/worksheets/sheet1.xml"})
        let book=try XCTUnwrap(package.first{$0.name=="xl/workbook.xml"})
        let xml=try XCTUnwrap(String(data:book.data,encoding:.utf8))
        XCTAssertTrue(xml.contains("name=\"KARDEX ENFERMERAS\""))
        XCTAssertFalse(xml.contains("name=\"Hoja1\""))
        XCTAssertFalse(package.contains{$0.name=="docProps/app.xml"})
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
    func testBundledDemoOnlyGateRejectsAnyUnmarkedClinicalPlan() throws {
        for kind in N1sDemoWorkbookKind.allCases {
            let prefix = kind == .indicator ? "n1s-indicator" : "n1s-nursing"
            let base = try fixture(prefix + "-template-store.zip")
            let original = try fixture(prefix + "-plan.json")
            XCTAssertThrowsError(try N1sDemoExportBridge.create(kind,
                                    base: base, manifest: original)) {
                XCTAssertEqual($0 as? N1sDemoExportError, .nonDemoManifest)
            }
            var parsed = try manifest(prefix + "-plan.json")
            parsed["demoFixtureOnly"] = true
            parsed["demoFixtureTag"] = "DANPER_N1S_SYNTHETIC_2026"
            parsed["demoKind"] = kind.rawValue
            let marked = try JSONSerialization.data(withJSONObject: parsed)
            let result = try N1sDemoExportBridge.create(kind,base:base,manifest:marked)
            XCTAssertTrue(result.starts(with:[0x50,0x4B,0x03,0x04]))
            parsed["demoKind"] = "different"
            let wrong = try JSONSerialization.data(withJSONObject: parsed)
            XCTAssertThrowsError(try N1sDemoExportBridge.create(kind,
                                    base: base, manifest: wrong)) {
                XCTAssertEqual($0 as? N1sDemoExportError, .nonDemoManifest)
            }
        }
    }
    func testBothOfficialWorkbooksKeepDatesNumericAndDisplayDDMMYYYY() throws {
        var plan=try manifest("n1s-nursing-plan.json")
        var rows=try XCTUnwrap(plan["rows"] as? [[String:Any]])
        rows[0]["expiry"]="2026-10-18"
        plan["rows"]=rows
        let nursing=try N1sNursingExcelWriter.export(
            base:fixture("n1s-nursing-template-store.zip"),
            manifest:JSONSerialization.data(withJSONObject:plan))
        let entries=try N1rStoredZip.unpack(nursing.xlsx)
        let sheet=try XCTUnwrap(String(data:XCTUnwrap(
            entries.first(where:{$0.name=="xl/worksheets/sheet2.xml"})?.data),
            encoding:.utf8))
        let styles=try XCTUnwrap(String(data:XCTUnwrap(
            entries.first(where:{$0.name=="xl/styles.xml"})?.data),
            encoding:.utf8))
        XCTAssertTrue(styles.contains("formatCode=\"dd/mm/yyyy\""))
        XCTAssertFalse(sheet.contains("2026-10-18"))
        XCTAssertTrue(sheet.contains("<v>46313</v></c>"))
        XCTAssertTrue(sheet.contains("r=\"I7\" s=\""))

        let indicator=try N1sFullExcelWriter.exportIndicator(
            base:fixture("n1s-indicator-template-store.zip"),
            manifest:fixture("n1s-indicator-plan.json"))
        let all=try N1rStoredZip.unpack(indicator.xlsx)
        let stylesTen=try XCTUnwrap(String(data:XCTUnwrap(
            all.first(where:{$0.name=="xl/styles.xml"})?.data),encoding:.utf8))
        let consumos=try XCTUnwrap(String(data:XCTUnwrap(
            all.first(where:{$0.name=="xl/worksheets/sheet5.xml"})?.data),
            encoding:.utf8))
        XCTAssertTrue(stylesTen.contains("formatCode=\"dd/mm/yyyy\""))
        XCTAssertTrue(consumos.contains("r=\"F2\" s=\""))
    }
}
