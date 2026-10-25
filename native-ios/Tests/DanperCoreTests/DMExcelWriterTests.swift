import Foundation
import XCTest
import ZIPFoundation
@testable import DanperCore

final class DMExcelWriterTests:XCTestCase {
    private func fixture(_ location:URL)throws {
        let archive=try Archive(url:location,accessMode:.create)
        var rows=[String]()
        for i in 1...4093 {
            if i==1 {
                rows.append("<row r=\"1\"><c r=\"I1\" s=\"58\" t=\"inlineStr\"><is><t>DNI</t></is></c></row>")
                continue
            }
            let historical=i==2
            rows.append("<row r=\"\(i)\">"+
                "<c r=\"F\(i)\" s=\"50\""+(historical ? "><v>46055</v></c>" : "/>")+
                "<c r=\"I\(i)\" s=\"51\""+(historical ? "><v>87654321</v></c>" : "/>")+
                "<c r=\"O\(i)\" s=\"55\"/>"+
                "<c r=\"P\(i)\" s=\"55\"/>"+
                "<c r=\"Q\(i)\" s=\"53\"/>"+
                "<c r=\"R\(i)\" s=\"54\"/>"+
                "<c r=\"S\(i)\" s=\"54\"/>"+
                "<c r=\"U\(i)\" s=\"54\"/>"+
                "<c r=\"AA\(i)\" s=\"42\"/>"+
                "<c r=\"AC\(i)\" s=\"66\"/></row>")
        }
        let sheet="<worksheet><dimension ref=\"A1:AE4093\"/><sheetData>"+
            rows.joined()+"</sheetData></worksheet>"
        var entries=[String:String]()
        entries["xl/workbook.xml"]="WBOOK-PRESERVED"
        entries["xl/tables/table1.xml"]="TABLE-PRESERVED"
        for i in 2...7 {entries["xl/worksheets/sheet\(i).xml"]="SHEET\(i)-PRESERVED"}
        entries["xl/worksheets/sheet1.xml"]=sheet
        for (path,string) in entries.sorted(by:{$0.key<$1.key}) {
            let data=Data(string.utf8)
            try archive.addEntry(with:path,type:.file,uncompressedSize:UInt32(data.count),
                                 compressionMethod:.deflate,
                                 provider:{p,size in
                                     data.subdata(in:Int(p)..<(Int(p)+size))
                                 })
        }
    }
    private func read(_ archive:Archive,_ path:String)throws->String {
        let entry=try XCTUnwrap(archive[path])
        var data=Data()
        _=try archive.extract(entry){chunk in data.append(chunk)}
        return try XCTUnwrap(String(data:data,encoding:.utf8))
    }
    func testSevenSheetsHistoricalCellsAndDatesRemainUntouched()throws {
        let directory=FileManager.default.temporaryDirectory
            .appendingPathComponent("dm-excel-test-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:false)
        defer {try? FileManager.default.removeItem(at:directory)}
        let source=directory.appendingPathComponent("base.xlsx")
        let target=directory.appendingPathComponent("result.xlsx")
        try fixture(source)
        var c=DMCertificate()
        c.dni="12345678";c.name="PERSONA FICTICIA";c.certificateNumber="SYN-2026"
        c.receiptDate="2026-10-23";c.startDate="2026-10-19"
        c.endDate="2026-10-20";c.documentDays=2
        c.issuer="ESSALUD";c.contingency="ENFERMEDAD COMUN"
        try DMExcelWriter.export(template:source,records:[c],destination:target)
        let archive=try Archive(url:target,accessMode:.read)
        XCTAssertEqual(try read(archive,"xl/tables/table1.xml"),"TABLE-PRESERVED")
        for i in 2...7 {
            XCTAssertEqual(try read(archive,"xl/worksheets/sheet\(i).xml"),"SHEET\(i)-PRESERVED")
        }
        let xml=try read(archive,"xl/worksheets/sheet1.xml")
        XCTAssertTrue(xml.contains("<c r=\"I2\" s=\"51\"><v>87654321</v></c>"))
        XCTAssertTrue(xml.contains("<c r=\"I3\" s=\"51\"><v>12345678</v></c>"))
        XCTAssertTrue(xml.contains("<f>IF(AND(O3&lt;&gt;\"\",P3&lt;&gt;\"\"),P3-O3+1,0)</f>"))
        XCTAssertTrue(xml.contains("<c r=\"F3\" s=\"50\"><v>46318</v></c>"))
    }
}
