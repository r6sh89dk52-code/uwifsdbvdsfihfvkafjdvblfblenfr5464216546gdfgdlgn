import XCTest
import Foundation
import ZIPFoundation
@testable import DanperCore

final class N2PersonalWorkbookImportTests:XCTestCase {
    private func makeWorkbook(rows:[String],includePersonal:Bool=true,
                              useSharedStrings:Bool=true)throws->URL {
        let dir=FileManager.default.temporaryDirectory
        let path=dir.appendingPathComponent(UUID().uuidString+".xlsx")
        let archive=try Archive(url:path,accessMode:.create)
        func add(_ name:String,_ text:String)throws {
            let bytes=Data(text.utf8)
            try archive.addEntry(with:name,type:.file,
                                 uncompressedSize:Int64(bytes.count),
                                 compressionMethod:.deflate,
                                 provider:{offset,size in
                bytes.subdata(in:Int(offset)..<Int(offset)+size)
            })
        }
        let sheetName=includePersonal ? "PERSONAL" : "OTRA HOJA"
        let wb="""
        <?xml version="1.0" encoding="UTF-8"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
                  xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets><sheet name="\(sheetName)" sheetId="1" r:id="rId1"/></sheets></workbook>
        """
        let rel="""
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Target="worksheets/sheet1.xml"
            Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet"/>
        </Relationships>
        """
        try add("xl/workbook.xml",wb)
        try add("xl/_rels/workbook.xml.rels",rel)
        try add("xl/worksheets/sheet1.xml", """
            <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>\(rows.joined())</sheetData></worksheet>
            """)
        if useSharedStrings {
            try add("xl/sharedStrings.xml", """
                <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
                <si><t>DNI</t></si><si><t>NOMBRES</t></si>
                <si><t>SEXO</t></si><si><t>ÁREA</t></si>
                <si><t>CARGO</t></si><si><t>EDAD</t></si>
                <si><t>UBIGEO</t></si>
                </sst>
                """)
        }
        return path
    }
    private let headings="""
        <row r="1">
        <c r="A1" t="s"><v>0</v></c>
        <c r="B1" t="s"><v>1</v></c>
        <c r="C1" t="s"><v>2</v></c>
        <c r="D1" t="s"><v>3</v></c>
        <c r="E1" t="s"><v>4</v></c>
        <c r="F1" t="s"><v>5</v></c>
        <c r="G1" t="s"><v>6</v></c>
        </row>
        """
    func testCompressedPERSONALWithSharedStringsAndInlineWorkers()throws {
        let input=headings+"""
        <row r="2">
            <c r="A2"><v>41728463</v></c>
            <c r="B2" t="inlineStr"><is><t>Mariana Torres Salazar</t></is></c>
            <c r="C2" t="inlineStr"><is><t>F</t></is></c>
            <c r="D2" t="inlineStr"><is><t>Empaque</t></is></c>
            <c r="E2" t="inlineStr"><is><t>Operaria</t></is></c>
            <c r="F2"><v>27</v></c>
            <c r="G2" t="inlineStr"><is><t>130101</t></is></c>
        </row>
        """
        let file=try makeWorkbook(rows:[input])
        defer{try? FileManager.default.removeItem(at:file)}
        let preview=try N2PersonalWorkbookReader.read(url:file)
        XCTAssertEqual(preview.stats.valid,1)
        XCTAssertTrue(preview.stats.canConfirm)
        let person=try XCTUnwrap(preview.workers.first)
        XCTAssertEqual(person.dni,"41728463")
        XCTAssertEqual(person.name,"Mariana Torres Salazar")
        XCTAssertEqual(person.area,"Empaque")
        XCTAssertEqual(person.sex,"F")
        XCTAssertEqual(person.age,"27")
        let created=try N2PersonalRosterImport.initialSnapshot(
            preview:preview,site:"PLVENTUROSA")
        let obj=try XCTUnwrap(JSONSerialization.jsonObject(with:created) as? [String:Any])
        for name in ["attentions","stockLots","stockMovements","catalogMappings",
                     "deliveryIncidents","ambulatoryReconciliation"] {
            XCTAssertTrue((obj[name] as? [Any])?.isEmpty==true)
        }
        XCTAssertTrue((obj["allergies"] as? [String:Any])?.isEmpty==true)
        let workers=try XCTUnwrap(obj["workers"] as? [[String:Any]])
        XCTAssertEqual(workers.first?["rosterStatus"] as? String,"official")
        XCTAssertEqual(workers.first?["site"] as? String,"PLVENTUROSA")
    }

