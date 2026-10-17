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
