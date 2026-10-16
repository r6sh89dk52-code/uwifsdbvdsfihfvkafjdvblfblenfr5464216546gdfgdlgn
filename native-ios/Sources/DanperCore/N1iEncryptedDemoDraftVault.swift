import Foundation
import Crypto

/// N1i copy-on-write AES-256-GCM store limited to the strict synthetic
/// N1gClinic JSON schema. Key bytes are injected (a distinct iOS Keychain
/// service supplies them in the preview app) and never stored here.
/// App data may ONLY be under its dedicated Application Support demo folder;
/// tests may ONLY run in immediate OS temp subdirectories with the prefix below.
public final class N1iEncryptedDemoDraftVault {
    public enum Checkpoint: Equatable {
        case ciphertextWritten, ciphertextVerified, pointerWritten
    }
    public enum Failure: Error, Equatable {
        case unsafeLocation, badKey, missingRecord, malformedPointer
        case corruptedCiphertext, conflictingCommit, invalidDemoData
    }
    private struct Pointer: Codable, Equatable {
        let version: Int
        let generation: String
        let ciphertextSHA256: String
        let authentication: String
    }
    private let root: URL
    private let key: SymmetricKey
    private let fm = FileManager.default
    private let pointerName = "active-demo-draft.json"
    private static let scope = "DANPER-N1I-DEMO-DRAFT|v1|"

    public init(root: URL, keyData: Data) throws {
        guard keyData.count == 32 else { throw Failure.badKey }
        let canonical = root.standardizedFileURL
        let temp = fm.temporaryDirectory.standardizedFileURL
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.standardizedFileURL
        let tempAllowed = canonical.lastPathComponent.hasPrefix("danper-n1i-synthetic-") &&
            canonical.deletingLastPathComponent().standardizedFileURL == temp
        let appAllowed = canonical.lastPathComponent == "DANPER-N1I-DEMO" &&
            canonical.deletingLastPathComponent().standardizedFileURL == appSupport
        guard tempAllowed || appAllowed else { throw Failure.unsafeLocation }
        if !fm.fileExists(atPath: canonical.path) {
            try fm.createDirectory(at: canonical, withIntermediateDirectories: false)
        }
        let meta = try canonical.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard meta.isDirectory == true, meta.isSymbolicLink != true else {
            throw Failure.unsafeLocation
        }
        self.root = canonical
        self.key = SymmetricKey(data: keyData)
    }
    private func location(_ name: String) -> URL {
        root.appendingPathComponent(name, isDirectory: false)
    }
    private func fileName(_ generation: String) -> String {
        "draft-" + generation + ".gcm"
    }
    private func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format:"%02x", $0) }.joined()
    }
    private func message(_ gen: String, _ digest: String) -> Data {
        Data((Self.scope + gen + "|" + digest).utf8)
    }
    private func mac(_ gen: String, _ digest: String) -> String {
        Data(HMAC<SHA256>.authenticationCode(for: message(gen,digest), using:key))
            .base64EncodedString()
    }
    private func readFile(_ name: String) throws -> Data? {
        let file = location(name)
        guard fm.fileExists(atPath:file.path) else { return nil }
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw Failure.malformedPointer
        }
        return try Data(contentsOf:file)
    }
    private func writeFile(_ data: Data, name: String) throws {
        let dst=location(name)
        try data.write(to:dst, options:.atomic)
        #if canImport(UIKit)
        try fm.setAttributes([.protectionKey: FileProtectionType.complete],ofItemAtPath:dst.path)
        #endif
        guard try readFile(name) == data else { throw Failure.corruptedCiphertext }
    }
    private func readPointer() throws -> Pointer? {
        guard let raw = try readFile(pointerName) else { return nil }
        guard raw.count < 2048,
              let pointer = try? JSONDecoder().decode(Pointer.self,from:raw),
              pointer.version == 1,
              let uuid=UUID(uuidString:pointer.generation),
              uuid.uuidString == pointer.generation,
              pointer.ciphertextSHA256.count == 64,
              pointer.ciphertextSHA256.utf8.allSatisfy({
                (48...57).contains($0) || (97...102).contains($0)
              }),
              pointer.authentication == mac(pointer.generation,pointer.ciphertextSHA256)
        else { throw Failure.malformedPointer }
        return pointer
    }
    private func authenticate(_ pointer: Pointer) throws -> N1gClinic {
        guard let encrypted = try readFile(fileName(pointer.generation)),
              encrypted.count >= 28, encrypted.count <= 65_600 else {
            throw Failure.missingRecord
        }
        guard digest(encrypted) == pointer.ciphertextSHA256 else {
            throw Failure.corruptedCiphertext
        }
        let plain: Data
        do {
            let box=try AES.GCM.SealedBox(combined:encrypted)
            plain=try AES.GCM.open(box,using:key,
                authenticating:Data((Self.scope + pointer.generation).utf8))
        } catch { throw Failure.corruptedCiphertext }
        do { return try N1iDemoArchiveCodec.decode(plain) }
        catch { throw Failure.invalidDemoData }
    }
    /// Returns nil only when the store is genuinely empty; tampering,
    /// an invalid key, or missing files cause an error (fail closed).
    public func load() throws -> N1gClinic? {
        guard let pointer = try readPointer() else { return nil }
        return try authenticate(pointer)
    }
    /// Stage + verify before the single logical activation pointer. Old
    /// generations are intentionally retained to avoid destructive rollback.
    /// No fsync/anti-rollback guarantee yet; used only with demo data.
    @discardableResult
    public func save(_ clinic: N1gClinic,
                     fault: ((Checkpoint) throws -> Void)? = nil) throws -> String {
        let expectedGeneration = try readPointer()
        if let active=expectedGeneration { _ = try authenticate(active) }
        let plain: Data
        do { plain=try N1iDemoArchiveCodec.encode(clinic) }
        catch { throw Failure.invalidDemoData }
        let generation=UUID().uuidString
        let sealed: Data
        do {
            let result=try AES.GCM.seal(plain, using:key,
                authenticating:Data((Self.scope + generation).utf8))
            guard let combined=result.combined else { throw Failure.corruptedCiphertext }
            sealed=combined
        } catch { throw Failure.corruptedCiphertext }
        try writeFile(sealed,name:fileName(generation))
        try fault?(.ciphertextWritten)
        let receipt=Pointer(version:1,generation:generation,
            ciphertextSHA256:digest(sealed),
            authentication:mac(generation,digest(sealed)))
        _ = try authenticate(receipt)
        try fault?(.ciphertextVerified)
        guard try readPointer() == expectedGeneration else {
            throw Failure.conflictingCommit
        }
        try writeFile(try JSONEncoder().encode(receipt),name:pointerName)
        try fault?(.pointerWritten)
        guard try readPointer() == receipt else { throw Failure.malformedPointer }
        _ = try authenticate(receipt)
        return generation
    }
}
