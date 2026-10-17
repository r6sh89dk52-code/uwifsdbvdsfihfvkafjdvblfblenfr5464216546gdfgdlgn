import Foundation
import XCTest
@testable import DanperCore

final class N2AtomicClinicalCoordinatorTests:XCTestCase {
    private enum SimulatedCrash:Error {case interruption}
    private func fixture(_ name:String)throws->Data {
        let folder=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:folder,isDirectory:true)
            .appendingPathComponent(name))
    }
    private func json(_ object:Any)throws->Data {
        try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys])
    }
    private func at()->Int64 {
        Int64(ISO8601DateFormatter().date(from:"2026-10-14T18:00:00Z")!
            .timeIntervalSince1970*1000)
    }
    private func visit(_ original:Data,id:String)->Data {
        var root=(try! JSONSerialization.jsonObject(with:original)) as! [String:Any]
        var visits=root["attentions"] as! [[String:Any]]
        var item=visits.first{$0["id"] as? String == "fundo-unit"}!
        item["id"]=id
        var lines=item["items"] as! [[String:Any]]
        lines[0]["id"]=id+"-material"
        lines[0]["quantity"]=2
        item["items"]=lines
        root["attentions"]=visits
        return try! json(item)
    }
    private func folder()throws->URL {
        let p=FileManager.default.temporaryDirectory
            .appendingPathComponent("danper-n2-synthetic-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:p,withIntermediateDirectories:false)
        addTeardownBlock{try? FileManager.default.removeItem(at:p)}
        return p
    }
    private func connect(_ url:URL)throws -> (N2EncryptedClinicalJournal,N2AtomicClinicalCoordinator) {
        let v=try N2EncryptedClinicalJournal(directory:url,
                  secret:Data(repeating:0x41,count:32))
        return(v,N2AtomicClinicalCoordinator(journal:v))
    }
    func testOneSavedVisitAndAllPhysicalMovementsCommitTogether()throws {
        let root=try folder(),original=try fixture("n1e-clinical-stock.json")
        let catalog=try fixture("n2-reviewed-approved.json")
        let (journal,coordinator)=try connect(root)
        XCTAssertEqual(try coordinator.bootstrapFromVerifiedSingleSource(original),1)
        let data=visit(original,id:"n2-atomic-1")
        let answer=try coordinator.save(visit:data,approvedCatalog:catalog,
                                        at:at(),expectedRevision:1)
        XCTAssertEqual(answer.revision,2)
        XCTAssertEqual(answer.linked,1)
        XCTAssertEqual(answer.addedMovements,1)
        let record=try XCTUnwrap(journal.recover())
        XCTAssertEqual(record.revision,2)
        let report=try N1eLegacyClinicalAudit.inspect(record.snapshot)
        XCTAssertEqual(report.linkedClinicalItems,5)
        XCTAssertEqual(report.attentions,6)
        XCTAssertEqual(report.consumptionR.last!,2)
        let again=try coordinator.save(visit:data,approvedCatalog:catalog,
                                       at:at(),expectedRevision:1)
        XCTAssertTrue(again.alreadyCommitted)
        XCTAssertEqual(again.revision,2)
        XCTAssertEqual(again.addedMovements,0)
        var changed=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        var lines=changed["items"] as! [[String:Any]]
        lines[0]["quantity"]=3;changed["items"]=lines
        XCTAssertThrowsError(try coordinator.save(visit:json(changed),
                          approvedCatalog:catalog,at:at(),expectedRevision:2)) {
            XCTAssertEqual($0 as? N2AtomicClinicalCoordinator.Failure,.duplicateChangedVisit)
        }
    }
    func testInterruptedSaveIsEntirelyOldOrEntirelyNew()throws {
        for fail in [
            N2EncryptedClinicalJournal.Checkpoint.pendingJournalWritten,
            .activePointerWritten
        ] {
            let root=try folder(),original=try fixture("n1e-clinical-stock.json"),
                catalog=try fixture("n2-reviewed-approved.json")
            let (journal,coordinator)=try connect(root)
            _=try coordinator.bootstrapFromVerifiedSingleSource(original)
            let data=visit(original,id:"n2-recovery")
            XCTAssertThrowsError(try coordinator.save(
                visit:data,approvedCatalog:catalog,at:at(),expectedRevision:1,
                fault:{step in if step==fail{throw SimulatedCrash.interruption}}
            ))
            let (_,retry)=try connect(root)
            let previous=try XCTUnwrap(journal.recover())
            if fail == .pendingJournalWritten {
                XCTAssertEqual(previous.revision,1)
                XCTAssertEqual(previous.snapshot,original)
                let result=try retry.save(visit:data,approvedCatalog:catalog,
                                          at:at(),expectedRevision:1)
                XCTAssertEqual(result.revision,2)
            }else {
                XCTAssertEqual(previous.revision,2)
                XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(previous.snapshot)
                        .linkedClinicalItems,5)
                XCTAssertTrue(try retry.save(visit:data,approvedCatalog:catalog,
                        at:at(),expectedRevision:1).alreadyCommitted)
            }
        }
    }
    func testAutosavedIncompleteDraftPromotionIsAtomicAndIdempotent()throws {
        let original=try fixture("n1e-clinical-stock.json")
        let catalog=try fixture("n2-reviewed-approved.json")
        let sample=visit(original,id:"n2-promote")
        let incomplete=try N2SnapshotEditor.upsertDraft(
            snapshot:original,id:"n2-promote",
            changes:json(["diagnosis":"INCOMPLETO",
                          "items":[["id":"n2-promote-material","quantity":0]]]),
            at:at()-2000)
        var draftRoot=try XCTUnwrap(JSONSerialization.jsonObject(
            with:incomplete) as? [String:Any])
        var beforeVisits=draftRoot["attentions"] as! [[String:Any]]
        let pos=try XCTUnwrap(beforeVisits.firstIndex{
            $0["id"] as? String=="n2-promote"
        })
        beforeVisits[pos]["futureExtension"]=["retained":true]
        draftRoot["attentions"]=beforeVisits
        let sourceWithFuture=try json(draftRoot)
        let folder=try self.folder()
        let (journal,coordinator)=try connect(folder)
        XCTAssertEqual(try coordinator.bootstrapFromVerifiedSingleSource(sourceWithFuture),1)
        let answer=try coordinator.save(visit:sample,approvedCatalog:catalog,
                                        at:at(),expectedRevision:1)
        XCTAssertEqual(answer.revision,2)
        XCTAssertEqual(answer.linked,1)
        XCTAssertEqual(answer.addedMovements,1)
        let current=try XCTUnwrap(journal.recover())
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:current.snapshot) as? [String:Any])
        let visits=root["attentions"] as! [[String:Any]]
        XCTAssertEqual(visits.filter{$0["id"] as? String=="n2-promote"}.count,1)
        let promoted=try XCTUnwrap(visits.first{$0["id"] as? String=="n2-promote"})
        XCTAssertEqual(promoted["status"] as? String,"saved")
        XCTAssertNotNil(promoted["futureExtension"])
        let again=try coordinator.save(visit:sample,approvedCatalog:catalog,
                                       at:at(),expectedRevision:1)
        XCTAssertTrue(again.alreadyCommitted)
        XCTAssertEqual(again.addedMovements,0)
        XCTAssertEqual(try journal.recover()?.revision,2)
    }
    func testCorrectionDraftCannotBePromotedWithoutAudit()throws {
        let original=try fixture("n1e-clinical-stock.json")
        let catalog=try fixture("n2-reviewed-approved.json")
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:original) as? [String:Any])
        var visits=root["attentions"] as! [[String:Any]]
        var correction=try XCTUnwrap(JSONSerialization.jsonObject(
            with:visit(original,id:"n2-correction")) as? [String:Any])
        correction["status"]="draft"
        correction["originId"]="fundo-unit"
        visits.append(correction)
        root["attentions"]=visits
        let before=try json(root)
        let folder=try self.folder()
        let (_,coordinator)=try connect(folder)
        _=try coordinator.bootstrapFromVerifiedSingleSource(before)
        correction["status"]="saved"
        XCTAssertThrowsError(try coordinator.save(visit:json(correction),
                             approvedCatalog:catalog,at:at(),expectedRevision:1)) {
            XCTAssertEqual($0 as? N2AtomicClinicalCoordinator.Failure,
                           .duplicateChangedVisit)
        }
    }
}
