import XCTest
import Foundation
@testable import DanperCore

final class N2NativeClinicalFormTests:XCTestCase {
    private func source(_ name:String)throws->Data {
        let root=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:root).appendingPathComponent(name))
    }
    private func catalog()throws->N2NativeCatalogIndex {
        let plan=try XCTUnwrap(JSONSerialization.jsonObject(
            with:source("n1s-indicator-plan.json")) as? [String:Any])
        let nurse=try XCTUnwrap(JSONSerialization.jsonObject(
            with:source("n2-nursing-parity.json")) as? [String:Any])
        let products=try JSONSerialization.data(withJSONObject:plan["catalog"]!)
        let nursing=try JSONSerialization.data(withJSONObject:nurse["catalog"]!)
        return try N2NativeCatalogLoader.load(products:products,nursing:nursing,
                     approvedMappings:source("n2-reviewed-approved.json"))
    }
    func testNursingCatalogUsesOnlyApprovedPresentationWithoutExposingUserCodes()throws {
        let catalog=try self.catalog()
        XCTAssertEqual(catalog.nursing.count,98)
        XCTAssertEqual(catalog.approvals.count,86)
        let clinicalUnits=Dictionary(uniqueKeysWithValues:catalog.clinical.map {
            ($0.code,$0.unit)
        })
        for link in catalog.approvals {
            let item=try XCTUnwrap(catalog.nursing.first{$0.id==link.kardexID})
            let expectedUnit:String?
            if item.group=="TABLETAS" || item.id=="E-18" {
                expectedUnit="UND"
            } else if ["E-94","E-95"].contains(item.id) {
                expectedUnit="CJA"
            } else {
                expectedUnit=clinicalUnits[link.clinicalCode]
            }
            XCTAssertEqual(item.unit,expectedUnit)
        }
        XCTAssertEqual(catalog.nursing.first{$0.id=="E-1"}?.unit,"UND")
        XCTAssertEqual(catalog.nursing.first{$0.id=="E-86"}?.name,"ALCOHOL 1 LT")
        XCTAssertEqual(catalog.nursing.first{$0.id=="E-86"}?.unit,"FCO")
        // No approved correspondence for nylon: do not fabricate UND.
        XCTAssertNil(catalog.nursing.first{$0.id=="E-68"}?.unit)
        XCTAssertEqual(catalog.nursingMatches("ALCOHOL 1 LT").first?.name,
                       "ALCOHOL 1 LT")
        XCTAssertTrue(catalog.nursingMatches("E-86").isEmpty)
    }

    private func at()->Int64 {
        Int64(ISO8601DateFormatter().date(from:"2026-10-14T18:00:00Z")!
            .timeIntervalSince1970*1000)
    }
    private func form(with products:Bool=true,reviewed:Bool=true)throws->(N2NativeFormDraft,N2FormContext) {
        let snapshot=try source("n1e-clinical-stock.json")
        let approved=reviewed
            ? try N2SnapshotEditor.reviewAllergies(snapshot:snapshot,
                dni:"00000001",status:"none",substances:"",at:at())
            : snapshot
        let context=try N2NativeFormContextReader.read(
                snapshot:approved,revision:7,products:catalog())
        var draft=N2NativeFormDraft(id:"n2-form-\(products ? "product" : "procedure")")
        draft.dni="00000001"
        draft.date="2026-10-14"
        draft.time="13:00"
        draft.category="ENFERMEDAD"
        draft.system="RESPIRATORIO"
        draft.diagnosis="DX FICTICIO PARA PARIDAD"
        draft.responsible="OPERADOR FICTICIO"
        draft.procedures=["OBSERVACION"]
        if products {draft.items=[N2FormMedication(id:"unit-new",
            code:"16000182",quantity:2,procedure:"OBSERVACION")]}
        return(draft,context)
    }
    func testHistoricOptionsIncludeDocumentedEmptyBottlesWithoutFEFOAvailability()throws {
        let catalog=try self.catalog()
        let old=N2FormLot(id:"empty-lot-history",kardexCode:"E-86",
                          name:"ALCOHOL 1 LT",unit:"FCO",expires:"",
                          capacity:1000,sealed:0,loose:0,opened:0)
        let context=N2FormContext(revision:1,workers:[],allergies:[:],
                                  lots:[old],products:catalog)
        XCTAssertTrue(context.options(for:"16000019",at:"2026-10-23").isEmpty)
        XCTAssertEqual(context.historicalOptions(for:"16000019",
                       at:"2026-10-23").map(\.id),["empty-lot-history"])
        XCTAssertTrue(context.historicalOptions(for:"16000182",
                      at:"2026-10-23").isEmpty)
    }
    func testOsteomuscularChoicesIncludeOriginalWorkbookAndSpecificAnatomy()throws {
        XCTAssertEqual(N2OsteomuscularSegments.historical.count,10)
        for original in [
            "ZONA CERVICAL,DORSAL,LUMBAR Y SACRA",
            "PARTE POSTERIOR DEL TORAX (ESPALDA)",
            "PRIMER, SEGUNDO, TERCERO, CUARTO Y QUINTO ORTEJO DERECHO E IZQUIERDO",
            "RODILLA","TOBILLO","MANO","CUELLO"
        ] {
            XCTAssertTrue(N2OsteomuscularSegments.options.contains(original))
        }
        for specific in ["ZONA CERVICAL","ZONA DORSAL","ZONA LUMBAR",
                         "ZONA SACRA","PIE","PIERNA","RODILLA"] {
            XCTAssertTrue(N2OsteomuscularSegments.isKnown(specific))
        }
        XCTAssertEqual(Set(N2OsteomuscularSegments.options).count,
                       N2OsteomuscularSegments.options.count)
        XCTAssertFalse(N2OsteomuscularSegments.isKnown("ZONA ADICIONAL DOCUMENTADA"))
    }

    func testOsteomuscularSelectionAndLegacyTextSurviveEncryptedDraftFlow()throws {
        let (baseline,ctx)=try form()
        let original=try source("n1e-clinical-stock.json")
        for segment in ["ZONA LUMBAR","PIE","ZONA ANATOMICA HISTORICA LIBRE"] {
            var draft=baseline
            draft.segment=segment
            draft.system="OSTEOMUSCULAR"
            let updated=try N2SnapshotEditor.upsertDraft(
                snapshot:original,id:draft.id,
                changes:draft.makeDraftPatch(context:ctx,stage:1),at:at())
            let restored=try XCTUnwrap(N2NativeDraftRecovery.read(updated).first{
                $0.id==draft.id
            })
            XCTAssertEqual(restored.form.system,"OSTEOMUSCULAR")
            XCTAssertEqual(restored.form.segment,segment)
            XCTAssertEqual(restored.stage,1)
        }
    }

    func testDraftRecoveryRetainsMultipleProceduresAndPhysicalChoices()throws {
        var (draft,ctx)=try form()
        draft.procedures=["OBSERVACION","CURACION DE HERIDA","CONTROL"]
        draft.dispensingSite="LA VENTUROSA"
        draft.items[0].selectedLotID="lot-selected"
        draft.items[0].physicalQuantity=2.5
        draft.items[0].approveOpening=true
        let original=try source("n1e-clinical-stock.json")
        let next=try N2SnapshotEditor.upsertDraft(snapshot:original,id:draft.id,
            changes:draft.makeDraftPatch(context:ctx,stage:2),at:at())
        let projected=try N2NativeDraftRecovery.read(next)
        let restored=try XCTUnwrap(projected.first{$0.id==draft.id})
        XCTAssertEqual(restored.form.procedures,draft.procedures)
        XCTAssertEqual(restored.form.dni,draft.dni)
        XCTAssertEqual(restored.stage,2,"El borrador debe retomar Tratamiento, no Trabajador")
        XCTAssertEqual(restored.form.items.count,1)
        XCTAssertEqual(restored.form.dispensingSite,"LA VENTUROSA")
        XCTAssertEqual(restored.form.items[0].selectedLotID,"lot-selected")
        XCTAssertEqual(restored.form.items[0].physicalQuantity,2.5)
        XCTAssertTrue(restored.form.items[0].approveOpening)
        let clean=try N2SnapshotEditor.deleteDraft(snapshot:next,id:draft.id)
        XCTAssertFalse(try N2NativeDraftRecovery.read(clean).contains{$0.id==draft.id})
    }
    func testEmptyVisitWithoutAnyProcedureOrMedicationIsRejected()throws {
        var (draft,context)=try form(with:false)
        draft.procedures=[]
        XCTAssertThrowsError(try draft.makeSavedVisit(context:context)) {
            XCTAssertEqual($0 as? N2FormError,.invalidVisit)
        }
    }
    func testImpossibleCalendarDateIsRejectedBeforeSaving()throws {
        var (draft,context)=try form()
        draft.date="2026-02-30"
        XCTAssertThrowsError(try draft.makeSavedVisit(context:context)){
            XCTAssertEqual($0 as? N2FormError,.invalidDate)
        }
    }
    func testClinicalFormCreatesTSCompatibleVisitAndVerifiedStock()throws {
        let (form,context)=try self.form()
        XCTAssertEqual(context.revision,7)
        XCTAssertEqual(context.workers.count,5)
        XCTAssertEqual(context.products.clinical.count,432)
        XCTAssertEqual(context.products.nursing.count,98)
        XCTAssertEqual(context.products.approvals.count,86)
        let saved=try form.makeSavedVisit(context:context)
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:saved) as? [String:Any])
        XCTAssertEqual(root["date"] as? String,"2026-10-14")
        XCTAssertEqual(root["photoSent"] as? Bool,false)
        let original=try source("n1e-clinical-stock.json")
        let output=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:original,visit:saved,
            approvedCatalog:source("n2-reviewed-approved.json"),at:at())
        XCTAssertEqual(output.linked,1)
        XCTAssertEqual(output.physicalMovementsAdded,1)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(output.snapshot)
                .consumptionR.last!,2)
    }
    func testNoProductOnlyProcedureCanBeSavedWithoutFalseStockMovement()throws {
        let (form,context)=try self.form(with:false)
        let saved=try form.makeSavedVisit(context:context)
        let source=try self.source("n1e-clinical-stock.json")
        let old=try N1eLegacyClinicalAudit.inspect(source)
        let outcome=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:source,visit:saved,
            approvedCatalog:self.source("n2-reviewed-approved.json"),at:at())
        XCTAssertEqual(outcome.linked,0)
        XCTAssertEqual(outcome.pending,0)
        XCTAssertEqual(outcome.physicalMovementsAdded,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(outcome.snapshot)
                       .physicalMovements,old.physicalMovements)
    }
    func testUnreviewedAllergyCannotBeSavedAndDraftIsLossless()throws {
        let (form,context)=try self.form(reviewed:false)
        XCTAssertThrowsError(try form.makeSavedVisit(context:context)) {
            XCTAssertEqual($0 as? N2FormError,.unreviewedAllergies)
        }
        let original=try source("n1e-clinical-stock.json")
        let partial=try N2SnapshotEditor.upsertDraft(
            snapshot:original,id:form.id,
            changes:form.makeDraftPatch(context:context),at:at())
        let parsed=try XCTUnwrap(JSONSerialization.jsonObject(
             with:partial) as? [String:Any])
        XCTAssertEqual((parsed["attentions"] as? [[String:Any]])?.count,6)
    }
    func testAllergyReviewEnablesSavingAndStalePhysicalLotKeepsClinicalPending()throws {
        let original=try source("n1e-clinical-stock.json")
        let updated=try N2SnapshotEditor.reviewAllergies(
            snapshot:original,dni:"00000001",status:"none",
            substances:"",at:at())
        let context=try N2NativeFormContextReader.read(
            snapshot:updated,revision:9,products:catalog())
        var (form,_)=try self.form()
        let bytes=try form.makeSavedVisit(context:context)
        XCTAssertFalse(bytes.isEmpty)
        form.items[0].selectedLotID="nonexistent-stock"
        form.items[0].physicalQuantity=2
        let clinical=try form.makeSavedVisit(context:context)
        let outcome=try N2NativeClinicalTransaction.appendSavedVisit(snapshot:updated,
            visit:clinical,approvedCatalog:source("n2-reviewed-approved.json"),at:at())
        XCTAssertEqual(outcome.pending,1)
        XCTAssertEqual(outcome.physicalMovementsAdded,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(outcome.snapshot).attentions,
                       try N1eLegacyClinicalAudit.inspect(updated).attentions+1)
    }
}

