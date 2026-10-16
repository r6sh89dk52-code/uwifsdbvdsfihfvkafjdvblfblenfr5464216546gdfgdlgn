import Foundation
import XCTest
@testable import DanperCore

/// N1o never reads .danperbackup or accesses clinical app data.
/// Every test uses an isolated OS temporary directory and fake fixture.
final class N1oInactiveTransactionTests: XCTestCase {
    private enum Crash:Error {case simulated}
    private let key=Data(repeating:0x72,count:32)
    private let accepted=N1nAcknowledgment(originalBuild222:true,
          reviewedForDemo:true,understandsNoRestore:true)

    private func location() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "danper-n1o-synthetic-" + UUID().uuidString)
    }
    private func lab(_ path:URL,key:Data?=nil) throws -> N1oInactiveTransactionLab {
        try N1oInactiveTransactionLab(directory:path,keyData:key ?? self.key)
    }
    private func snapshot() throws -> Data {
        guard let fixture=ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"] else {
            throw XCTSkip("Requires synthetic fixture")
        }
        let bytes=try Data(contentsOf:URL(fileURLWithPath:fixture)
                  .appendingPathComponent("n1f-source.json"))
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:bytes) as? [String:Any])
        var roster=root["workers"] as! [[String:Any]]
        roster[0]["name"]="IDENTIDAD SINTETICA ALFA"
        roster[1]["name"]="IDENTIDAD SINTETICA BETA"
        root["workers"]=roster
        var visits=root["attentions"] as! [[String:Any]]
        for i in visits.indices {
            if var worker=visits[i]["worker"] as? [String:Any] {
                worker["name"]="IDENTIDAD SINTETICA ALFA"
                visits[i]["worker"]=worker
            }
        }
        root["attentions"]=visits
        return try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys])
    }
    private func changed(_ edit:(inout [String:Any])->Void) throws -> Data {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:snapshot()) as? [String:Any])
        edit(&root)
        return try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys])
    }
    func testNineDomainsAndClinicalCountersPreservedInInactiveRehearsal() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let raw=try snapshot()
        let v=try lab(dir)
        XCTAssertEqual(try v.recover(),.empty)
        let summary=try v.stage(raw)
        XCTAssertEqual(summary.collectionCounts.count,9)
        XCTAssertEqual(summary.collectionHashes.count,9)
        XCTAssertEqual(summary.collectionCounts["workers"],2)
        XCTAssertEqual(summary.collectionCounts["attentions"],3)
        XCTAssertEqual(summary.collectionCounts["notifications"],1)
        XCTAssertEqual(summary.drafts,2)
        XCTAssertEqual(summary.corrections,1)
        XCTAssertEqual(summary.unresolvedConsumptions,1)
        XCTAssertFalse(summary.canActivate)
        XCTAssertNil(try v.inspectInactive())
        XCTAssertEqual(try v.recover(),.pending)
        let sealed=try v.commitInactive()
        XCTAssertEqual(summary,sealed)
        XCTAssertFalse(sealed.canActivate)
        XCTAssertEqual(try lab(dir).recover(),.inactiveVerified)
        XCTAssertEqual(try lab(dir).inspectInactive(),summary)
    }
    func testNoPlaintextEverWrittenToShadowDirectory() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let vault=try lab(dir),raw=try snapshot()
        try vault.stage(raw)
        try vault.commitInactive()
        let files=try FileManager.default.contentsOfDirectory(atPath:dir.path)
        XCTAssertEqual(Set(files),Set(["candidate.sealed.gcm","inactive-verified.json"]))
        for name in files {
            let data=try Data(contentsOf:dir.appendingPathComponent(name))
            XCTAssertNil(data.range(of:Data("IDENTIDAD SINTETICA ALFA".utf8)))
            XCTAssertNil(data.range(of:Data("CEFALEA".utf8)))
        }
    }
    func testRepeatedSameSourceIsIdempotentButChangedCannotReplace() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let v=try lab(dir),raw=try snapshot()
        let a=try v.stage(raw)
        XCTAssertEqual(try v.stage(raw),a)
        let changedData=try changed{$0["futureTop"]=["new":"extension"]}
        XCTAssertThrowsError(try v.stage(changedData)) {
            XCTAssertEqual($0 as? N1oInactiveTransactionLab.Failure,.sourceConflict)
        }
        try v.commitInactive()
        XCTAssertEqual(try v.stage(raw),a)
        XCTAssertThrowsError(try v.stage(changedData))
        XCTAssertEqual(try v.inspectInactive(),a)
    }
    func testInterruptedAfterEncryptedFileFailsClosedNeverReplaces() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let v=try lab(dir),raw=try snapshot()
        XCTAssertThrowsError(try v.stage(raw,fault:{ step in
            if step == .encryptedWritten {throw Crash.simulated}
        }))
        XCTAssertThrowsError(try lab(dir).recover()){
            XCTAssertEqual($0 as? N1oInactiveTransactionLab.Failure,.incomplete)
        }
        XCTAssertThrowsError(try v.stage(raw))
        XCTAssertThrowsError(try v.commitInactive())
        XCTAssertTrue(FileManager.default.fileExists(
            atPath:dir.appendingPathComponent("candidate.pending.gcm").path))
    }
    func testInterruptedAfterJournalRemainsPendingNeverAutomaticallyCommits() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let v=try lab(dir),raw=try snapshot()
        XCTAssertThrowsError(try v.stage(raw,fault:{ step in
            if step == .journalWritten {throw Crash.simulated}
        }))
        let restarted=try lab(dir)
        XCTAssertEqual(try restarted.recover(),.pending)
        XCTAssertNil(try restarted.inspectInactive())
        XCTAssertEqual(try restarted.stage(raw).drafts,2)
        XCTAssertNil(try restarted.inspectInactive())
        XCTAssertEqual(try restarted.commitInactive().corrections,1)
    }
    func testInterruptedAfterRenameRollsBackToPendingForExplicitCommit() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let v=try lab(dir),raw=try snapshot()
        try v.stage(raw)
        XCTAssertThrowsError(try v.commitInactive(fault:{ step in
            if step == .sealedRenamed {throw Crash.simulated}
        }))
        XCTAssertThrowsError(try v.stage(raw)){
            XCTAssertEqual($0 as? N1oInactiveTransactionLab.Failure,.recoveryRequired)
        }
        let restarted=try lab(dir)
        XCTAssertEqual(try restarted.recover(),.pending)
        XCTAssertNil(try restarted.inspectInactive())
        XCTAssertEqual(try restarted.commitInactive().collectionCounts["workers"],2)
    }
    func testInterruptedAfterInactivePointerVerifiesAndFinalizesWithoutRewriting() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let v=try lab(dir)
        try v.stage(snapshot())
        XCTAssertThrowsError(try v.commitInactive(fault:{ step in
            if step == .inactivePointerWritten {throw Crash.simulated}
        }))
        XCTAssertNotNil(try v.inspectInactive())
        XCTAssertEqual(try lab(dir).recover(),.inactiveVerified)
        let files=try FileManager.default.contentsOfDirectory(atPath:dir.path)
        XCTAssertEqual(Set(files),Set(["candidate.sealed.gcm","inactive-verified.json"]))
    }
    func testBadExternalKeyNeverTreatsCommittedDataAsEmpty() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let v=try lab(dir)
        try v.stage(snapshot())
        try v.commitInactive()
        let falseKey=try lab(dir,key:Data(repeating:0x73,count:32))
        XCTAssertThrowsError(try falseKey.recover()){
            XCTAssertEqual($0 as? N1oInactiveTransactionLab.Failure,.wrongKey)
        }
        XCTAssertNotNil(try v.inspectInactive())
        XCTAssertThrowsError(try lab(dir,key:Data(repeating:0x00,count:16)))
    }
    func testCiphertextAndReceiptTamperingBlocksInspection() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let v=try lab(dir)
        try v.stage(snapshot())
        try v.commitInactive()
        let cipherPath=dir.appendingPathComponent("candidate.sealed.gcm")
        var bytes=try Data(contentsOf:cipherPath)
        bytes[12] ^= 0x80
        try bytes.write(to:cipherPath,options:.atomic)
        XCTAssertThrowsError(try lab(dir).recover()){
            XCTAssertEqual($0 as? N1oInactiveTransactionLab.Failure,.alteredCiphertext)
        }
        XCTAssertThrowsError(try v.stage(snapshot()))
    }
    func testTamperedJournalCannotBeCommittedOrDiscarded() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let v=try lab(dir)
        try v.stage(snapshot())
        let journal=dir.appendingPathComponent("inactive-intent.json")
        var data=try XCTUnwrap(JSONSerialization.jsonObject(
            with:Data(contentsOf:journal)) as? [String:Any])
        data["drafts"]=7
        try JSONSerialization.data(withJSONObject:data).write(to:journal,options:.atomic)
        XCTAssertThrowsError(try v.commitInactive())
        XCTAssertThrowsError(try lab(dir).recover())
        XCTAssertTrue(FileManager.default.fileExists(atPath:journal.path))
    }
    func testIncompleteOrDemoSourceNeverGetsStaged() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let v=try lab(dir)
        let truncated=try changed{$0.removeValue(forKey:"allergies")}
        XCTAssertThrowsError(try v.stage(truncated))
        let fake=try changed {root in
            var workers=root["workers"] as! [[String:Any]]
            workers[0]["name"]="PERSONA FICTICIA"
            root["workers"]=workers
        }
        XCTAssertThrowsError(try v.stage(fake))
        XCTAssertEqual(try v.recover(),.empty)
    }
    func testExternalOrOccupiedDirectoriesAndSymlinkAreRefused() throws {
        let path=location();defer{try? FileManager.default.removeItem(at:path)}
        XCTAssertThrowsError(try lab(
            FileManager.default.temporaryDirectory.appendingPathComponent("DANPER-N1M-REAL-STAGING")))
        let v=try lab(path)
        try Data("rogue".utf8).write(to:path.appendingPathComponent("clinical.json"))
        XCTAssertThrowsError(try lab(path)){
            XCTAssertEqual($0 as? N1oInactiveTransactionLab.Failure,.unexpectedFiles)
        }
        try FileManager.default.removeItem(at:path.appendingPathComponent("clinical.json"))
        try v.stage(snapshot())
        let bad=path.appendingPathComponent("candidate.sealed.gcm")
        try FileManager.default.createSymbolicLink(at:bad,
            withDestinationURL:path.appendingPathComponent("missing.gcm"))
        XCTAssertThrowsError(try lab(path).recover()) {
            XCTAssertEqual($0 as? N1oInactiveTransactionLab.Failure,.unsafeEntry)
        }
    }
    func testNewFutureFieldsChangeDomainHashRatherThanBeingTruncated() throws {
        let dir=location();defer{try? FileManager.default.removeItem(at:dir)}
        let before=try snapshot()
        let extended=try changed{ root in
            var attentions=root["attentions"] as! [[String:Any]]
            attentions[0]["futureNote"]=["remain":true,"unknown":NSNull()]
            root["attentions"]=attentions
        }
        let base=try lab(dir).stage(before)
        let shadow=try lab(location())
        // A distinct, fresh synthetic directory can independently verify the
        // extension fingerprint; no source content is sent to logs.
        let a=try shadow.stage(extended)
        XCTAssertNotEqual(base.semanticSHA256,a.semanticSHA256)
        XCTAssertNotEqual(base.collectionHashes["attentions"],a.collectionHashes["attentions"])
        XCTAssertEqual(base.collectionHashes["workers"],a.collectionHashes["workers"])
        XCTAssertEqual(a.drafts,base.drafts)
    }
}
