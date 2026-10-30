import Foundation
import XCTest
@testable import DanperCore

final class N2EncryptedClinicalJournalTests:XCTestCase {
    private enum Crash:Error {case abrupt}
    private func input()throws->Data {
        let folder=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:folder)
            .appendingPathComponent("n1e-clinical-stock.json"))
    }
    private func path()throws->URL {
        let folder=FileManager.default.temporaryDirectory
            .appendingPathComponent("danper-n2-synthetic-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:false)
        addTeardownBlock{try? FileManager.default.removeItem(at:folder)}
        return folder
    }
    private func start(_ folder:URL,_ key:Data)throws->N2EncryptedClinicalJournal {
        try N2EncryptedClinicalJournal(directory:folder,secret:key)
    }
    func testFastAllergyWriteRecoversVerifiedRevisionWithoutChangingClinicalHistory()throws {
        let folder=try path(),key=Data(repeating:0x68,count:32)
        let journal=try start(folder,key),original=try input()
        XCTAssertEqual(try journal.commit(original,expectedRevision:0),1)
        let core=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        let rev=try core.reviewAllergiesRevision(
            dni:"00000001",status:"known",substances:"PENICILINA",
            at:1793370000000,expectedRevision:1)
        XCTAssertEqual(rev,2)
        let reopened=try start(folder,key)
        let result=try XCTUnwrap(reopened.recover())
        XCTAssertEqual(result.revision,2)
        let prior=try XCTUnwrap(JSONSerialization.jsonObject(with:original) as? [String:Any])
        let next=try XCTUnwrap(JSONSerialization.jsonObject(with:result.snapshot) as? [String:Any])
        let allergies=try XCTUnwrap(next["allergies"] as? [String:Any])
        let allergy=try XCTUnwrap(allergies["00000001"] as? [String:Any])
        XCTAssertEqual(allergy["status"] as? String,"known")
        XCTAssertEqual(allergy["substances"] as? String,"PENICILINA")
        for field in ["workers","attentions","stockLots","stockMovements"] {
            XCTAssertEqual(
                try JSONSerialization.data(withJSONObject:prior[field]!,
                    options:[.sortedKeys]),
                try JSONSerialization.data(withJSONObject:next[field]!,
                    options:[.sortedKeys]))
        }
        XCTAssertThrowsError(try core.reviewAllergiesRevision(
            dni:"00000001",status:"none",substances:"",
            at:1793370000100,expectedRevision:1)) {
            XCTAssertEqual($0 as? N2ProtectedStoreError,.staleRevision)
        }
        XCTAssertEqual(try reopened.recover()?.revision,2)
    }

    func testAtomicEncryptedRevisionAndNoPlaintextFiles()throws {
        let folder=try path(),key=Data(repeating:0x44,count:32),original=try input()
        let store=try start(folder,key)
        XCTAssertNil(try store.recover())
        XCTAssertEqual(try store.commit(original,expectedRevision:0),1)
        let reopened=try start(folder,key)
        let restored=try XCTUnwrap(reopened.recover())
        XCTAssertEqual(restored.revision,1)
        XCTAssertEqual(restored.snapshot,original)
        let paths=try FileManager.default.contentsOfDirectory(at:folder,
                                      includingPropertiesForKeys:nil)
        for url in paths {
            let raw=try Data(contentsOf:url)
            XCTAssertNil(raw.range(of:Data("PERSONA FICTICIA".utf8)))
            XCTAssertNil(raw.range(of:Data("00000001".utf8)))
        }
        XCTAssertThrowsError(try reopened.commit(original,expectedRevision:0)) {
            XCTAssertEqual($0 as? N2EncryptedClinicalJournal.Failure,.staleRevision)
        }
        let wrong=try start(folder,Data(repeating:0x55,count:32))
        XCTAssertThrowsError(try wrong.recover()) {
            XCTAssertEqual($0 as? N2EncryptedClinicalJournal.Failure,.authenticationFailed)
        }
    }
    func testPowerLossCheckpointsProtectCompleteSnapshot()throws {
        let original=try input()
        for checkpoint in [
            N2EncryptedClinicalJournal.Checkpoint.encryptedGenerationWritten,
            .pendingJournalWritten,.activePointerWritten
        ] {
            let folder=try path(),key=Data(repeating:0x33,count:32)
            let engine=try start(folder,key)
            XCTAssertEqual(try engine.commit(original,expectedRevision:0),1)
            let candidate=try engine.commit(original,expectedRevision:1)
            XCTAssertEqual(candidate,2)
            // A fresh transition deliberately faults after one milestone.
            XCTAssertThrowsError(try engine.commit(original,expectedRevision:2) { stage in
                if stage==checkpoint {throw Crash.abrupt}
            })
            let after=try start(folder,key)
            let recovered=try XCTUnwrap(after.recover())
            XCTAssertEqual(recovered.revision,
                           checkpoint == .activePointerWritten ? 3 : 2)
            XCTAssertEqual(recovered.snapshot,original)
        }
    }
    func testModifiedCiphertextIsNeverAccepted()throws {
        let folder=try path(),key=Data(repeating:0x11,count:32)
        let store=try start(folder,key)
        _=try store.commit(input(),expectedRevision:0)
        let verified=try XCTUnwrap(store.recover())
        XCTAssertEqual(verified.parity.sourceSHA256,verified.fields.sourceSHA256)
        let auditCount=store.semanticValidationCount
        _=try store.recover()
        XCTAssertEqual(store.semanticValidationCount,auditCount,
            "Identical authenticated bytes share semantic proof only inside this journal instance")
        let p=try FileManager.default.contentsOfDirectory(at:folder,
                                 includingPropertiesForKeys:nil).first {
            $0.lastPathComponent.hasPrefix("gen-")
        }
        let path=try XCTUnwrap(p)
        var bytes=try Data(contentsOf:path)
        bytes[bytes.count-1] ^= 0x01
        try bytes.write(to:path,options:.atomic)
        XCTAssertThrowsError(try store.recover()) {
            XCTAssertEqual($0 as? N2EncryptedClinicalJournal.Failure,.authenticationFailed)
        }
    }
    func testValidationMemoDoesNotCertifyChangedBytesOrWrongKey()throws {
        let folder=try path(),key=Data(repeating:0x31,count:32)
        let store=try start(folder,key),raw=try input()
        _=try store.commit(raw,expectedRevision:0)
        let count=store.semanticValidationCount
        let next=try N2SnapshotEditor.reviewAllergies(snapshot:raw,dni:"00000001",
            status:"known",substances:"SUSTANCIA FICTICIA",at:1793370000000)
        _=try store.commit(next,expectedRevision:1)
        XCTAssertGreaterThan(store.semanticValidationCount,count)
        let after=try XCTUnwrap(store.recover())
        XCTAssertEqual(after.snapshot,next)
        XCTAssertEqual(after.parity.sourceSHA256,after.fields.sourceSHA256)
        XCTAssertThrowsError(try start(folder,Data(repeating:0x32,count:32)).recover())
        var bad=try XCTUnwrap(JSONSerialization.jsonObject(with:next) as? [String:Any])
        bad["allergies"]=["00000001":["status":"known","substances":7,"updatedAt":1793370000000]]
        XCTAssertThrowsError(try store.commit(JSONSerialization.data(withJSONObject:bad),expectedRevision:2))
        XCTAssertEqual(try store.recover()?.revision,2)
    }
    func testMissingApplicationSupportParentIsCreatedWithoutDestroyingData()throws {
        // Regression: on a fresh iPhone install, Application Support is not
        // necessarily present. The previous createDirectory(intermediates:false)
        // returned NSCocoaErrorDomain 4 before the demo could start.
        let sandbox=FileManager.default.temporaryDirectory
            .appendingPathComponent("danper-n2-support-test-"+UUID().uuidString,
                                    isDirectory:true)
        defer{try? FileManager.default.removeItem(at:sandbox)}
        let support=sandbox.appendingPathComponent("Library",isDirectory:true)
            .appendingPathComponent("Application Support",isDirectory:true)
        XCTAssertFalse(FileManager.default.fileExists(atPath:support.path))
        try N2EncryptedClinicalJournal.ensureApplicationSupportDirectory(support)
        var isDirectory:ObjCBool=false
        XCTAssertTrue(FileManager.default.fileExists(atPath:support.path,
                                                       isDirectory:&isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        let marker=support.appendingPathComponent("existing-encrypted-generation")
        try Data([0x12,0x34,0x56]).write(to:marker)
        try N2EncryptedClinicalJournal.ensureApplicationSupportDirectory(support)
        XCTAssertEqual(try Data(contentsOf:marker),Data([0x12,0x34,0x56]))
    }
    func testApplicationSupportSymlinkIsRejectedWithoutDeletingTarget()throws {
        let sandbox=FileManager.default.temporaryDirectory
            .appendingPathComponent("danper-n2-support-link-"+UUID().uuidString,
                                    isDirectory:true)
        defer{try? FileManager.default.removeItem(at:sandbox)}
        try FileManager.default.createDirectory(at:sandbox,
                                                withIntermediateDirectories:true)
        let target=sandbox.appendingPathComponent("safe",isDirectory:true)
        try FileManager.default.createDirectory(at:target,
                                                withIntermediateDirectories:false)
        let support=sandbox.appendingPathComponent("Application Support",
                                                   isDirectory:true)
        try FileManager.default.createSymbolicLink(at:support,withDestinationURL:target)
        XCTAssertThrowsError(
            try N2EncryptedClinicalJournal.ensureApplicationSupportDirectory(support)
        ) {
            XCTAssertEqual($0 as? N2EncryptedClinicalJournal.Failure,.unsafeLocation)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath:target.path))
    }
}
