import Foundation
import XCTest
@testable import DanperCore

final class N2RealIndicatorWorkbookTests:XCTestCase {
    private func withPlantBottleCounts(_ events:[[String:Any]])->[[String:Any]] {
        events + events.filter {
            ["opening","count"].contains($0["kind"] as? String ?? "")
        }.map { original in
            var event=original
            event["id"]=(original["id"] as! String)+"-bottle"
            event["code"]="16000013"
            event["quantity"]=(original["kind"] as? String)=="opening" ? 2 : 1
            return event
        }
    }
    func testMissingSiteCanBeConfirmedForOneVisitAndExportedOfficially()throws {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        var visits=try XCTUnwrap(root["attentions"] as? [[String:Any]])
        let index=try XCTUnwrap(visits.firstIndex{$0["id"] as? String=="fundo-unit"})
        var worker=try XCTUnwrap(visits[index]["worker"] as? [String:Any])
        worker["site"]=""
        visits[index]["worker"]=worker
        root["attentions"]=visits
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-reviewed-expected.json")) as? [String:Any])
        root["ambulatoryReconciliation"]=proof["events"]!
        let source=try JSONSerialization.data(withJSONObject:root)
        let catalog=try JSONSerialization.data(withJSONObject:proof["catalog"]!)
        let mappings=try fixture("n2-reviewed-approved.json")
        let template=try fixture("n1s-indicator-template-store.zip")
        let ids:Set<String>=["fundo-unit","fundo-reuse"]
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:source,products:catalog,mappings:mappings,template:template,
            start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",selectedVisitIDs:ids)) {
            XCTAssertEqual($0 as? N2VerifiedIndicatorWorkbook.Failure,.invalidVisit)
        }
        let detail=try N2ClinicalCorrections.detail(snapshot:source,visitID:"fundo-unit")
        let amended=try N2ClinicalCorrections.append(
            snapshot:source,eventID:"534BA0DE-2CFA-4BC1-9BA7-DCB302DDCB0A",
            visitID:"fundo-unit",
            changes:JSONSerialization.data(withJSONObject:[
                "visitWorkerSite":"LA VENTUROSA"
            ]),reason:"Sede confirmada para la atención original",
            operatorName:"RESPONSABLE DE ENFERMERÍA",medicationDiscrepancy:"",
            expectedEffectiveSHA:detail.effectiveSHA256,at:1792060000000)
        let exported=try N2VerifiedIndicatorWorkbook.export(
            snapshot:amended,products:catalog,mappings:mappings,template:template,
            start:"2026-10-09",end:"2026-11-08",
            subdivision:"LA VENTUROSA",selectedVisitIDs:ids)
        XCTAssertEqual(exported.visits,2)
        XCTAssertEqual(exported.rows,2)
        let parts=try N1rStoredZip.unpack(exported.xlsx)
        XCTAssertEqual(parts.filter{$0.name.hasPrefix("xl/worksheets/sheet") &&
            $0.name.hasSuffix(".xml")}.count,10)
        let ledger=try XCTUnwrap(JSONSerialization.jsonObject(
            with:amended) as? [String:Any])
        XCTAssertEqual(try JSONSerialization.data(
            withJSONObject:root["stockMovements"]!,options:[.sortedKeys]),
            try JSONSerialization.data(
            withJSONObject:ledger["stockMovements"]!,options:[.sortedKeys]))
    }

    func testProvisionalAllVisitsKeepsPendingContainerWithoutInventingR() throws {
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1e-clinical-stock.json")) as? [String:Any])
        var visits=try XCTUnwrap(snapshot["attentions"] as? [[String:Any]])
        let boxVisit=try XCTUnwrap(visits.first {
            $0["id"] as? String=="planta-open"
        })
        let boxItem=try XCTUnwrap((boxVisit["items"] as? [[String:Any]])?.first)
        let idx=try XCTUnwrap(visits.firstIndex {
            $0["id"] as? String=="pending-stock"
        })
        var pendingItem=try XCTUnwrap((visits[idx]["items"] as? [[String:Any]])?.first)
        for key in ["code","name","unit"] {pendingItem[key]=boxItem[key]}
        pendingItem["quantity"]=1
        pendingItem.removeValue(forKey:"physicalUse")
        visits[idx]["items"]=[pendingItem]
        snapshot["attentions"]=visits
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1q-reviewed-expected.json")) as? [String:Any])
        let catalog=try JSONSerialization.data(withJSONObject:proof["catalog"]!)
        let selected=Set(visits.compactMap{$0["id"] as? String})
        let source=try JSONSerialization.data(withJSONObject:snapshot)
        let mappings=try fixture("n2-reviewed-approved.json")
        let template=try fixture("n1s-indicator-template-store.zip")
        let provisional=try N2VerifiedIndicatorWorkbook.export(
            snapshot:source,products:catalog,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"AMBAS",selectedVisitIDs:selected,allowPending:true)
        XCTAssertTrue(provisional.provisional)
        XCTAssertEqual(provisional.visits,5)
        XCTAssertEqual(provisional.rows,5)
        XCTAssertGreaterThanOrEqual(provisional.pendingLines,1)
        let parts=try N1rStoredZip.unpack(provisional.xlsx)
        XCTAssertEqual(parts.filter{$0.name.hasPrefix("xl/worksheets/sheet") &&
            $0.name.hasSuffix(".xml")}.count,10)
        let sheet=try XCTUnwrap(String(data:try XCTUnwrap(
            parts.first{$0.name=="xl/worksheets/sheet5.xml"}).data,
            encoding:.utf8))
        // Find the synthetic worker's exported row; the R column MUST
        // be empty (unknown), not zero (reuse) or one (new opening).
        let rows=sheet.components(separatedBy:"</row>")
        let pendingRow=try XCTUnwrap(rows.first{$0.contains("00000005")})
        XCTAssertNotNil(pendingRow.range(
            of:#"<c r="R[0-9]+"[^>]*/>"#,
            options:.regularExpression))
        let notes=try XCTUnwrap(String(data:try XCTUnwrap(
            parts.first{$0.name=="xl/worksheets/sheet6.xml"}).data,
            encoding:.utf8))
        XCTAssertTrue(notes.contains("R PENDIENTE"))
        // The same unknown package still blocks the official export.
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.export(
            snapshot:source,products:catalog,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"AMBAS",selectedVisitIDs:selected,allowPending:false))
    }
    func testProvisionalHistoricalROnlyWithCompatibleLotAndNoPhysicalDoubleCount() {
        let r1=N2PendingDispensingEvidence(
            visitID:"sample-visit",itemID:"sample-item",lotID:"lot-real",
            quantity:0,confirmNewContainer:true,operatorName:"ENFERMERIA",
            reason:"Apertura histórica declarada",at:1792886400000,
            newContainers:1)
        let r0=N2PendingDispensingEvidence(
            visitID:"sample-visit-2",itemID:"sample-item",lotID:"lot-real",
            quantity:0,confirmNewContainer:false,operatorName:"ENFERMERIA",
            reason:"Reutilización histórica declarada",at:1792886400000,
            newContainers:0)
        let allowed:Set<String>=["E-57"]
        func r(_ record:N2PendingDispensingEvidence,
               lot:String="E-57",unit:String="CJA",linked:Bool=false)->Int? {
            N2VerifiedIndicatorWorkbook.provisionalHistoricalR(
                record,lotCode:lot,lotUnit:unit,
                approvedCodes:allowed,alreadyLinked:linked)
        }
        XCTAssertEqual(r(r1),1)
        XCTAssertEqual(r(r0),0)
        XCTAssertNil(r(r1,lot:"E-999"))
        XCTAssertNil(r(r1,unit:"UND"))
        XCTAssertNil(r(r1,linked:true))
    }
    func testSingleInventoryCutGuardDoesNotRequireTwoSiteReviews() {
        let all:Set<String>=["fundo-1","planta-1"]
        XCTAssertTrue(N2VerifiedIndicatorWorkbook.eligibleForSharedClose(
            subdivision:"AMBAS",start:"2026-10-09",end:"2026-11-08",
            today:"2026-11-09",selected:all,all:all,
            hasUnresolvedHistory:false))
        XCTAssertFalse(N2VerifiedIndicatorWorkbook.eligibleForSharedClose(
            subdivision:"AMBAS",start:"2026-10-09",end:"2026-11-08",
            today:"2026-10-24",selected:all,all:all,
            hasUnresolvedHistory:false))
        XCTAssertFalse(N2VerifiedIndicatorWorkbook.eligibleForSharedClose(
            subdivision:"AMBAS",start:"2026-10-09",end:"2026-10-24",
            today:"2026-10-24",selected:all,all:all,
            hasUnresolvedHistory:false))
        XCTAssertFalse(N2VerifiedIndicatorWorkbook.eligibleForSharedClose(
            subdivision:"AMBAS",start:"2026-10-09",end:"2026-11-08",
            today:"2026-11-09",selected:["fundo-1"],all:all,
            hasUnresolvedHistory:false))
        XCTAssertFalse(N2VerifiedIndicatorWorkbook.eligibleForSharedClose(
            subdivision:"AMBAS",start:"2026-10-09",end:"2026-11-08",
            today:"2026-11-09",selected:all,all:all,
            hasUnresolvedHistory:true))
    }
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
        snapshot["ambulatoryReconciliation"]=withPlantBottleCounts(events)
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
        XCTAssertEqual(x.missingOpening,430)
        XCTAssertEqual(x.missingClosingCount,430)
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
        snapshot["ambulatoryReconciliation"]=base+withPlantBottleCounts(planta)
        let verified=try JSONSerialization.data(withJSONObject:snapshot)
        let result=try N2VerifiedIndicatorWorkbook.export(
            snapshot:verified,products:products,mappings:mappings,
            template:template,start:"2026-10-09",end:"2026-11-08",
            subdivision:"AMBAS",selectedVisitIDs:ids)
        XCTAssertEqual(result.visits,4)
        XCTAssertEqual(result.rows,4)
        XCTAssertFalse(result.provisional)
        XCTAssertEqual(result.missingOpening,430)
        XCTAssertEqual(result.missingClosingCount,430)
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
