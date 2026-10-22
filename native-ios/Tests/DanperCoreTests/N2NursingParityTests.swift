import Foundation
import XCTest
@testable import DanperCore

final class N2NursingParityTests:XCTestCase {
    private func bytes(_ name:String)throws->Data {
        let root=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:root)
            .appendingPathComponent(name))
    }
    private func fixture()throws->([String:Any],Data) {
        let file=try XCTUnwrap(JSONSerialization.jsonObject(
            with:bytes("n2-nursing-parity.json")) as? [String:Any])
        return (file,try JSONSerialization.data(withJSONObject:file["catalog"]!))
    }
    func testKardexFromNinthAccumulatesDailyMovementsOnceAndZerosEmptyDays() throws {
        let snapshot=try bytes("n1e-clinical-stock.json")
        let (_,catalog)=try fixture()
        let accumulated=try N2NursingReportBuilder.range(
            snapshot:snapshot,catalog:catalog,
            start:"2026-10-09",end:"2026-10-22")
        XCTAssertEqual(accumulated.date,"2026-10-09")
        XCTAssertEqual(accumulated.periodEnd,"2026-10-22")
        XCTAssertEqual(accumulated.rows.count,98)
        let days=(9...22).map{String(format:"2026-10-%02d",$0)}
        let daily=try days.map{date in
            try N2NursingReportBuilder.daily(
                snapshot:snapshot,catalog:catalog,date:date)
        }
        for (index,row) in accumulated.rows.enumerated() {
            let actual=daily.reduce(0.0){$0+$1.rows[index].consumed}
            XCTAssertEqual(row.consumed,actual,accuracy:0.001,
                           "Consumo duplicado en "+row.code)
        }
        let emptyDay=try N2NursingReportBuilder.daily(
            snapshot:snapshot,catalog:catalog,date:"2026-10-19")
        XCTAssertTrue(emptyDay.rows.allSatisfy{$0.consumed==0})
        XCTAssertTrue(emptyDay.rows.filter{$0.stockKnown}.allSatisfy{$0.consumed==0})
    }

    func testNursingDailyAndRangeMatchBuild222TypeScriptByAll98Rows()throws {
        let source=try bytes("n1e-clinical-stock.json")
        let (reference,catalog)=try fixture()
        let scenarios=try XCTUnwrap(reference["scenarios"] as? [[String:Any]])
        XCTAssertEqual(scenarios.count,4)
        for caseRow in scenarios {
            let expected=try XCTUnwrap(caseRow["expected"] as? [String:Any])
            let kind=caseRow["kind"] as? String
            let report:N2NursingReport
            if kind=="day" {
                report=try N2NursingReportBuilder.daily(snapshot:source,catalog:catalog,
                            date:caseRow["date"] as! String)
            }else{
                report=try N2NursingReportBuilder.range(snapshot:source,catalog:catalog,
                            start:caseRow["start"] as! String,end:caseRow["end"] as! String)
            }
            let expectedRows=try XCTUnwrap(expected["rows"] as? [[String:Any]])
            XCTAssertEqual(report.rows.count,98)
            XCTAssertEqual(expectedRows.count,98)
            XCTAssertEqual(report.warnings,try XCTUnwrap(expected["warnings"] as? [String]))
            XCTAssertEqual(report.exportable,expected["exportable"] as? Bool)
            for (idx,r) in report.rows.enumerated() {
                let exp=expectedRows[idx]
                XCTAssertEqual(r.code,exp["code"] as? String,"row \(idx)")
                XCTAssertEqual(r.name,exp["name"] as? String,"row \(idx)")
                XCTAssertEqual(r.stockKnown,exp["stockKnown"] as? Bool,"row \(idx)")
                XCTAssertEqual(r.expiry,exp["expiry"] as? String,"row \(idx)")
                for (key,value) in [
                    ("initial",r.initial),("extraordinary",r.extraordinary),
                    ("total",r.total),("consumed",r.consumed),("final",r.closing)
                ] {
                    let reference=(exp[key] as? NSNumber)?.doubleValue
                    XCTAssertNotNil(reference,"Missing \(key) \(idx)")
                    if let reference {
                        XCTAssertEqual(value,reference,accuracy:0.001,
                                       "\(kind ?? "") row \(idx) \(key)")
                    }
                }
                if let expectedFS=exp["fs"] as? NSNumber {
                    XCTAssertEqual(try XCTUnwrap(r.fs),expectedFS.doubleValue,accuracy:0.001)
                }else{XCTAssertNil(r.fs)}
            }
        }
    }
    func testOnlyVerifiedDailyReportsCanProduceOfficialNursingWorkbook()throws {
        let source=try bytes("n1e-clinical-stock.json")
        let (_,catalog)=try fixture()
        let report=try N2NursingReportBuilder.daily(
            snapshot:source,catalog:catalog,date:"2026-10-14")
        if report.exportable {
            let data=try N1sNursingExcelWriter.export(
                base:bytes("n1s-nursing-template-store.zip"),
                manifest:report.manifest(shift:"CONSOLIDADO",
                                         responsible:"OPERADOR FICTICIO"))
            XCTAssertEqual(data.sheetCount,1)
            XCTAssertEqual(data.writtenRows,98)
            XCTAssertTrue(data.xlsx.starts(with:[0x50,0x4B,0x03,0x04]))
        }else {
            XCTAssertThrowsError(try report.manifest(
                shift:"CONSOLIDADO",responsible:"OPERADOR FICTICIO"))
        }
    }
    func testExportActualSnapshotToOfficialNursingXLSXWithUnknownBlanks() throws {
        let source=try bytes("n1e-clinical-stock.json")
        let (_,catalog)=try fixture()
        let template=try bytes("n1s-nursing-template-store.zip")
        let result=try N2VerifiedNursingWorkbook.export(
            snapshot:source,catalog:catalog,template:template,
            date:"2026-10-14",shift:"CONSOLIDADO",
            responsible:"OPERADOR FICTICIO")
        XCTAssertEqual(result.stockKnownRows,2)
        XCTAssertEqual(result.stockUnknownRows,96)
        XCTAssertTrue(result.xlsx.starts(with:[0x50,0x4B,0x03,0x04]))
        XCTAssertThrowsError(try N2VerifiedNursingWorkbook.export(
            snapshot:source,catalog:catalog,template:template,
            date:"2026-02-30",shift:"CONSOLIDADO",
            responsible:"OPERADOR FICTICIO"))
    }
    func testRosterOnlySourceExportsBlankUnknownStockWithoutInventingZeros()throws {
        let original=try bytes("n1e-clinical-stock.json")
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:original) as? [String:Any])
        let people=try XCTUnwrap(root["workers"] as? [[String:Any]])
        root["workers"]=Array(people.prefix(1))
        root["attentions"]=[[String:Any]]()
        root["allergies"]=[String:Any]()
        for key in ["stockLots","stockMovements","catalogMappings",
                    "deliveryIncidents","ambulatoryReconciliation"] {
            root[key]=[[String:Any]]()
        }
        let fresh=try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys])
        let (_,catalog)=try fixture()
        let book=try N2VerifiedNursingWorkbook.export(
            snapshot:fresh,catalog:catalog,
            template:bytes("n1s-nursing-template-store.zip"),
            date:"2026-10-14",shift:"CONSOLIDADO",
            responsible:"OPERADOR DE PRUEBA")
        XCTAssertEqual(book.stockKnownRows,0)
        XCTAssertEqual(book.stockUnknownRows,98)
        let archive=try N1rStoredZip.unpack(book.xlsx)
        XCTAssertFalse(archive.contains{$0.name=="xl/worksheets/sheet1.xml"})
        let excel=try XCTUnwrap(archive.first{$0.name=="xl/worksheets/sheet2.xml"})
        let xml=try XCTUnwrap(String(data:excel.data,encoding:.utf8))
        XCTAssertTrue(xml.contains("D7"))
        XCTAssertFalse(xml.contains("<c r=\"D7\"><v>0</v></c>"))
    }

    func testRangeIsAlwaysLabeledAsConsolidatedPeriod() throws {
        let source=try bytes("n1e-clinical-stock.json")
        let (_,catalog)=try fixture()
        let period=try N2NursingReportBuilder.range(
            snapshot:source,catalog:catalog,
            start:"2026-10-14",end:"2026-10-15")
        XCTAssertEqual(period.periodEnd,"2026-10-15")
        XCTAssertThrowsError(try period.manifest(
            shift:"MAÑANA",responsible:"OPERADOR FICTICIO")) {
            XCTAssertEqual($0 as? N2NursingReportError,.unsupportedRange)
        }
        if period.exportable {
            let manifest=try period.manifest(shift:"CONSOLIDADO",
                                             responsible:"OPERADOR FICTICIO")
            let obj=try XCTUnwrap(JSONSerialization.jsonObject(with:manifest) as? [String:Any])
            XCTAssertEqual(obj["date"] as? String,"2026-10-14")
            XCTAssertEqual(obj["periodEnd"] as? String,"2026-10-15")
        } else {
            XCTAssertThrowsError(try period.manifest(
                shift:"CONSOLIDADO",responsible:"OPERADOR FICTICIO")) {
                XCTAssertEqual($0 as? N2NursingReportError,.incompleteHistory)
            }
        }
    }
    func testAuditedRangeWritesConsolidatedDatesInNursingWorkbook()throws {
        let source=try bytes("n1e-clinical-stock.json")
        let (_,catalog)=try fixture()
        let template=try bytes("n1s-nursing-template-store.zip")
        let result=try N2VerifiedNursingWorkbook.exportRange(
            snapshot:source,catalog:catalog,template:template,
            start:"2026-10-14",end:"2026-10-14",
            responsible:"OPERADOR FICTICIO")
        XCTAssertEqual(result.stockKnownRows,2)
        XCTAssertEqual(result.stockUnknownRows,96)
        let entries=try N1rStoredZip.unpack(result.xlsx)
        let sheet=try XCTUnwrap(entries.first(where:{$0.name=="xl/worksheets/sheet2.xml"}))
        let xml=try XCTUnwrap(String(data:sheet.data,encoding:.utf8))
        XCTAssertTrue(xml.contains("PERÍODO CONSOLIDADO"))
        XCTAssertTrue(xml.contains("14/10/2026"))
    }
    func testInvalidPeriodsOrUnknownPhysicalCountsFailClosed()throws {
        let source=try bytes("n1e-clinical-stock.json")
        let (_,catalog)=try fixture()
        XCTAssertThrowsError(try N2NursingReportBuilder.daily(
            snapshot:source,catalog:catalog,date:"2026-02-30"))
        XCTAssertThrowsError(try N2NursingReportBuilder.range(
            snapshot:source,catalog:catalog,start:"2026-12-31",end:"2026-01-01"))
        XCTAssertThrowsError(try N2NursingReportBuilder.daily(
            snapshot:source,catalog:catalog,date:"2026-10-14",
            physicalCounts:["E-22":-1]))
    }
}
