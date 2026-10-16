import Foundation
import Crypto
import XCTest
@testable import DanperCore

final class N1jMonotonicAutosaveTests: XCTestCase {
    private enum Interruption: Error { case interruption }
    private let key = Data(repeating: 0x35, count: 32)
    private func temp() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("danper-n1i-synthetic-" + UUID().uuidString)
    }
    private func open(_ url: URL) throws -> N1iEncryptedDemoDraftVault {
        try N1iEncryptedDemoDraftVault(root:url,keyData:key)
    }
    private func mock() throws -> (N1gClinic, UUID) {
        var c = N1gClinic()
        let id = c.newDraft(at:100)
        try c.edit(id,.worker("00000001"),at:101)
        try c.edit(id,.category("ENFERMEDAD"),at:102)
        try c.edit(id,.system("RESPIRATORIO"),at:103)
        try c.edit(id,.diagnosis("CEFALEA FICTICIA"),at:104)
        try c.edit(id,.procedure("OBSERVACION"),at:105)
        try c.reviewAllergy(.none,for:"00000001")
        return (c,id)
    }
    func testClockUsesRecoveredRevisionAndRejectsOverflow() throws {
        var clock = N1jRevisionClock(recoveredRevision: 53)
        XCTAssertEqual(clock.latest, 53)
        XCTAssertEqual(try clock.capture(),54)
        XCTAssertFalse(clock.isLatest(53))
        XCTAssertTrue(clock.isLatest(54))
        var nearMax=N1jRevisionClock(recoveredRevision:Int64.max)
        XCTAssertThrowsError(try nearMax.capture()) { e in
            XCTAssertEqual(e as? N1jRevisionClock.Failure, .exhausted)
        }
    }
    func testFirstCommitAndReopenCarryVerifiedRevision() throws {
        let root=temp();defer{try? FileManager.default.removeItem(at:root)}
        let (demo,_) = try mock()
        let store=try open(root)
        XCTAssertNil(try store.loadWithRevision())
        try store.save(demo,revision:7)
        let reopened=try XCTUnwrap(try open(root).loadWithRevision())
        XCTAssertEqual(reopened.revision,7)
        XCTAssertEqual(reopened.clinic.visits,demo.visits)
        XCTAssertEqual(try store.activeRevision(),7)
    }
    func testOutOfOrderAndEqualRevisionCannotOverwrite() throws {
        let root=temp();defer{try? FileManager.default.removeItem(at:root)}
        var (demo,id)=try mock()
        let stale=demo
        try demo.edit(id,.quantity(9),at:150)
        let store=try open(root)
        try store.save(demo,revision:11)
        XCTAssertThrowsError(try store.save(stale,revision:10)) { e in
            XCTAssertEqual(e as? N1iEncryptedDemoDraftVault.Failure,.staleRevision)
        }
        XCTAssertThrowsError(try store.save(stale,revision:11))
        XCTAssertEqual(try store.load()?.activeDraft?.quantity,9)
        XCTAssertEqual(try store.activeRevision(),11)
    }
    func testStaleJobsRemainBlockedAfterProcessRestart() throws {
        let root=temp();defer{try? FileManager.default.removeItem(at:root)}
        var (demo,id)=try mock()
        let prev=demo
        try open(root).save(prev,revision:22)
        try demo.edit(id,.quantity(5),at:210)
        try open(root).save(demo,revision:23)
        let restarted=try open(root)
        XCTAssertEqual(try restarted.activeRevision(),23)
        XCTAssertThrowsError(try restarted.save(prev,revision:22))
        XCTAssertEqual(try restarted.load()?.activeDraft?.quantity,5)
    }
    func testInterruptBeforeActivationLeavesPreviousRevisionAvailable() throws {
        let root=temp();defer{try? FileManager.default.removeItem(at:root)}
        var (demo,id)=try mock()
        let store=try open(root)
        try store.save(demo,revision:31)
        try demo.edit(id,.quantity(4),at:260)
        XCTAssertThrowsError(try store.save(demo,revision:32,fault:{ at in
            if at == .ciphertextVerified { throw Interruption.interruption }
        }))
        XCTAssertEqual(try open(root).activeRevision(),31)
        XCTAssertEqual(try open(root).load()?.activeDraft?.quantity,1)
        try open(root).save(demo,revision:32)
        XCTAssertEqual(try open(root).activeRevision(),32)
    }
    func testInterruptAfterActivationRecoversNewRevision() throws {
        let root=temp();defer{try? FileManager.default.removeItem(at:root)}
        var (demo,id)=try mock()
        try open(root).save(demo,revision:48)
        try demo.edit(id,.quantity(8),at:270)
        XCTAssertThrowsError(try open(root).save(demo,revision:49,fault:{ at in
            if at == .pointerWritten { throw Interruption.interruption }
        }))
        let reopened=try open(root)
        XCTAssertEqual(try reopened.activeRevision(),49)
        XCTAssertEqual(try reopened.load()?.activeDraft?.quantity,8)
        XCTAssertThrowsError(try reopened.save(demo,revision:48))
    }
    func testForgedRevisionWithoutHMACUpdateIsRejected() throws {
        let root=temp();defer{try? FileManager.default.removeItem(at:root)}
        let (demo,_) = try mock()
        let store=try open(root)
        try store.save(demo,revision:3)
        let pointer=root.appendingPathComponent("active-demo-draft.json")
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:
            Data(contentsOf:pointer)) as? [String:Any])
        XCTAssertEqual(json["version"] as? Int,2)
        json["revision"]=4
        try JSONSerialization.data(withJSONObject:json).write(to:pointer,options:.atomic)
        XCTAssertThrowsError(try store.loadWithRevision())
        XCTAssertThrowsError(try store.save(demo,revision:5))
    }
    func testDowngradingPointerVersionOrRemovingRevisionFailsClosed() throws {
        let root=temp();defer{try? FileManager.default.removeItem(at:root)}
        let (demo,_) = try mock()
        let store=try open(root)
        try store.save(demo,revision:100)
        let path=root.appendingPathComponent("active-demo-draft.json")
        var json=try XCTUnwrap(JSONSerialization.jsonObject(with:
            Data(contentsOf:path)) as? [String:Any])
        json["version"]=1
        json.removeValue(forKey:"revision")
        try JSONSerialization.data(withJSONObject:json).write(to:path,options:.atomic)
        XCTAssertThrowsError(try store.loadWithRevision())
    }
    func testSecondWriterWinsOnlyIfFirstConflictsBeforePointerCommit() throws {
        let root=temp();defer{try? FileManager.default.removeItem(at:root)}
        var (a,id)=try mock()
        let x=try open(root),y=try open(root)
        try x.save(a,revision:60)
        try a.edit(id,.quantity(3),at:300)
        let first=a
        try a.edit(id,.quantity(7),at:301)
        let second=a
        XCTAssertThrowsError(try x.save(first,revision:61,fault:{ at in
            if at == .ciphertextVerified { try y.save(second,revision:62) }
        })) { e in
            XCTAssertEqual(e as? N1iEncryptedDemoDraftVault.Failure,.conflictingCommit)
        }
        XCTAssertEqual(try open(root).activeRevision(),62)
        XCTAssertEqual(try open(root).load()?.activeDraft?.quantity,7)
    }
    func testLegacyN1iV1PointerCanBeReadAndUpgradedWithoutReset() throws {
        let root=temp();defer{try? FileManager.default.removeItem(at:root)}
        let (demo,_)=try mock()
        _ = try open(root)
        let originalKey=SymmetricKey(data:key)
        let generation=UUID().uuidString
        let prefix="DANPER-N1I-DEMO-DRAFT|v1|"
        let clear=try N1iDemoArchiveCodec.encode(demo)
        let sealed=try AES.GCM.seal(clear,using:originalKey,
                   authenticating:Data((prefix+generation).utf8))
        let bytes=try XCTUnwrap(sealed.combined)
        let digest=SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined()
        let h=Data(HMAC<SHA256>.authenticationCode(
            for:Data((prefix+generation+"|"+digest).utf8),
            using:originalKey)).base64EncodedString()
        let pointer:[String:Any]=["version":1,"generation":generation,
           "ciphertextSHA256":digest,"authentication":h]
        try bytes.write(to:root.appendingPathComponent("draft-"+generation+".gcm"),options:.atomic)
        try JSONSerialization.data(withJSONObject:pointer).write(
            to:root.appendingPathComponent("active-demo-draft.json"),options:.atomic)
        let upgraded=try open(root)
        XCTAssertEqual(try upgraded.loadWithRevision()?.revision,0)
        try upgraded.save(demo,revision:1)
        XCTAssertEqual(try upgraded.loadWithRevision()?.revision,1)
    }
}
