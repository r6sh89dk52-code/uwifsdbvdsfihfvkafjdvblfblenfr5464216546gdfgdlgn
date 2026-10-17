import Foundation
import XCTest
@testable import DanperCore

final class N2SnapshotEditorTests:XCTestCase {
    private func source()throws->Data {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:dir)
            .appendingPathComponent("n1e-clinical-stock.json"))
    }
    private func json(_ value:Any)throws->Data {
        try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
    }
    private func root(_ raw:Data)throws->[String:Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with:raw) as? [String:Any])
    }
    func testPartialDraftPreservesUnfilledClinicalFieldsAndSavedStock()throws {
        let original=try source()
        let originalAudit=try N1eLegacyClinicalAudit.inspect(original)
        let draft:[String:Any]=[
            "worker":["dni":"00000001","name":"PERSONA FICTICIA UNO"],
            "items":[["id":"line-1","quantity":0,"code":"","name":"",
                      "unit":"","procedure":""]],
            "diagnosis":"",
            "date":"2026-10-14"
        ]
        let withDraft=try N2SnapshotEditor.upsertDraft(
            snapshot:original,id:"N2-UNFINISHED",changes:json(draft),at:123456)
        let result=try root(withDraft)
        let before=try root(original)
        XCTAssertEqual((result["attentions"] as? [[String:Any]])?.count,
                       (before["attentions"] as? [[String:Any]])!.count+1)
        let row=try XCTUnwrap((result["attentions"] as! [[String:Any]])
             .first(where:{$0["id"] as? String=="N2-UNFINISHED"}))
        XCTAssertEqual(row["status"] as? String,"draft")
        XCTAssertEqual((row["items"] as? [[String:Any]])?.first?["quantity"] as? Int,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(withDraft).consumptionR,
                       originalAudit.consumptionR)
        for collection in ["workers","allergies","stockLots","stockMovements",
                           "catalogMappings","deliveryIncidents","ambulatoryReconciliation"] {
            XCTAssertEqual(try json(result[collection]!),try json(before[collection]!))
        }
        // Restart-safe encrypted journal accepts an incomplete draft.
        let folder=FileManager.default.temporaryDirectory
            .appendingPathComponent("danper-n2-synthetic-"+UUID().uuidString,isDirectory:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let journal=try N2EncryptedClinicalJournal(directory:folder,
                            secret:Data(repeating:0x71,count:32))
        XCTAssertEqual(try journal.commit(withDraft,expectedRevision:0),1)
        XCTAssertEqual(try journal.recover()?.snapshot,withDraft)
    }
    func testManualWorkerAndAllergyAreExactAndReversible()throws {
        let before=try source()
        let worker:[String:Any]=["dni":"00000009","name":"PERSONA DE PRUEBA NUEVE",
                                 "area":"CAMPO","labor":"PRUEBA",
                                 "sex":"F","age":"31","ubigeo":""]
        let updated=try N2SnapshotEditor.addWorker(
            snapshot:before,worker:json(worker),at:1700000000000)
        let newer=try N2SnapshotEditor.reviewAllergies(
            snapshot:updated,dni:"00000009",status:"known",
            substances:"SUSTANCIA DE PRUEBA",at:1700000000001)
        let obj=try root(newer)
        XCTAssertEqual((obj["workers"] as? [[String:Any]])?.count,6)
        XCTAssertEqual((obj["allergies"] as? [String:[String:Any]])?["00000009"]?["status"] as? String,"known")
        XCTAssertEqual((obj["stockMovements"] as? [Any])?.count,
                       (try root(before)["stockMovements"] as? [Any])?.count)
        XCTAssertThrowsError(try N2SnapshotEditor.addWorker(
            snapshot:updated,worker:json(worker),at:1700000000002)) {
            XCTAssertEqual($0 as? N2SnapshotEditError,.duplicateWorker)
        }
        XCTAssertThrowsError(try N2SnapshotEditor.reviewAllergies(
            snapshot:updated,dni:"00000009",status:"known",
            substances:"",at:1700000000002)) {
            XCTAssertEqual($0 as? N2SnapshotEditError,.invalidAllergy)
        }
    }
    func testCannotRewriteSavedAttentionOrKeepDuplicateDraftIDs()throws {
        let before=try source()
        XCTAssertThrowsError(try N2SnapshotEditor.upsertDraft(
            snapshot:before,id:"fundo-unit",
            changes:json(["diagnosis":"TAMPER"]),at:1700000000001)) {
            XCTAssertEqual($0 as? N2SnapshotEditError,.savedIsImmutable)
        }
        let partial=try N2SnapshotEditor.upsertDraft(snapshot:before,id:"draft-1",
                                 changes:json(["diagnosis":"PENDIENTE"]),at:1700000000001)
        let patched=try N2SnapshotEditor.upsertDraft(snapshot:partial,id:"draft-1",
                                 changes:json(["category":"ENFERMEDAD"]),at:1700000000002)
        let visits=(try root(patched)["attentions"]) as! [[String:Any]]
        XCTAssertEqual(visits.filter{$0["id"] as? String=="draft-1"}.count,1)
        let deleted=try N2SnapshotEditor.deleteDraft(snapshot:patched,id:"draft-1")
        XCTAssertEqual((try root(deleted)["attentions"] as! [[String:Any]]).count,5)
        XCTAssertThrowsError(try N2SnapshotEditor.deleteDraft(snapshot:before,id:"fundo-unit")) {
            XCTAssertEqual($0 as? N2SnapshotEditError,.savedIsImmutable)
        }
        XCTAssertThrowsError(try N2SnapshotEditor.upsertDraft(snapshot:partial,id:"draft-1",
                        changes:json(["status":"saved"]),at:1700000000002)) {
            XCTAssertEqual($0 as? N2SnapshotEditError,.invalidDraft)
        }
    }
    func testUnrecognizedExtensionFieldsAndCorrectionChainAreNotErased()throws {
        var s=try root(source())
        var visits=s["attentions"] as! [[String:Any]]
        visits.append(["id":"correction-1","status":"draft",
                       "originId":"fundo-unit",
                       "worker":[:],"items":[],
                       "futureExtension":["flags":["a","b"]]])
        s["attentions"]=visits
        s["newFutureCollection"]=["original":true]
        let source=try json(s)
        let patched=try N2SnapshotEditor.upsertDraft(
            snapshot:source,id:"correction-1",
            changes:json(["diagnosis":"CORRECCION SIN CONFIRMAR"]),at:1700000000000)
        let root=try self.root(patched)
        let row=(root["attentions"] as! [[String:Any]]).last!
        XCTAssertNotNil(row["originId"])
        XCTAssertNotNil(row["futureExtension"])
        XCTAssertNotNil(root["newFutureCollection"])
    }
}
