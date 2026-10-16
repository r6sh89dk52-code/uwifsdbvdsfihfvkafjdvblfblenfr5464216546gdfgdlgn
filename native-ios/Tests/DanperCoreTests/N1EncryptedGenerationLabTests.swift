import Foundation
import Crypto
import XCTest
@testable import DanperCore

final class N1EncryptedGenerationLabTests: XCTestCase {
    private let roster = Data("N1D-CANARY|worker-fictitious".utf8)
    private let clinical = Data("N1D-CANARY|clinical-fictitious".utf8)
    private let goodKey = SymmetricKey(data: Data(repeating: 0x31, count: 32))
    private let wrongKey = SymmetricKey(data: Data(repeating: 0x72, count: 32))
    private enum SimulatedCrash: Error { case triggered }
    private func url() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("danper-n1d-synthetic-" + UUID().uuidString)
    }
    private func open(_ url: URL, _ key: SymmetricKey? = nil) throws -> N1EncryptedGenerationLab {
        try N1EncryptedGenerationLab(root: url, key: key ?? goodKey)
    }
    private func crash(_ point: N1EncryptedGenerationLab.Checkpoint)
      -> (N1EncryptedGenerationLab.Checkpoint) throws -> Void {
        { at in if at == point { throw SimulatedCrash.triggered } }
    }
    func testEncryptedDataAndAtomicCommitAreReopenable() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        let lab = try open(dir)
        let id = try lab.prepare(workers: roster, clinical: clinical)
        let encryptedW = try lab.encryptedStageBytesForTest(domain: "workers")
        let encryptedC = try lab.encryptedStageBytesForTest(domain: "clinical")
        XCTAssertNil(encryptedW.range(of: Data("worker-fictitious".utf8)))
        XCTAssertNil(encryptedC.range(of: Data("clinical-fictitious".utf8)))
        XCTAssertNil(encryptedW.range(of: Data("N1D-CANARY|".utf8)))
        XCTAssertNotEqual(encryptedW, encryptedC)
        XCTAssertNil(try lab.activeGenerationID())
        try lab.commit()
        let reboot = try open(dir)
        XCTAssertEqual(try reboot.recover(), .committed(id))
        XCTAssertEqual(try reboot.activeGenerationID(), id)
        XCTAssertEqual(try reboot.recover(), .committed(id))
        XCTAssertThrowsError(try reboot.prepare(workers: roster, clinical: clinical))
    }
    func testCrashAfterFirstEncryptedFileDoesNotExposePartialRecord() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertThrowsError(try open(dir).prepare(
            workers: roster, clinical: clinical, fault: crash(.workersEncrypted)))
        XCTAssertEqual(try open(dir).recover(), .empty)
        XCTAssertNil(try open(dir).activeGenerationID())
    }
    func testCrashAfterSecondEncryptedFileDoesNotExposePartialRecord() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertThrowsError(try open(dir).prepare(
            workers: roster, clinical: clinical, fault: crash(.clinicalEncrypted)))
        XCTAssertEqual(try open(dir).recover(), .empty)
        XCTAssertNil(try open(dir).activeGenerationID())
    }
    func testCrashAfterJournalRollsBackWithoutDeletingStages() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertThrowsError(try open(dir).prepare(
            workers: roster, clinical: clinical, fault: crash(.journalWritten)))
        let reboot = try open(dir)
        XCTAssertEqual(try reboot.recover(), .rolledBackUncommitted)
        XCTAssertEqual(try reboot.recover(), .empty)
        let newId = try reboot.prepare(workers: roster, clinical: clinical)
        try reboot.commit()
        XCTAssertEqual(try open(dir).recover(), .committed(newId))
    }
    func testCrashAfterPointerIsReconciledOnlyOnce() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        let lab = try open(dir)
        let id = try lab.prepare(workers: roster, clinical: clinical)
        XCTAssertThrowsError(try lab.commit(fault: crash(.pointerWritten)))
        let reboot = try open(dir)
        XCTAssertEqual(try reboot.recover(), .committed(id))
        XCTAssertEqual(try reboot.recover(), .committed(id))
        XCTAssertThrowsError(try reboot.commit())
    }
    func testWrongKeyCannotReadCommittedDataOrOverwrite() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        let lab = try open(dir)
        try lab.prepare(workers: roster, clinical: clinical)
        try lab.commit()
        let wrong = try open(dir, wrongKey)
        XCTAssertThrowsError(try wrong.recover())
        XCTAssertThrowsError(try wrong.prepare(workers: roster, clinical: clinical))
        XCTAssertNotNil(try open(dir).activeGenerationID())
    }
    func testTamperedCiphertextFailsClosedBeforeCommit() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        let lab = try open(dir)
        try lab.prepare(workers: roster, clinical: clinical)
        try lab.alterCiphertextForTest(domain: "clinical")
        XCTAssertThrowsError(try lab.commit())
        XCTAssertNil(try lab.activeGenerationID())
        XCTAssertEqual(try open(dir).recover(), .rolledBackUncommitted)
    }
    func testTamperedCommittedStageCannotBeExposedOrErased() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        let lab = try open(dir)
        try lab.prepare(workers: roster, clinical: clinical)
        try lab.commit()
        try lab.alterCiphertextForTest(domain: "workers")
        let reboot = try open(dir)
        XCTAssertThrowsError(try reboot.recover())
        XCTAssertThrowsError(try reboot.activeGenerationID())
        XCTAssertThrowsError(try reboot.prepare(workers: roster, clinical: clinical))
    }
    func testSwappedCiphertextsAreBoundToGenerationAndDomain() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        let lab = try open(dir)
        let id = try lab.prepare(workers: roster, clinical: clinical)
        let w = dir.appendingPathComponent("workers-" + id + ".gcm")
        let c = dir.appendingPathComponent("clinical-" + id + ".gcm")
        let originalW = try Data(contentsOf: w)
        let originalC = try Data(contentsOf: c)
        try originalC.write(to: w, options: .atomic)
        try originalW.write(to: c, options: .atomic)
        XCTAssertThrowsError(try lab.commit())
        XCTAssertNil(try lab.activeGenerationID())
    }
    func testReceiptTamperingFailsAuthentication() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        let lab = try open(dir)
        try lab.prepare(workers: roster, clinical: clinical)
        let path = dir.appendingPathComponent("pending-encrypted.json")
        var receipt = try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as! [String: Any]
        receipt["workersSHA256"] = String(repeating: "f", count: 64)
        try JSONSerialization.data(withJSONObject: receipt).write(to: path, options: .atomic)
        XCTAssertThrowsError(try lab.commit())
        XCTAssertThrowsError(try open(dir).recover())
    }
    func testRejectNonSyntheticPayloadAndUnexpectedDirectory() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        let lab = try open(dir)
        XCTAssertThrowsError(try lab.prepare(workers: roster,
                           clinical: Data("actual-dni-12345678".utf8)))
        XCTAssertNil(try lab.activeGenerationID())
        XCTAssertThrowsError(try N1EncryptedGenerationLab(
            root: FileManager.default.temporaryDirectory.appendingPathComponent("clinical"),
            key: goodKey))
    }
    func testMissingEncryptedStageBlocksActivation() throws {
        let dir = url(); defer { try? FileManager.default.removeItem(at: dir) }
        let lab = try open(dir)
        let id = try lab.prepare(workers: roster, clinical: clinical)
        try FileManager.default.removeItem(
            at: dir.appendingPathComponent("clinical-" + id + ".gcm"))
        XCTAssertThrowsError(try lab.commit())
        XCTAssertNil(try lab.activeGenerationID())
    }
}