    func testDoesNotGuessUnknownDNIOrOverwriteConflict()throws {
        let input=headings+"""
        <row r="2"><c r="A2"><v>41728463</v></c>
            <c r="B2" t="inlineStr"><is><t>Mariana Torres Salazar</t></is></c>
            <c r="C2" t="inlineStr"><is><t>F</t></is></c></row>
        <row r="3"><c r="A3"><v>41728463</v></c>
            <c r="B3" t="inlineStr"><is><t>Otra Persona Distinta</t></is></c>
            <c r="C3" t="inlineStr"><is><t>M</t></is></c></row>
        <row r="4"><c r="A4"><v>12</v></c>
            <c r="B4" t="inlineStr"><is><t>Nombre Invalido</t></is></c></row>
        """
        let path=try makeWorkbook(rows:[input])
        defer{try? FileManager.default.removeItem(at:path)}
        let imported=try N2PersonalWorkbookReader.read(url:path)
        XCTAssertEqual(imported.stats.duplicates,1)
        XCTAssertEqual(imported.stats.nameConflicts,1)
        XCTAssertEqual(imported.stats.sexConflicts,1)
        XCTAssertEqual(imported.stats.invalidDni,1)
        XCTAssertFalse(imported.stats.canConfirm)
        XCTAssertThrowsError(try N2PersonalRosterImport.initialSnapshot(
            preview:imported,site:"PLVENTUROSA"))
    }

    func testMissingPERSONALRejected()throws {
        let workbook=try makeWorkbook(rows:["<row r=\"1\"></row>"],
                                      includePersonal:false)
        defer{try? FileManager.default.removeItem(at:workbook)}
        XCTAssertThrowsError(try N2PersonalWorkbookReader.read(url:workbook)) {
            XCTAssertEqual($0 as? N2PersonalImportError,.missingPersonal)
        }
    }

    func testReimportPreservesEveryClinicalCollection()throws {
        let person=N2PersonalWorker(dni:"41728463",name:"Mariana Torres Salazar",
                                     area:"Empaque",labor:"Operaria",sex:"F")
        var stats=N2PersonalImportStats()
        stats.total=1;stats.valid=1
        let prev=N2PersonalImportPreview(workers:[person],stats:stats)
        let initial=try N2PersonalRosterImport.initialSnapshot(
            preview:prev,site:"PLVENTUROSA")
        let (same,result)=try N2PersonalRosterImport.merge(
            snapshot:initial,preview:prev,site:"PLVENTUROSA")
        XCTAssertEqual(same,initial)
        XCTAssertEqual(result.unchanged,1)
        XCTAssertEqual(result.added,0)
        let next=N2PersonalWorker(dni:"78654321",name:"Luis Paredes Rojas",
                                  area:"Campo",labor:"Operario",sex:"M")
        stats.valid=2;stats.total=2
        let update=N2PersonalImportPreview(workers:[person,next],stats:stats)
        let (merged,report)=try N2PersonalRosterImport.merge(
            snapshot:initial,preview:update,site:"PLVENTUROSA")
        XCTAssertEqual(report.added,1)
        XCTAssertEqual(report.after,2)
        let before=try XCTUnwrap(JSONSerialization.jsonObject(with:initial) as? [String:Any])
        let after=try XCTUnwrap(JSONSerialization.jsonObject(with:merged) as? [String:Any])
        for key in ["attentions","allergies","stockLots","stockMovements",
                    "catalogMappings","deliveryIncidents","ambulatoryReconciliation"] {
            XCTAssertEqual(try JSONSerialization.data(withJSONObject:before[key]!,
                                                        options:[.sortedKeys]),
                           try JSONSerialization.data(withJSONObject:after[key]!,
                                                        options:[.sortedKeys]))
        }
    }
}
