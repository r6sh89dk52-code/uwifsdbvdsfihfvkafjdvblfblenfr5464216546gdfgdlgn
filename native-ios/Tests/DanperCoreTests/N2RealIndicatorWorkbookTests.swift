import Foundation
import XCTest
@testable import DanperCore

final class N2RealIndicatorWorkbookTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:dir).appendingPathComponent(name))
    }
    func testPlantSiteUsesSameOfficialTenSheetTemplateAfterReview() throws {
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-reviewed-expected.json")) as? [String:Any])
        let events:[[String:Any]]=[
          ["id":"n2-pl-open","kind":"opening","subdivision":"PLVENTUROSA",
           "code":"16000182","date":"2026-10-09","at":1791504000000,
           "quantity":22,"reason":"Conteo verificado",
           "document":"","expires":"","periodEnd":"","voidOf":""],
          ["id":"n2-pl-count","kind":"count","subdivision":"PLVENTUROSA",
           "code":"16000182","date":"2026-11-08","at":1794182400000,
           "quantity":10,"reason":"Conteo verificado",
           "document":"","expires":"","periodEnd":"","voidOf":""],
          ["id":"n2-pl-review","kind":"review","subdivision":"PLVENTUROSA",
           "code":"","date":"2026-10-09","at":1794182400100,
           "quantity":0,"reason":"Cierre revisado",
           "document":"","expires":"","periodEnd":"2026-11-08","voidOf":""]
        ]
        snapshot["ambulatoryReconciliation"]=events
        let raw=try JSONSerialization.data(withJSONObject:snapshot)
        let catalog=try JSONSerialization.data(withJSONObject:proof["catalog"]!)
        let x=try N2VerifiedIndicatorWorkbook.export(
            snapshot:raw,products:catalog,
            mappings:fixture("n2-reviewed-approved.json"),
            template:fixture("n1s-indicator-template-store.zip"),
            start:"2026-10-09",end:"2026-11-08",
            subdivision:"PLVENTUROSA",
            selectedVisitIDs:Set(["planta-open","planta-tablet-carton"]))
        XCTAssertEqual(x.visits,2)
        XCTAssertEqual(x.rows,2)
        XCTAssertEqual(x.missingOpening,431)
        XCTAssertEqual(x.missingClosingCount,431)
    }
    func testJointFundoAndPlantaIndicatorRequiresBothReconciledPeriods()throws {
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-reviewed-expected.json")) as? [String:Any])
        let base=try XCTUnwrap(proof["events"] as? [[String:Any]])
        let planta:[[String:Any]]=[
            ["id":"joint-pl-open","kind":"opening","subdivision":"PLVENTUROSA",
             "code":"16000182","date":"2026-10-09","at":1791504000000,
             "quantity":22,"reason":"Inventario inicial de prueba","document":"",
             "expires":"","periodEnd":"","voidOf":""],
            ["id":"joint-pl-close","kind":"count","subdivision":"PLVENTUROSA",
             "code":"16000182","date":"2026-11-08","at":1794182400000,
             "quantity":10,"reason":"Recuento final de prueba","document":"",
             "expires":"","periodEnd":"","voidOf":""],
            ["id":"joint-pl-reviewed","kind":"review","subdivision":"PLVENTUROSA",
             "code":"","date":"2026-10-09","at":1794182400200,
             "quantity":0,"reason":"Cierre físico verificado","document":"",
             "expires":"","periodEnd":"2026-11-08","voidOf":""]
        ]
        let ids:Set<String>=["fundo-unit","fundo-reuse",
                              "planta-open","planta-tablet-carton"]
        let products=try JSONSerialization.data(withJSONObject:proof["catalog"]!)
        let mappings=try fixture("n2-reviewed-approved.json")
        let template=try fixture("n1s-indicator-template-store.zip")
        // The old one-site evidence cannot be relabeled as "BOTH".
        snapshot["ambulatoryReconciliation"]=base
        let partial=try JSONSerialization.data(withJSONObject:snapshot)
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:partial,products:products,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"AMBAS",selectedVisitIDs:ids)) {
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,
                           .unreviewedPeriod)
        }
        snapshot["ambulatoryReconciliation"]=base+planta
        let verified=try JSONSerialization.data(withJSONObject:snapshot)
        let result=try N2VerifiedIndicatorWorkbook.export(
            snapshot:verified,products:products,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"AMBAS",selectedVisitIDs:ids)
        XCTAssertEqual(result.visits,4)
        XCTAssertEqual(result.rows,4)
        XCTAssertFalse(result.provisional)
        XCTAssertEqual(result.missingOpening,431)
        XCTAssertEqual(result.missingClosingCount,431)
        let entries=try N1rStoredZip.unpack(result.xlsx)
        let sheet=try XCTUnwrap(entries.first(where:{$0.name=="xl/worksheets/sheet5.xml"}))
        let xml=try XCTUnwrap(String(data:sheet.data,encoding:.utf8))
        XCTAssertTrue(xml.contains("LA VENTUROSA"))
        XCTAssertTrue(xml.contains("PLVENTUROSA"))
        XCTAssertEqual(entries.filter{$0.name.hasPrefix("xl/worksheets/sheet") &&
                                      $0.name.hasSuffix(".xml")}.count,10)
    }

    func testReviewedPeriodVoidedRequiresNewClosingReview()throws {
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-voided-expected.json")) as? [String:Any])
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        snapshot["ambulatoryReconciliation"]=proof["events"]!
        let source=try JSONSerialization.data(withJSONObject:snapshot)
        let products=try JSONSerialization.data(withJSONObject:proof["catalog"]!)
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:source,products:products,
            mappings:fixture("n2-reviewed-approved.json"),
            template:fixture("n1s-indicator-template-store.zip"),
            start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",
            selectedVisitIDs:Set(["fundo-unit","fundo-reuse"]))) {
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,
                           .unreviewedPeriod)
        }
    }
    func testAmendedClinicalDiagnosisAppearsInOfficialExcelWithoutSecondStockIssue() throws {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-reviewed-expected.json")) as? [String:Any])
        root["ambulatoryReconciliation"]=proof["events"]
        let source=try JSONSerialization.data(withJSONObject:root)
        let detail=try N2ClinicalCorrections.detail(snapshot:source,visitID:"fundo-unit")
        let changed=try N2ClinicalCorrections.append(
            snapshot:source,eventID:"ec7d8bc4-19d9-4cab-a9bf-088df8f0b22d",
            visitID:"fundo-unit",
            changes:JSONSerialization.data(withJSONObject:[
                "diagnosis":"RECTIFICACION_XLSX_VERIFICADA",
                "itemProcedures":["unit-5":"CONTROL"]
            ]),
            reason:"Rectificación de diagnóstico y procedimiento",
            operatorName:"RESPONSABLE DANPER",medicationDiscrepancy:"",
            expectedEffectiveSHA:detail.effectiveSHA256,at:1792060000000)
        let before=try N1eLegacyClinicalAudit.inspect(source)
        let after=try N1eLegacyClinicalAudit.inspect(changed)
        XCTAssertEqual(after.consumptionR,before.consumptionR)
        XCTAssertEqual(after.physicalMovements,before.physicalMovements)
        let catalog=try JSONSerialization.data(withJSONObject:proof["catalog"]!)
        let map=try fixture("n2-reviewed-approved.json")
        let template=try fixture("n1s-indicator-template-store.zip")
        let ids:Set<String>=["fundo-unit","fundo-reuse"]
        let result=try N2VerifiedIndicatorWorkbook.export(
            snapshot:changed,products:catalog,mappings:map,template:template,
            start:"2026-10-09",end:"2026-11-08",subdivision:"LA VENTUROSA",
            selectedVisitIDs:ids)
        XCTAssertEqual(result.rows,2)
        let sheet=try XCTUnwrap(N1rStoredZip.unpack(result.xlsx)
            .first(where:{$0.name=="xl/worksheets/sheet5.xml"}))
        let xml=try XCTUnwrap(String(data:sheet.data,encoding:.utf8))
        XCTAssertTrue(xml.contains("RECTIFICACION_XLSX_VERIFICADA"))
        let current=try N2ClinicalCorrections.detail(snapshot:changed,visitID:"fundo-unit")
        let disputed=try N2ClinicalCorrections.append(
            snapshot:changed,eventID:"659ece9f-b1db-483c-8fd7-50e8422ae454",
            visitID:"fundo-unit",changes:JSONSerialization.data(
                withJSONObject:[:]),
            reason:"Aclaración de cantidad real pendiente de revisión",
            operatorName:"RESPONSABLE DANPER",
            medicationDiscrepancy:"Se requiere conciliación de la dosis administrada",
            expectedEffectiveSHA:current.effectiveSHA256,at:1792060001000)
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:disputed,products:catalog,mappings:map,template:template,
            start:"2026-10-09",end:"2026-11-08",subdivision:"LA VENTUROSA",
            selectedVisitIDs:ids)){
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,.unverifiedDelivery)
        }
    }
    func testTenSheetWriterRejectsUnreviewedAndPendingPhysical()throws {
        let expected=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-reviewed-expected.json")) as? [String:Any])
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        let catalog=try JSONSerialization.data(withJSONObject:expected["catalog"]!)
        let template=try fixture("n1s-indicator-template-store.zip")
        let mappings=try fixture("n2-reviewed-approved.json")
        let ids=Set(try XCTUnwrap(expected["selectedVisitIDs"] as? [String]))
        let unreviewed=try JSONSerialization.data(withJSONObject:snapshot)
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:unreviewed,products:catalog,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",selectedVisitIDs:ids)) {
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,.unreviewedPeriod)
        }
        snapshot["ambulatoryReconciliation"]=expected["events"]!
        let active=try JSONSerialization.data(withJSONObject:snapshot)
        let result=try N2VerifiedIndicatorWorkbook.export(
            snapshot:active,products:catalog,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",selectedVisitIDs:ids)
        XCTAssertEqual(result.rows,2)
        XCTAssertEqual(result.visits,2)
        XCTAssertEqual(result.missingOpening,429)
        XCTAssertEqual(result.missingClosingCount,429)
        XCTAssertTrue(result.xlsx.starts(with:[0x50,0x4B,0x03,0x04]))
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:active,products:catalog,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",
            selectedVisitIDs:ids.union(["pending-stock"]))) {
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,.unverifiedDelivery)
        }
    }
}
