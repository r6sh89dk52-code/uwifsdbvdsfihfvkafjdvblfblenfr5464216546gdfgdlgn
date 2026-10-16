import Foundation
import XCTest
@testable import DanperCore

final class N1DurableRestoreSandboxTests: XCTestCase {
    private let workers = Data("N1-CANARY|fictional-worker-1".utf8)
    private let clinical = Data("N1-CANARY|fictional-visit-1".utf8)

    private func dir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "danper-n1c-synthetic-" + UUID().uuidString, isDirectory: true)
    }
    private func lab(_ url: URL) throws -> N1DurableRestoreSandbox {
        try N1DurableRestoreSandbox(root: url)
    }
    private func crash(_ point: N1DurableRestoreSandbox.Checkpoint)
        -> (N1DurableRestoreSandbox.Checkpoint) throws -> Void {
        { actual in
            if actual == point { throw SimulatedCrash.triggered }
        }
    }
    private enum SimulatedCrash: Error { case triggered }

    func testNormalTwoDomainCommitSurvivesRestarts() throws {
        let url = dir(); defer { try? FileManager.default.removeItem(at: url) }
        let store = try lab(url)
        let id = try store.prepare(workers: workers, clinical: clinical)
        XCTAssertNil(try store.activeGenerationID())
        try store.commit()
        let reboot = try lab(url)
        XCTAssertEqual(try reboot.recover(), .committed(id))
        XCTAssertEqual(try reboot.activeGenerationID(), id)
        XCTAssertEqual(try lab(url).recover(), .committed(id))
        XCTAssertThrowsError(try reboot.prepare(workers: workers, clinical: clinical))
    }

    func testCrashAfterFirstStageCannotExposeHalfARecord() throws {
        let url = dir(); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try lab(url).prepare(workers: workers, clinical: clinical,
                   fault: crash(.workersStaged)))
        let reboot = try lab(url)
        XCTAssertEqual(try reboot.recover(), .empty)
        XCTAssertNil(try reboot.activeGenerationID())
    }
    func testCrashAfterSecondStageCannotExposeHalfARecord() throws {
        let url = dir(); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try lab(url).prepare(workers: workers, clinical: clinical,
                   fault: crash(.clinicalStaged)))
        XCTAssertEqual(try lab(url).recover(), .empty)
        XCTAssertNil(try lab(url).activeGenerationID())
    }
    func testCrashWithJournalButWithoutPointerRollsBackIntent() throws {
        let url = dir(); defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try lab(url).prepare(workers: workers, clinical: clinical,
                   fault: crash(.journalPersisted)))
        let reboot = try lab(url)
        XCTAssertEqual(try reboot.recover(), .abandonedBeforeCommit)
        XCTAssertNil(try reboot.activeGenerationID())
        XCTAssertEqual(try reboot.recover(), .empty)
        // New synthetic attempt can be staged without treating leftovers as active.
        let id = try reboot.prepare(workers: workers, clinical: clinical)
        try reboot.commit()
        XCTAssertEqual(try lab(url).recover(), .committed(id))
    }
    func testCrashAfterAtomicPointerReplaysWithoutDoubleCommit() throws {
        let url = dir(); defer { try? FileManager.default.removeItem(at: url) }
        let store = try lab(url)
        let id = try store.prepare(workers: workers, clinical: clinical)
        XCTAssertThrowsError(try store.commit(fault: crash(.pointerCommitted)))
        let reboot = try lab(url)
        XCTAssertEqual(try reboot.recover(), .committed(id))
        XCTAssertEqual(try reboot.recover(), .committed(id))
        XCTAssertThrowsError(try reboot.commit())
        XCTAssertThrowsError(try reboot.prepare(workers: workers, clinical: clinical))
    }

    func testCorruptClinicalStageBeforeCommitDoesNotActivate() throws {
        let url = dir(); defer { try? FileManager.default.removeItem(at: url) }
        let store = try lab(url)
        try store.prepare(workers: workers, clinical: clinical)
        try store.corruptStagedClinicalForTest()
        XCTAssertThrowsError(try store.commit())
        XCTAssertNil(try store.activeGenerationID())
        XCTAssertEqual(try lab(url).recover(), .abandonedBeforeCommit)
    }
    func testCorruptionAfterCommitFailsClosedAndRetainsPointer() throws {
        let url = dir(); defer { try? FileManager.default.removeItem(at: url) }
        let store = try lab(url)
        try store.prepare(workers: workers, clinical: clinical)
        XCTAssertThrowsError(try store.commit(fault: crash(.pointerCommitted)))
        try store.corruptStagedClinicalForTest()
        let reboot = try lab(url)
        XCTAssertThrowsError(try reboot.recover())
        XCTAssertThrowsError(try reboot.activeGenerationID())
        XCTAssertThrowsError(try reboot.prepare(workers: workers, clinical: clinical))
    }
    func testUnauthorizedDataAndDirectoryRejected() throws {
        let url = dir(); defer { try? FileManager.default.removeItem(at: url) }
        let store = try lab(url)
        XCTAssertThrowsError(try store.prepare(workers: workers,
            clinical: Data("{\"dni\":\"12345678\"}".utf8)))
        XCTAssertNil(try store.activeGenerationID())
        XCTAssertThrowsError(try lab(FileManager.default.temporaryDirectory
            .appendingPathComponent("a-normal-clinical-folder")))
    }
    func testMetadataTamperingFailsClosed() throws {
        let url = dir(); defer { try? FileManager.default.removeItem(at: url) }
        let store = try lab(url)
        try store.prepare(workers: workers, clinical: clinical)
        let journal = url.appendingPathComponent("restore-journal.json")
        try Data("{\"id\":\"../../escape\"}".utf8).write(to: journal, options: .atomic)
        XCTAssertThrowsError(try lab(url).recover())
        XCTAssertNil(try store.activeGenerationID())
    }
}
