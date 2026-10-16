import Foundation
import XCTest
@testable import DanperCore

final class N1rNativeWorkbookWriterTests:XCTestCase {
    private func folder() throws -> URL {
        guard let s=ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"] else {
            throw XCTSkip("Synthetic fixture path not provided")
        }
        return URL(fileURLWithPath:s,isDirectory:true)
    }
    private func template() throws -> Data {
        try Data(contentsOf:folder().appendingPathComponent("n1r-sanitized-template-store.zip"))
    }
    private func plan(_ id:String) throws -> Data {
        try Data(contentsOf:folder().appendingPathComponent("n1p-"+id+"-expected.json"))
    }
    private func altered(_ update:(inout [[String:Any]])->Void) throws -> Data {
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:plan("stock")) as? [String:Any])
        var body=json["plan"] as! [String:Any]
        var lines=body["lines"] as! [[String:Any]]
        update(&lines)
        body["lines"]=lines;json["plan"]=body
        return try JSONSerialization.data(withJSONObject:json,options:[.sortedKeys])
    }
    func testWritesNativeFiveRowXlsx() throws {
        let input=try template(),manifest=try plan("stock")
        let result=try N1rNativeWorkbookWriter.export(storedTemplate:input,syntheticPlan:manifest)
        XCTAssertEqual(result.rows,5)
        XCTAssertEqual(result.sheetNames.count,10)
        XCTAssertFalse(result.canActivate)
        XCTAssertFalse(result.supportsFullExcelParity)
        XCTAssertEqual(try N1rStoredZip.unpack(result.xlsx).count,try N1rStoredZip.unpack(input).count)
        XCTAssertEqual(result.xlsx,try N1rNativeWorkbookWriter.export(
          storedTemplate:input,syntheticPlan:manifest).xlsx)
        XCTAssertEqual(input,try template())
        try result.xlsx.write(to:folder().appendingPathComponent("n1r-stock-native.xlsx"),options:.atomic)
    }
    func testWritesSevenFrequencyRowsInNativeXlsx() throws {
        let report=try N1rNativeWorkbookWriter.export(storedTemplate:template(),syntheticPlan:plan("frequency"))
        XCTAssertEqual(report.rows,7)
        try report.xlsx.write(to:folder().appendingPathComponent("n1r-frequency-native.xlsx"),options:.atomic)
    }
    func testCRCRejection() throws {
        var b=[UInt8](try template())
        let start=30+Int(b[26])+Int(b[27])*256+Int(b[28])+Int(b[29])*256
        XCTAssertLessThan(start,b.count)
        b[start] ^= 1
        XCTAssertThrowsError(try N1rStoredZip.unpack(Data(b))) {
            XCTAssertEqual($0 as? N1rWorkbookError,.badCRC)
        }
    }
    func testCorruptCentralDirectoryRejected() throws {
        var b=[UInt8](try template())
        b[b.count-22] ^= 1
        XCTAssertThrowsError(try N1rStoredZip.unpack(Data(b)))
    }
    func testDuplicateClinicalIDsRejected() throws {
        let bad=try altered{ $0[1]["id"]=$0[0]["id"] }
        XCTAssertThrowsError(try N1rNativeWorkbookWriter.export(
            storedTemplate:template(),syntheticPlan:bad)) {
            XCTAssertEqual($0 as? N1rWorkbookError,.duplicateRow)
        }
    }
    func testClinicalIdentifierMustStayText() throws {
        let bad=try altered{ lines in
            var cells=lines[0]["cells"] as! [Any]
            cells[7]=1
            lines[0]["cells"]=cells
        }
        XCTAssertThrowsError(try N1rNativeWorkbookWriter.export(
            storedTemplate:template(),syntheticPlan:bad)) {
            XCTAssertEqual($0 as? N1rWorkbookError,.invalidValue)
        }
    }
    func testIllegalXMLControlsRejected() throws {
        let bad=try altered{ lines in
            var cells=lines[0]["cells"] as! [Any]
            cells[29]="ILEGAL\u{0001}CONTROL"
            lines[0]["cells"]=cells
        }
        XCTAssertThrowsError(try N1rNativeWorkbookWriter.export(
            storedTemplate:template(),syntheticPlan:bad)) {
            XCTAssertEqual($0 as? N1rWorkbookError,.invalidValue)
        }
    }
    func testFormulaInjectionAndXMLCharactersAreEscaped() throws {
        let bad=try altered{ lines in
            var cells=lines[0]["cells"] as! [Any]
            cells[29]="=HYPERLINK(\"http://example.invalid/?x=1&y=2\",\"<X>\")"
            lines[0]["cells"]=cells
        }
        let output=try N1rNativeWorkbookWriter.export(
            storedTemplate:template(),syntheticPlan:bad)
        let data=try XCTUnwrap(N1rStoredZip.unpack(output.xlsx)
            .first{$0.name=="xl/worksheets/sheet5.xml"}?.data)
        let xml=try XCTUnwrap(String(data:data,encoding:.utf8))
        XCTAssertTrue(xml.contains("=HYPERLINK(&quot;"))
        XCTAssertTrue(xml.contains("&amp;y=2"))
        XCTAssertTrue(xml.contains("&lt;X&gt;"))
        XCTAssertFalse(xml.contains("<f>=HYPERLINK"))
    }
    func testIncompleteOriginalTemplateRejected() throws {
        let base=try N1rStoredZip.unpack(template())
        let invalid=try N1rStoredZip.pack(base.filter{$0.name != "xl/workbook.xml"})
        XCTAssertThrowsError(try N1rNativeWorkbookWriter.export(
            storedTemplate:invalid,syntheticPlan:plan("stock"))) {
            XCTAssertEqual($0 as? N1rWorkbookError,.invalidTemplate)
        }
    }
    func testNineOtherWorksheetsAndStylesUntouched() throws {
        let before=try N1rStoredZip.unpack(template())
        let result=try N1rNativeWorkbookWriter.export(
            storedTemplate:template(),syntheticPlan:plan("stock"))
        let after=try N1rStoredZip.unpack(result.xlsx)
        for part in before where part.name != "xl/worksheets/sheet5.xml" &&
               !part.name.hasPrefix("xl/tables/table") {
            XCTAssertEqual(part.data,after.first{$0.name==part.name}?.data)
        }
        XCTAssertFalse(result.canActivate)
        XCTAssertFalse(result.supportsFullExcelParity)
    }
}
