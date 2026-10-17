import XCTest
@testable import DanperCore

final class N2Build222ProcedureParityTests:XCTestCase {
    private func source(_ name:String)throws->Data {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:dir).appendingPathComponent(name))
    }
    private func catalog()throws->N2NativeCatalogIndex {
        let plan=try XCTUnwrap(JSONSerialization.jsonObject(with:source("n1s-indicator-plan.json")) as? [String:Any])
        let nurse=try XCTUnwrap(JSONSerialization.jsonObject(with:source("n2-nursing-parity.json")) as? [String:Any])
        return try N2NativeCatalogLoader.load(
            products:JSONSerialization.data(withJSONObject:plan["catalog"]!),
            nursing:JSONSerialization.data(withJSONObject:nurse["catalog"]!),
            approvedMappings:source("n2-reviewed-approved.json"))
    }
    func testEveryCatalogProductAgainstFrozenBuild222Oracle()throws {
        let rows=try XCTUnwrap(JSONSerialization.jsonObject(with:source("n2-procedure-parity.json")) as? [[String:Any]])
        XCTAssertGreaterThan(rows.count,3000)
        for row in rows {
            let name=try XCTUnwrap(row["name"] as? String)
            let context=try XCTUnwrap(row["context"] as? [String])
            let result=N2ProcedureRules.infer(name:name,context:context)
            XCTAssertEqual(result.procedure,row["procedure"] as? String,"\(name) / \(context)")
            XCTAssertEqual(result.source,row["source"] as? String,name)
            XCTAssertEqual(result.needsConfirmation,row["needsConfirmation"] as? Bool,name)
        }
    }
    func testRecalculationCannotKeepItsOwnContextAndManualOverrideSurvives()throws {
        let catalog=try catalog()
        let amp=try XCTUnwrap(catalog.clinical.first{N2ProcedureRules.infer(name:$0.name).procedure=="INYECTABLE"})
        let syringe=try XCTUnwrap(catalog.clinical.first{$0.name.contains("JERINGA") && !N2ProcedureRules.infer(name:$0.name,context:["INYECTABLE"]).needsConfirmation})
        var form=N2NativeFormDraft()
        XCTAssertTrue(form.procedures.isEmpty)
        XCTAssertTrue(N2FormMedication(code:amp.code).procedure.isEmpty)
        form.items=[N2FormMedication(code:amp.code),N2FormMedication(code:syringe.code)]
        form.refreshProcedureSuggestions(catalog:catalog)
        XCTAssertEqual(form.items[1].procedure,"INYECTABLE")
        form.items.removeFirst()
        form.refreshProcedureSuggestions(catalog:catalog)
        XCTAssertEqual(form.items[0].procedure,"")
        form.items[0].procedure="CONTROL"
        form.items[0].procedureConfirmed=true
        form.procedures=["INYECTABLE","CURACION DE HERIDA"]
        form.refreshProcedureSuggestions(catalog:catalog)
        XCTAssertEqual(form.items[0].procedure,"CONTROL")
    }
    func testManualChoiceAndProvenancePersistThroughEncryptedDraftShape()throws {
        let catalog=try catalog()
        let original=try source("n1e-clinical-stock.json")
        let context=try N2NativeFormContextReader.read(snapshot:original,revision:1,products:catalog)
        var form=N2NativeFormDraft(id:"parity-draft")
        form.items=[N2FormMedication(code:catalog.clinical[0].code,procedure:"CONTROL")]
        form.photoReviewed=true
        let saved=try N2SnapshotEditor.upsertDraft(snapshot:original,id:form.id,
            changes:form.makeDraftPatch(context:context),at:1_792_000_000_000)
        let recovered=try XCTUnwrap(N2NativeDraftRecovery.read(saved).first{$0.id==form.id})
        XCTAssertTrue(recovered.form.items[0].procedureConfirmed)
        XCTAssertEqual(recovered.form.items[0].procedureSource,"manual")
        XCTAssertTrue(recovered.form.photoReviewed)
    }
    func testLimaWeekBoundaryCountsVisitsNotClinicalLines()throws {
        func visit(_ id:String,_ date:String,_ status:String)->N2VisitIndexRow {
            N2VisitIndexRow(id:id,workerDNI:"00000001",workerName:"PERSONA FICTICIA",
                date:date,time:"08:00",diagnosis:"FICTICIO",status:status,frequency:nil,
                clinicalLines:10,confirmedPhysicalLines:9,pendingPhysicalLines:1,consumptionR:[])
        }
        let now=try XCTUnwrap(ISO8601DateFormatter().date(from:"2026-10-19T03:00:00Z")) // Sunday 22:00 Lima
        let metrics=N2DashboardMetrics.calculate(visits:[
            visit("a","2026-10-12","saved"),visit("b","2026-10-18","saved"),
            visit("c","2026-10-19","saved"),visit("d","2026-10-18","draft")],now:now)
        XCTAssertEqual(metrics.today,1)
        XCTAssertEqual(metrics.week,2)
        XCTAssertEqual(metrics.drafts,1)
    }
}
