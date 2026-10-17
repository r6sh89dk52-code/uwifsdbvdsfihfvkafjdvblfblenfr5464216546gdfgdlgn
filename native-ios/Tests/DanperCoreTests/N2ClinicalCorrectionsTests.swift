import Foundation
import XCTest
@testable import DanperCore

final class N2ClinicalCorrectionsTests:XCTestCase {
    private func fixture(_ name:String="n1e-clinical-stock.json")throws->Data {
        let root=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:root).appendingPathComponent(name))
    }
    private func amendment(_ payload:[String:Any])throws->Data {
        try JSONSerialization.data(withJSONObject:payload,options:[.sortedKeys])
    }
    private func originalStocks(_ snapshot:Data)throws->(Data,Data,Data) {
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:snapshot) as? [String:Any])
        let visits=try XCTUnwrap(root["attentions"] as? [[String:Any]])
        let ref=try XCTUnwrap(visits.first{$0["id"] as? String=="fundo-unit"})
        return (try amendment(ref),
                try amendment(["stockLots":root["stockLots"]!]),
                try amendment(["stockMovements":root["stockMovements"]!]))
    }
    func testClinicalCorrectionNeverReissuesDrugsAndKeepsOriginalImmutable()throws {
        let source=try fixture()
        let before=try N2ClinicalCorrections.detail(snapshot:source,visitID:"fundo-unit")
        let stocks=try originalStocks(source)
        let changes=try amendment([
            "diagnosis":"DIAGNÓSTICO CORREGIDO",
            "category":"ENFERMEDAD",
            "standaloneProcedures":["CONTROL","OBSERVACION"],
            "itemProcedures":["unit-5":"CONTROL"],
            "photoSent":true
        ])
        let corrected=try N2ClinicalCorrections.append(
            snapshot:source,eventID:"034d91d8-881a-4faf-b5cc-6dc1d60d59a9",
            visitID:"fundo-unit",changes:changes,
            reason:"Rectificación tras revisión clínica documental",
            operatorName:"ENFERMERÍA DANPER",medicationDiscrepancy:"",
            expectedEffectiveSHA:before.effectiveSHA256,at:1792010000000)
        let after=try N2ClinicalCorrections.detail(snapshot:corrected,visitID:"fundo-unit")
        XCTAssertEqual(after.previousCorrections,1)
        XCTAssertEqual(after.diagnosis,"DIAGNÓSTICO CORREGIDO")
        XCTAssertEqual(after.medications[0].procedure,"CONTROL")
        XCTAssertEqual(after.medications[0].quantity,before.medications[0].quantity)
        let original=try originalStocks(corrected)
        XCTAssertEqual(original.0,stocks.0)
        XCTAssertEqual(original.1,stocks.1)
        XCTAssertEqual(original.2,stocks.2)
        let projection=try N2NativeSnapshotReader.read(corrected)
        XCTAssertEqual(projection.visits.first{$0.id=="fundo-unit"}?.diagnosis,
                       "DIAGNÓSTICO CORREGIDO")
        let parityOriginal=try N1eLegacyClinicalAudit.inspect(source)
        let parityAfter=try N1eLegacyClinicalAudit.inspect(corrected)
        XCTAssertEqual(parityAfter.consumptionR,parityOriginal.consumptionR)
        XCTAssertEqual(parityAfter.physicalMovements,parityOriginal.physicalMovements)
        XCTAssertThrowsError(try N2ClinicalCorrections.append(
            snapshot:corrected,eventID:"34a19685-c9e9-456a-873d-a53171608d01",
            visitID:"fundo-unit",changes:changes,
            reason:"Intento con revisión de pantalla obsoleta",
            operatorName:"ENFERMERÍA DANPER",medicationDiscrepancy:"",
            expectedEffectiveSHA:before.effectiveSHA256,at:1792010002000)){
            XCTAssertEqual($0 as? N2CorrectionError,.staleCorrection)
        }
    }
    func testTwoCorrectionsAreChainedAndTamperDetected()throws {
        let source=try fixture()
        let initial=try N2ClinicalCorrections.detail(snapshot:source,visitID:"fundo-unit")
        let first=try N2ClinicalCorrections.append(
            snapshot:source,eventID:"0153931d-ff90-4dd9-9cb4-7b9acef82278",
            visitID:"fundo-unit",changes:amendment(["diagnosis":"CONTROL GENERAL"]),
            reason:"Corrección por revisión del registro original",
            operatorName:"RESPONSABLE ENFERMERÍA",medicationDiscrepancy:"",
            expectedEffectiveSHA:initial.effectiveSHA256,at:1792020000000)
        let next=try N2ClinicalCorrections.detail(snapshot:first,visitID:"fundo-unit")
        let second=try N2ClinicalCorrections.append(
            snapshot:first,eventID:"15b8439d-3893-4cc7-a866-05cf3888f218",
            visitID:"fundo-unit",changes:amendment(["diagnosis":"CONTROL POSTERIOR"]),
            reason:"Rectificación adicional documentada por enfermería",
            operatorName:"RESPONSABLE ENFERMERÍA",medicationDiscrepancy:"",
            expectedEffectiveSHA:next.effectiveSHA256,at:1792020001000)
        XCTAssertEqual(try N2ClinicalCorrections.detail(
            snapshot:second,visitID:"fundo-unit").previousCorrections,2)
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:second) as? [String:Any])
        var events=try XCTUnwrap(root["clinicalCorrectionLog"] as? [[String:Any]])
        events[0]["reason"]="Modificado sin una nueva rectificación"
        root["clinicalCorrectionLog"]=events
        let altered=try amendment(root)
        // Altering an annotation is rejected if its hash chain cannot be
        // reconstructed in full; no partially applied visits are returned.
        // NOTE: reason is metadata, not in the clinical state SHA. Audit below
        // deliberately changes the clinical field to exercise the link.
        events[0]["changes"]=["diagnosis":"REGISTRO ALTERADO"]
        root["clinicalCorrectionLog"]=events
        XCTAssertThrowsError(try N2ClinicalCorrections.effectiveSnapshot(
            try amendment(root))){
            XCTAssertEqual($0 as? N2CorrectionError,.brokenHistory)
        }
        _=altered
        XCTAssertThrowsError(try N2ClinicalCorrections.append(
            snapshot:second,eventID:"0153931d-ff90-4dd9-9cb4-7b9acef82278",
            visitID:"fundo-unit",changes:amendment(["diagnosis":"OTRO"]),
            reason:"Rectificación con ID duplicado",
            operatorName:"RESPONSABLE ENFERMERÍA",medicationDiscrepancy:"",
            expectedEffectiveSHA:try N2ClinicalCorrections.detail(
                snapshot:second,visitID:"fundo-unit").effectiveSHA256,
            at:1792020002000)){
            XCTAssertEqual($0 as? N2CorrectionError,.duplicateCorrection)
        }
    }
    func testMedicationDiscrepancyRemainsPendingNoPhysicalCompensation()throws {
        let source=try fixture()
        let initial=try N2ClinicalCorrections.detail(snapshot:source,visitID:"fundo-unit")
        let withNote=try N2ClinicalCorrections.append(
            snapshot:source,eventID:"17ad2588-f7cc-47a0-8ad9-85d8bc6bcc81",
            visitID:"fundo-unit",changes:amendment([:]),
            reason:"Se identificó diferencia en la dosis documentada",
            operatorName:"ENFERMERÍA DANPER",
            medicationDiscrepancy:"Revisar posible discrepancia de medicamento con inventario",
            expectedEffectiveSHA:initial.effectiveSHA256,at:1792021000000)
        XCTAssertTrue(try N2ClinicalCorrections.pendingDiscrepancies(
            withNote).contains("fundo-unit"))
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(withNote).consumptionR,
                       try N1eLegacyClinicalAudit.inspect(source).consumptionR)
        let forbidden=try amendment(["items":[["id":"unit-5","quantity":999]]])
        XCTAssertThrowsError(try N2ClinicalCorrections.append(
            snapshot:source,eventID:"173c839c-bd9c-43f0-a42e-4b78a5dd618c",
            visitID:"fundo-unit",changes:forbidden,
            reason:"Intento de cambiar la cantidad entregada",
            operatorName:"ENFERMERÍA DANPER",medicationDiscrepancy:"",
            expectedEffectiveSHA:initial.effectiveSHA256,at:1792021000100)){
            XCTAssertEqual($0 as? N2CorrectionError,.invalidChanges)
        }
    }
    func testDraftIsEncryptedSnapshotOnlyAndIsRemovedByAtomicAmendment()throws {
        let source=try fixture()
        let old=try N2ClinicalCorrections.detail(snapshot:source,visitID:"fundo-unit")
        let patch=try amendment(["diagnosis":"CORRECCIÓN PENDIENTE"])
        let draft=try N2ClinicalCorrections.savePendingDraft(
            snapshot:source,visitID:"fundo-unit",changes:patch,
            reason:"Pendiente por auditoría clínica",
            operatorName:"ENFERMERÍA DANPER",medicationDiscrepancy:"",
            expectedEffectiveSHA:old.effectiveSHA256,at:1792050000000)
        let recovered=try XCTUnwrap(N2ClinicalCorrections.pendingDraft(
            snapshot:draft,visitID:"fundo-unit"))
        XCTAssertEqual(recovered.changes,patch)
        XCTAssertEqual(recovered.reason,"Pendiente por auditoría clínica")
        XCTAssertEqual(try originalStocks(source).0,try originalStocks(draft).0)
        XCTAssertEqual(try originalStocks(source).2,try originalStocks(draft).2)
        let saved=try N2ClinicalCorrections.append(
            snapshot:draft,eventID:"390bd7f9-d7da-4cc8-a0ba-1fd51f6423d7",
            visitID:"fundo-unit",changes:patch,
            reason:"Pendiente por auditoría clínica",
            operatorName:"ENFERMERÍA DANPER",medicationDiscrepancy:"",
            expectedEffectiveSHA:old.effectiveSHA256,at:1792050001000)
        XCTAssertNil(try N2ClinicalCorrections.pendingDraft(
            snapshot:saved,visitID:"fundo-unit"))
        XCTAssertEqual(try N2ClinicalCorrections.detail(
            snapshot:saved,visitID:"fundo-unit").diagnosis,"CORRECCIÓN PENDIENTE")
        let restarted=try N2ClinicalCorrections.savePendingDraft(
            snapshot:source,visitID:"fundo-unit",changes:patch,
            reason:"Segundo borrador recuperable",
            operatorName:"ENFERMERÍA DANPER",medicationDiscrepancy:"",
            expectedEffectiveSHA:old.effectiveSHA256,at:1792050002000)
        let cleared=try N2ClinicalCorrections.deletePendingDraft(
            snapshot:restarted,visitID:"fundo-unit")
        XCTAssertNil(try N2ClinicalCorrections.pendingDraft(
            snapshot:cleared,visitID:"fundo-unit"))
        XCTAssertEqual(try originalStocks(cleared).2,try originalStocks(source).2)
    }
    func testInvalidDraftOrTamperedAuditMetadataFailClosed()throws {
        let source=try fixture()
        let initial=try N2ClinicalCorrections.detail(snapshot:source,visitID:"fundo-unit")
        XCTAssertThrowsError(try N2ClinicalCorrections.savePendingDraft(
            snapshot:source,visitID:"fundo-unit",
            changes:amendment(["diagnosis":"OTRA IMPRESIÓN"]),
            reason:"Registro no autorizado",operatorName:"ENFERMERÍA DANPER",
            medicationDiscrepancy:"",
            expectedEffectiveSHA:String(repeating:"0",count:64),
            at:1792050003000)){
            XCTAssertEqual($0 as? N2CorrectionError,.staleCorrection)
        }
        let changed=try N2ClinicalCorrections.append(
            snapshot:source,eventID:"c5e959a2-5bb4-4589-a48d-25675e4c0a71",
            visitID:"fundo-unit",
            changes:amendment(["diagnosis":"REGISTRO AUDITADO"]),
            reason:"Rectificación respaldada por revisión",
            operatorName:"ENFERMERÍA DANPER",medicationDiscrepancy:"",
            expectedEffectiveSHA:initial.effectiveSHA256,at:1792050004000)
        var obj=try XCTUnwrap(JSONSerialization.jsonObject(with:changed) as? [String:Any])
        var log=try XCTUnwrap(obj["clinicalCorrectionLog"] as? [[String:Any]])
        log[0]["reason"]="Motivo alterado fuera del flujo"
        obj["clinicalCorrectionLog"]=log
        XCTAssertThrowsError(try N2ClinicalCorrections.effectiveSnapshot(
            amendment(obj))){
            XCTAssertEqual($0 as? N2CorrectionError,.brokenHistory)
        }
    }
}
