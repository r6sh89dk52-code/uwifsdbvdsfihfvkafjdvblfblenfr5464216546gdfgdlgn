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
    func testRangeCannotMasqueradeAsOfficialSingleDayWorkbook() throws {
        let source=try bytes("n1e-clinical-stock.json")
        let (_,catalog)=try fixture()
        let period=try N2NursingReportBuilder.range(
            snapshot:source,catalog:catalog,
            start:"2026-10-14",end:"2026-10-15")
        XCTAssertEqual(period.periodEnd,"2026-10-15")
        XCTAssertThrowsError(try period.manifest(
            shift:"CONSOLIDADO",responsible:"OPERADOR FICTICIO")) {
            XCTAssertEqual($0 as? N2NursingReportError,.unsupportedRange)
        }
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
