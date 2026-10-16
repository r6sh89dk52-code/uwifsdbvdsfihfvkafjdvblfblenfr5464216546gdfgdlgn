import Foundation
import XCTest
@testable import DanperCore

final class N1SyntheticRecoveryTests: XCTestCase {
    private let workers = Data("N1-SYNTHETIC-ONLY|WORKERS-A".utf8)
    private let clinical = Data("N1-SYNTHETIC-ONLY|CLINICAL-A".utf8)

    func testCrashBeforeActivationKeepsExistingStateUntouched() throws {
        var stage = N1SyntheticRestoreCoordinator()
        try stage.prepare(id: "G1", workers: workers, clinical: clinical)
        XCTAssertNil(stage.activeGenerationID)
        let persisted = try JSONEncoder().encode(stage)
        var rebooted = try JSONDecoder().decode(N1SyntheticRestoreCoordinator.self, from: persisted)
        rebooted.reconcileAfterRestart()
        XCTAssertNil(rebooted.activeGenerationID)
        XCTAssertNil(rebooted.pendingGenerationID)
        XCTAssertNil(rebooted.staged["G1"])
    }
    func testCrashAfterCommitCompletesWithoutDuplicate() throws {
        var stage = N1SyntheticRestoreCoordinator()
        try stage.prepare(id: "G1", workers: workers, clinical: clinical)
        try stage.activate()
        let persisted = try JSONEncoder().encode(stage)
        var rebooted = try JSONDecoder().decode(N1SyntheticRestoreCoordinator.self, from: persisted)
        rebooted.reconcileAfterRestart()
        rebooted.reconcileAfterRestart()
        XCTAssertEqual(rebooted.activeGenerationID, "G1")
        XCTAssertNil(rebooted.pendingGenerationID)
        XCTAssertEqual(rebooted.staged.count, 1)
        XCTAssertThrowsError(try rebooted.prepare(id:"G2", workers:workers, clinical:clinical))
    }
    func testCorruptedStagedPairIsNeverActivated() throws {
        var stage = N1SyntheticRestoreCoordinator()
        try stage.prepare(id:"G1", workers: workers, clinical: clinical)
        stage.corruptStagedVerificationForTest(id:"G1")
        XCTAssertThrowsError(try stage.activate())
        XCTAssertNil(stage.activeGenerationID)
    }
    func testRejectsNonSyntheticClinicalPayload() {
        var stage = N1SyntheticRestoreCoordinator()
        XCTAssertThrowsError(try stage.prepare(id:"G1", workers:workers,
                                               clinical: Data("{\"patients\":[]}".utf8)))
        XCTAssertNil(stage.pendingGenerationID)
    }
}
