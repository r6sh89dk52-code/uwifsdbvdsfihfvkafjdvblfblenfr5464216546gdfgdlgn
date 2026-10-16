import Foundation
import Crypto

/// N1b synthetic model of a two-domain commit. Does not touch Files/Keychain.
/// It intentionally rejects clinical snapshots; NOT a real restore service.
internal struct N1SyntheticRestoreCoordinator: Codable {
    internal struct Generation: Codable, Equatable {
        var id: String
        var workersSHA256: String
        var clinicalSHA256: String
        var workersVerified: Bool
        var clinicalVerified: Bool
    }
    private(set) var activeGenerationID: String? = nil
    private(set) var pendingGenerationID: String? = nil
    private(set) var staged: [String: Generation] = [:]

    enum RestoreError: Error { case activeRecordsExist, invalidSyntheticInput
        case incompleteStage, alreadyPending, alteredStage }

    private static func synthetic(_ source: Data) -> Bool {
        source.starts(with: Data("N1-SYNTHETIC-ONLY|".utf8))
    }
    private static func sha(_ raw: Data) -> String {
        SHA256.hash(data: raw).map { String(format: "%02x", $0) }.joined()
    }

    /// Prepare isolated stage and intent; never changes activeGenerationID.
    mutating func prepare(id: String, workers: Data, clinical: Data) throws {
        guard activeGenerationID == nil else { throw RestoreError.activeRecordsExist }
        guard pendingGenerationID == nil else { throw RestoreError.alreadyPending }
        guard !id.isEmpty, staged[id] == nil,
              Self.synthetic(workers), Self.synthetic(clinical),
              workers.count < 4096, clinical.count < 4096 else {
            throw RestoreError.invalidSyntheticInput
        }
        staged[id] = Generation(id: id, workersSHA256: Self.sha(workers),
                                clinicalSHA256: Self.sha(clinical),
                                workersVerified: true, clinicalVerified: true)
        pendingGenerationID = id
    }

    mutating func corruptStagedVerificationForTest(id: String) {
        staged[id]?.clinicalVerified = false
    }

    /// One logical pointer switch is the whole commit in this fake model.
    mutating func activate() throws {
        guard activeGenerationID == nil else { throw RestoreError.activeRecordsExist }
        guard let id = pendingGenerationID, let generation = staged[id] else {
            throw RestoreError.incompleteStage
        }
        guard generation.workersVerified, generation.clinicalVerified else {
            throw RestoreError.alteredStage
        }
        activeGenerationID = id
    }

    /// Recover after "process death" by reconstructing Codable state.
    /// If activation never happened, abort; if it happened, finalize idempotently.
    mutating func reconcileAfterRestart() {
        if let pending = pendingGenerationID {
            // Commit is recognized only if the single active pointer already flipped.
            if activeGenerationID != pending { staged.removeValue(forKey: pending) }
        }
        pendingGenerationID = nil
    }
}
