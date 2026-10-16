import Foundation
import Crypto

/// N1c: *synthetic-only*, file-backed crash-recovery proof on Linux.
/// NEVER pass a clinical backup here; this intentionally refuses non-canary input.
/// This is not an iOS Keychain adapter or production clinical data store.
internal final class N1DurableRestoreSandbox {
    enum Checkpoint: Equatable {
        case workersStaged, clinicalStaged, journalPersisted, pointerCommitted
    }
    enum Failure: Error, Equatable {
        case unauthorizedLocation, notSynthetic, tooLarge, alreadyOccupied
        case pendingOperation, missingJournal, corruptMetadata, missingStage
        case alteredStage, conflict
    }
    enum Recovery: Equatable {
        case empty, abandonedBeforeCommit, committed(String)
    }
    private struct Receipt: Codable, Equatable {
        let version: Int
        let id: String
        let workersDigest: String
        let clinicalDigest: String
    }

    private let root: URL
    private let fm = FileManager.default
    private let fixturePrefix = Data("N1-CANARY|".utf8)
    private let journalFile = "restore-journal.json"
    private let pointerFile = "active-generation.json"

    /// Restrict this proof to a newly named immediate child of the OS temp dir.
    init(root: URL) throws {
        let canonical = root.standardizedFileURL
        guard canonical.lastPathComponent.hasPrefix("danper-n1c-synthetic-"),
              canonical.deletingLastPathComponent().standardizedFileURL ==
                fm.temporaryDirectory.standardizedFileURL else {
            throw Failure.unauthorizedLocation
        }
        self.root = canonical
        // Reopening an existing sandbox models process restart on Linux.
        // Linux FileManager throws EEXIST for createDirectory(false).
        if !fm.fileExists(atPath: canonical.path) {
            do {
                try fm.createDirectory(at: canonical, withIntermediateDirectories: false)
            } catch {
                let check = try? canonical.resourceValues(
                    forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard check?.isDirectory == true, check?.isSymbolicLink != true else {
                    throw error
                }
            }
        }
        let flags = try canonical.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard flags.isDirectory == true, flags.isSymbolicLink != true else {
            throw Failure.unauthorizedLocation
        }
    }

    private func location(_ filename: String) -> URL {
        root.appendingPathComponent(filename, isDirectory: false)
    }
    private func workersFile(_ id: String) -> String { "workers-\(id).canary" }
    private func clinicalFile(_ id: String) -> String { "clinical-\(id).canary" }

    private func read(_ filename: String) throws -> Data? {
        let url = location(filename)
        guard fm.fileExists(atPath: url.path) else { return nil }
        let flags = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard flags.isRegularFile == true, flags.isSymbolicLink != true else {
            throw Failure.corruptMetadata
        }
        return try Data(contentsOf: url)
    }
    private func save(_ data: Data, as filename: String) throws {
        // Writes an atomic replacement within our synthetic-only private sandbox.
        try data.write(to: location(filename), options: [.atomic])
        guard try read(filename) == data else { throw Failure.alteredStage }
    }
    private func readReceipt(_ name: String) throws -> Receipt? {
        guard let raw = try read(name) else { return nil }
        guard raw.count < 2048,
              let record = try? JSONDecoder().decode(Receipt.self, from: raw),
              record.version == 1,
              let parsedUUID = UUID(uuidString: record.id),
              parsedUUID.uuidString == record.id,
              Self.isHexDigest(record.workersDigest),
              Self.isHexDigest(record.clinicalDigest) else {
            throw Failure.corruptMetadata
        }
        return record
    }
    private static func isHexDigest(_ s: String) -> Bool {
        s.count == 64 && s.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }
    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func requireCanary(_ data: Data) throws {
        guard data.starts(with: fixturePrefix) else { throw Failure.notSynthetic }
        guard data.count > fixturePrefix.count && data.count <= 4096 else {
            throw Failure.tooLarge
        }
    }
    private func verify(_ receipt: Receipt) throws {
        guard let workerData = try read(workersFile(receipt.id)),
              let clinicalData = try read(clinicalFile(receipt.id)) else {
            throw Failure.missingStage
        }
        try requireCanary(workerData)
        try requireCanary(clinicalData)
        guard digest(workerData) == receipt.workersDigest,
              digest(clinicalData) == receipt.clinicalDigest else {
            throw Failure.alteredStage
        }
    }

    /// Prepare two complete generations and an on-disk intent record.
    /// The active pointer is still absent, even if a simulated crash occurs.
    @discardableResult
    func prepare(workers: Data, clinical: Data,
                 fault: ((Checkpoint) throws -> Void)? = nil) throws -> String {
        try requireCanary(workers)
        try requireCanary(clinical)
        if try readReceipt(pointerFile) != nil { throw Failure.alreadyOccupied }
        if try readReceipt(journalFile) != nil { throw Failure.pendingOperation }
        let id = UUID().uuidString
        let receipt = Receipt(version: 1, id: id,
                              workersDigest: digest(workers),
                              clinicalDigest: digest(clinical))
        try save(workers, as: workersFile(id))
        try fault?(.workersStaged)
        try save(clinical, as: clinicalFile(id))
        try fault?(.clinicalStaged)
        try verify(receipt)
        try save(JSONEncoder().encode(receipt), as: journalFile)
        try fault?(.journalPersisted)
        return id
    }

    /// Atomic logical commit point: ONE pointer for BOTH domains.
    /// No file is deleted and no journal is cleared until the pointer is verified.
    func commit(fault: ((Checkpoint) throws -> Void)? = nil) throws {
        guard let receipt = try readReceipt(journalFile) else {
            throw Failure.missingJournal
        }
        guard try readReceipt(pointerFile) == nil else { throw Failure.conflict }
        try verify(receipt)
        try save(JSONEncoder().encode(receipt), as: pointerFile)
        guard try readReceipt(pointerFile) == receipt else { throw Failure.corruptMetadata }
        try fault?(.pointerCommitted)
        try fm.removeItem(at: location(journalFile))
    }

    /// Call on a fresh instance to model app restart.
    /// Before pointer activation, safely drops only the intent record.
    /// After pointer activation, verifies BOTH staged files and finalizes
    /// journal idempotently; damage fails closed without clearing evidence.
    @discardableResult
    func recover() throws -> Recovery {
        let active = try readReceipt(pointerFile)
        let pending = try readReceipt(journalFile)
        if let active {
            if let pending, pending != active { throw Failure.conflict }
            try verify(active)
            if pending != nil { try fm.removeItem(at: location(journalFile)) }
            return .committed(active.id)
        }
        if pending != nil {
            try fm.removeItem(at: location(journalFile))
            return .abandonedBeforeCommit
        }
        return .empty
    }

    /// Exposes ONLY the synthetic generation ID, never records.
    func activeGenerationID() throws -> String? {
        guard let active = try readReceipt(pointerFile) else { return nil }
        try verify(active)
        return active.id
    }

    /// Test-only function for fault injection, path is derived from a receipt UUID.
    func corruptStagedClinicalForTest() throws {
        guard let receipt = try readReceipt(journalFile) ?? readReceipt(pointerFile) else {
            throw Failure.missingJournal
        }
        try save(Data("N1-CANARY|TAMPERED".utf8), as: clinicalFile(receipt.id))
    }
}
