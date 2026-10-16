import Foundation
import XCTest
@testable import DanperCore

/// N1m tests ONLY in a randomly named OS temporary synthetic directory.
/// Real patient data and .danperbackup passwords never enter GitHub CI.
final class N1mRealClinicalStagingTests: XCTestCase {
    private enum Crash: Error { case simulated }
    private let key = Data(repeating:0x67,count:32)
    private func temp() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("danper-n1m-synthetic-" + UUID().uuidString)
    }
    private func stage(_ path:URL, key:Data? = nil) throws -> N1mRealClinicalStagingVault {
        try N1mRealClinicalStagingVault(directory:path,keyData:key ?? self.key)
    }
    private func snapshot() throws -> Data {
        guard let dir=ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"],
              !dir.isEmpty else { throw XCTSkip("No N1f synthetic fixtures") }
        let data=try Data(contentsOf:URL(fileURLWithPath:dir)
                                .appendingPathComponent("n1f-source.json"))
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        var roster=root["workers"] as! [[String:Any]]
        roster[0]["name"]="IDENTIDAD SINTETICA ALFA"
        roster[1]["name"]="IDENTIDAD SINTETICA BETA"
        root["workers"]=roster
        var visits=root["attentions"] as! [[String:Any]]
        var a=visits[0]["worker"] as! [String:Any]
        a["name"]="IDENTIDAD SINTETICA ALFA"
        visits[0]["worker"]=a
        var fix=visits[2]["worker"] as! [String:Any]
        fix["name"]="IDENTIDAD SINTETICA ALFA"
        visits[2]["worker"]=fix
        root["attentions"]=visits
        return try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys])
    }
    private func modified(_ edit:(inout [String:Any])->Void) throws -> Data {
        var root=try XCTUnwrap(
            JSONSerialization.jsonObject(with:snapshot()) as? [String:Any])
        edit(&root)
        return try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys])
    }
    func testOneSourceAllNineCollectionsStagedWithoutActivation() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        let original=try snapshot(),v=try stage(dir)
        XCTAssertNil(try v.inspectPrepared())
        let receipt=try v.prepare(original)
        XCTAssertFalse(receipt.canActivate)
        XCTAssertEqual(receipt.workers,2)
        XCTAssertEqual(receipt.attentions,3)
        XCTAssertEqual(receipt.drafts,2)
        XCTAssertEqual(receipt.movements,0)
        XCTAssertEqual(receipt.unresolvedConsumptions,1)
        XCTAssertEqual(receipt.sourceSHA256.count,64)
        XCTAssertEqual(try stage(dir).inspectPrepared()?.semanticSHA256,
                       receipt.semanticSHA256)
        let files=try FileManager.default.contentsOfDirectory(atPath:dir.path)
        XCTAssertEqual(Set(files),Set(["complete-source.gcm","prepared-receipt.json"]))
        let cipher=try Data(contentsOf:dir.appendingPathComponent("complete-source.gcm"))
        XCTAssertNil(cipher.range(of:Data("IDENTIDAD SINTETICA ALFA".utf8)))
        XCTAssertNil(cipher.range(of:Data("CEFALEA".utf8)))
    }
    func testCannotAppendOrReplacePreparedSourceEvenSameWorkers() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        let original=try snapshot()
        let store=try stage(dir)
        let first=try store.prepare(original)
        XCTAssertEqual(try store.prepare(original).sourceSHA256,first.sourceSHA256)
        let different=try modified { root in
            var a=root["attentions"] as! [[String:Any]]
            a[0]["diagnosis"]="VALOR FICTICIO MODIFICADO"
            root["attentions"]=a
        }
        XCTAssertThrowsError(try store.prepare(different)) {
            XCTAssertEqual($0 as? N1mRealClinicalStagingVault.Failure,.sourceConflict)
        }
        XCTAssertEqual(try store.inspectPrepared()?.sourceSHA256,first.sourceSHA256)
    }
    func testCrashAfterWritingCiphertextCanResumeOnlySameBackup() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        let original=try snapshot(),store=try stage(dir)
        XCTAssertThrowsError(try store.prepare(original,fault:{ point in
            if point == .ciphertextWritten { throw Crash.simulated }
        }))
        XCTAssertThrowsError(try stage(dir).inspectPrepared()) {
            XCTAssertEqual($0 as? N1mRealClinicalStagingVault.Failure,.incompleteStaging)
        }
        let alternate=try modified { $0["futureTop"]=["changed":true] }
        XCTAssertThrowsError(try store.prepare(alternate)) {
            XCTAssertEqual($0 as? N1mRealClinicalStagingVault.Failure,.sourceConflict)
        }
        let done=try stage(dir).prepare(original)
        XCTAssertEqual(try stage(dir).inspectPrepared()?.sourceSHA256,
                       done.sourceSHA256)
    }
    func testCrashBeforeReceiptAndAfterReceiptIsRecoverable() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        let original=try snapshot(),store=try stage(dir)
        XCTAssertThrowsError(try store.prepare(original,fault:{ point in
            if point == .ciphertextVerified { throw Crash.simulated }
        }))
        XCTAssertThrowsError(try store.inspectPrepared())
        XCTAssertThrowsError(try store.prepare(original,fault:{ point in
            if point == .receiptWritten { throw Crash.simulated }
        }))
        XCTAssertNotNil(try stage(dir).inspectPrepared())
    }
    func testInvalidPasswordDerivedKeyIsNeverTreatedAsEmpty() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        try stage(dir).prepare(snapshot())
        let other=try stage(dir,key:Data(repeating:0x68,count:32))
        XCTAssertThrowsError(try other.inspectPrepared())
        XCTAssertThrowsError(try other.prepare(snapshot()))
        XCTAssertNotNil(try stage(dir).inspectPrepared())
        XCTAssertThrowsError(try stage(dir,key:Data(repeating:0x01,count:16))) {
            XCTAssertEqual($0 as? N1mRealClinicalStagingVault.Failure,.badKey)
        }
    }
    func testManipulatedCiphertextAndReceiptCannotSilentlyReset() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        let store=try stage(dir)
        try store.prepare(snapshot())
        let receipt=dir.appendingPathComponent("prepared-receipt.json")
        var json=try XCTUnwrap(JSONSerialization.jsonObject(
            with:Data(contentsOf:receipt)) as? [String:Any])
        json["workers"]=999
        try JSONSerialization.data(withJSONObject:json).write(to:receipt,options:.atomic)
        XCTAssertThrowsError(try store.inspectPrepared()) {
            XCTAssertEqual($0 as? N1mRealClinicalStagingVault.Failure,.invalidReceipt)
        }
        XCTAssertThrowsError(try store.prepare(snapshot()))
        // No destructive rewrite: original encrypted bytes stay untouched.
        XCTAssertTrue(FileManager.default.fileExists(
            atPath:dir.appendingPathComponent("complete-source.gcm").path))
    }
    func testCorruptedEncryptedRecordAndMissingReceiptFailClosed() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        let store=try stage(dir)
        try store.prepare(snapshot())
        let url=dir.appendingPathComponent("complete-source.gcm")
        var bytes=try Data(contentsOf:url)
        bytes[14] ^= 0x80
        try bytes.write(to:url,options:.atomic)
        XCTAssertThrowsError(try store.inspectPrepared()) {
            XCTAssertEqual($0 as? N1mRealClinicalStagingVault.Failure,.damagedCiphertext)
        }
        try FileManager.default.removeItem(at:dir.appendingPathComponent("prepared-receipt.json"))
        XCTAssertThrowsError(try store.inspectPrepared())
    }
    func testRejectsUnverifiedOrKnownDemoSource() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        let store=try stage(dir)
        let fixture=try Data(contentsOf:URL(fileURLWithPath:try XCTUnwrap(
            ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"]))
            .appendingPathComponent("n1f-source.json"))
        XCTAssertThrowsError(try store.prepare(fixture)) {
            XCTAssertEqual($0 as? N1mRealClinicalStagingVault.Failure,.unverifiedSnapshot)
        }
        XCTAssertNil(try store.inspectPrepared())
        XCTAssertThrowsError(try store.prepare(Data("{}".utf8)))
    }
    func testRejectsDuplicatedWorkersAndUnknownMissingFields() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        let store=try stage(dir)
        let dupe=try modified { root in
            var workers=root["workers"] as! [[String:Any]]
            workers[1]["dni"]=workers[0]["dni"]
            root["workers"]=workers
        }
        XCTAssertThrowsError(try store.prepare(dupe))
        let partial=try modified { $0.removeValue(forKey:"stockMovements") }
        XCTAssertThrowsError(try store.prepare(partial))
        XCTAssertNil(try store.inspectPrepared())
    }
    func testDirectoryIsolationCannotMixWithN1gDemoOrExternalFiles() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        XCTAssertThrowsError(try stage(
            FileManager.default.temporaryDirectory.appendingPathComponent("DANPER-N1I-DEMO")))
        let first=try stage(dir)
        let stray=dir.appendingPathComponent("worker-demo.json")
        try Data("{}".utf8).write(to:stray)
        XCTAssertThrowsError(try stage(dir)) {
            XCTAssertEqual($0 as? N1mRealClinicalStagingVault.Failure,.unexpectedFiles)
        }
        XCTAssertThrowsError(try first.prepare(Data("{}".utf8)))
    }
    func testCompleteSourceIncludesIncompleteDraftAndUnknownExtensions() throws {
        let dir=temp();defer { try? FileManager.default.removeItem(at:dir) }
        let source=try snapshot(), prepared=try stage(dir).prepare(source)
        let report=try N1fLosslessFieldGate.inspect(source)
        XCTAssertEqual(prepared.semanticSHA256,report.semanticSHA256)
        XCTAssertEqual(prepared.drafts,2)
        XCTAssertFalse(prepared.canActivate)
    }
}
