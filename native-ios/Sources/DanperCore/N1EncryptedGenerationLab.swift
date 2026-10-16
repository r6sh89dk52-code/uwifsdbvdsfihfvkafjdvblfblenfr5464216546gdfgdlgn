import Foundation
import Crypto

/// N1d: encrypted, file-backed rehearsal restricted to fictional canaries.
/// Its key is supplied by the caller; this class NEVER stores a key on disk.
/// Not an iOS Keychain implementation or a clinical restoration service.
internal final class N1EncryptedGenerationLab {
    enum Checkpoint: Equatable {
        case workersEncrypted, clinicalEncrypted, journalWritten, pointerWritten
    }
    enum Failure: Error, Equatable {
        case invalidLocation, invalidCanary, oversized, occupied, pending
        case missingJournal, missingData, corruptRecord, authenticationFailed
        case inconsistentGeneration, concurrentActivation
    }
    enum Recovery: Equatable {
        case empty, rolledBackUncommitted, committed(String)
    }
    private struct Receipt: Codable, Equatable {
        let version: Int
        let generation: String
        let workersSHA256: String
        let clinicalSHA256: String
        let mac: String
    }
    private let root: URL
    private let key: SymmetricKey
    private let fm = FileManager.default
    private let canary = Data("N1D-CANARY|".utf8)
    private let journal = "pending-encrypted.json"
    private let pointer = "active-encrypted.json"

    init(root: URL, key: SymmetricKey) throws {
        let dir = root.standardizedFileURL
        let parent = fm.temporaryDirectory.standardizedFileURL
        guard dir.deletingLastPathComponent() == parent,
              dir.lastPathComponent.hasPrefix("danper-n1d-synthetic-") else {
            throw Failure.invalidLocation
        }
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: false)
        }
        let values = try dir.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true && values.isSymbolicLink != true else {
            throw Failure.invalidLocation
        }
        self.root = dir
        self.key = key
    }

    private func file(_ name: String) -> URL {
        root.appendingPathComponent(name, isDirectory: false)
    }
    private func stageName(_ kind: String, _ generation: String) -> String {
        "\(kind)-\(generation).gcm"
    }
    private func read(_ name: String) throws -> Data? {
        let path = file(name)
        guard fm.fileExists(atPath: path.path) else { return nil }
        let attrs = try path.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard attrs.isRegularFile == true && attrs.isSymbolicLink != true else {
            throw Failure.corruptRecord
        }
        return try Data(contentsOf: path)
    }
    private func write(_ data: Data, to name: String) throws {
        try data.write(to: file(name), options: .atomic)
        guard try read(name) == data else { throw Failure.corruptRecord }
    }
    private func requireSynthetic(_ data: Data) throws {
        guard data.starts(with: canary) else { throw Failure.invalidCanary }
        guard data.count > canary.count && data.count <= 4096 else {
            throw Failure.oversized
        }
    }
    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func authMessage(_ generation: String, _ workers: String, _ clinical: String) -> Data {
        Data("DANPER-N1D-MANIFEST|v1|\(generation)|\(workers)|\(clinical)".utf8)
    }
    private func mac(generation: String, workers: String, clinical: String) -> String {
        Data(HMAC<SHA256>.authenticationCode(
            for: authMessage(generation, workers, clinical), using: key
        )).base64EncodedString()
    }
    private func receipt(generation: String, workers: Data, clinical: Data) -> Receipt {
        let wh = digest(workers)
        let ch = digest(clinical)
        return Receipt(version: 1, generation: generation, workersSHA256: wh,
                       clinicalSHA256: ch,
                       mac: mac(generation: generation, workers: wh, clinical: ch))
    }
    private func readReceipt(_ name: String) throws -> Receipt? {
        guard let data = try read(name) else { return nil }
        guard data.count < 2048,
              let value = try? JSONDecoder().decode(Receipt.self, from: data),
              value.version == 1,
              let id = UUID(uuidString: value.generation),
              id.uuidString == value.generation,
              value.workersSHA256.count == 64,
              value.clinicalSHA256.count == 64,
              let storedMAC = Data(base64Encoded: value.mac),
              storedMAC.count == 32 else {
            throw Failure.corruptRecord
        }
        let expectedMessage = authMessage(value.generation, value.workersSHA256,
                                          value.clinicalSHA256)
        guard HMAC<SHA256>.isValidAuthenticationCode(storedMAC,
                authenticating: expectedMessage, using: key) else {
            throw Failure.authenticationFailed
        }
        return value
    }
    private func aad(_ generation: String, _ domain: String) -> Data {
        Data("DANPER-N1D|v1|\(generation)|\(domain)".utf8)
    }
    private func encrypt(_ raw: Data, generation: String, domain: String) throws {
        try requireSynthetic(raw)
        let box = try AES.GCM.seal(raw, using: key,
                      authenticating: aad(generation, domain))
        guard let combined = box.combined else { throw Failure.corruptRecord }
        try write(combined, to: stageName(domain, generation))
    }
    private func decrypt(_ generation: String, domain: String) throws -> Data {
        guard let data = try read(stageName(domain, generation)) else {
            throw Failure.missingData
        }
        guard data.count >= 28 && data.count <= 8192,
              let box = try? AES.GCM.SealedBox(combined: data),
              let raw = try? AES.GCM.open(box, using: key,
                       authenticating: aad(generation, domain)) else {
            throw Failure.authenticationFailed
        }
        try requireSynthetic(raw)
        return raw
    }
    private func verify(_ entry: Receipt) throws {
        let workers = try decrypt(entry.generation, domain: "workers")
        let clinical = try decrypt(entry.generation, domain: "clinical")
        guard digest(workers) == entry.workersSHA256,
              digest(clinical) == entry.clinicalSHA256 else {
            throw Failure.inconsistentGeneration
        }
    }

    /// Encrypted copies are stored and checked before writing a durable journal.
    /// The active pointer is NEVER changed during preparation.
    @discardableResult
    func prepare(workers: Data, clinical: Data,
                 fault: ((Checkpoint) throws -> Void)? = nil) throws -> String {
        try requireSynthetic(workers)
        try requireSynthetic(clinical)
        if try readReceipt(pointer) != nil { throw Failure.occupied }
        if try readReceipt(journal) != nil { throw Failure.pending }
        let id = UUID().uuidString
        try encrypt(workers, generation: id, domain: "workers")
        try fault?(.workersEncrypted)
        try encrypt(clinical, generation: id, domain: "clinical")
        try fault?(.clinicalEncrypted)
        let entry = receipt(generation: id, workers: workers, clinical: clinical)
        try verify(entry)
        try write(JSONEncoder().encode(entry), to: journal)
        try fault?(.journalWritten)
        return id
    }
    /// One atomic pointer makes BOTH authenticated encrypted files visible.
    func commit(fault: ((Checkpoint) throws -> Void)? = nil) throws {
        guard let entry = try readReceipt(journal) else { throw Failure.missingJournal }
        if try readReceipt(pointer) != nil { throw Failure.concurrentActivation }
        try verify(entry)
        try write(JSONEncoder().encode(entry), to: pointer)
        guard try readReceipt(pointer) == entry else { throw Failure.corruptRecord }
        try fault?(.pointerWritten)
        try fm.removeItem(at: file(journal))
    }
    /// Reopen the directory with the SAME external key after a process death.
    /// An uncommitted journal is abandoned; an active pair is fully verified.
    @discardableResult
    func recover() throws -> Recovery {
        let active = try readReceipt(pointer)
        let pending = try readReceipt(journal)
        if let active {
            if let pending, pending != active { throw Failure.inconsistentGeneration }
            try verify(active)
            if pending != nil { try fm.removeItem(at: file(journal)) }
            return .committed(active.generation)
        }
        if pending != nil {
            try fm.removeItem(at: file(journal))
            return .rolledBackUncommitted
        }
        return .empty
    }
    func activeGenerationID() throws -> String? {
        guard let active = try readReceipt(pointer) else { return nil }
        try verify(active)
        return active.generation
    }
    /// Test-only mutation, never decrypts or logs record content.
    func alterCiphertextForTest(domain: String) throws {
        guard domain == "workers" || domain == "clinical" else {
            throw Failure.invalidCanary
        }
        guard let entry = try readReceipt(journal) ?? readReceipt(pointer) else {
            throw Failure.missingJournal
        }
        let name = stageName(domain, entry.generation)
        guard var bytes = try read(name), bytes.count > 20 else {
            throw Failure.missingData
        }
        bytes[bytes.count - 1] ^= 0x01
        try write(bytes, to: name)
    }
    /// Read only encrypted stage bytes to assert that no clinical-like text
    /// leaks on disk. No method in this lab returns decrypted records.
    func encryptedStageBytesForTest(domain: String) throws -> Data {
        guard domain == "workers" || domain == "clinical",
              let entry = try readReceipt(journal) ?? readReceipt(pointer),
              let bytes = try read(stageName(domain, entry.generation)) else {
            throw Failure.missingData
        }
        return bytes
    }
}
