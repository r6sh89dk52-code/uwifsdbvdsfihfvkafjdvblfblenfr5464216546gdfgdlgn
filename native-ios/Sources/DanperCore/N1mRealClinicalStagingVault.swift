import Foundation
import Crypto

/// N1m isolates ONE complete build222 snapshot in encrypted, INACTIVE staging.
/// No merge, no clinical activation, no N1g data, and no production Keychain.
/// The only disk payload is AES-256-GCM authenticated ciphertext. The receipt
/// contains checksums and counts, never patient names, identifiers or visits.
/// Callers must later confirm true source provenance; encryption cannot prove
/// the absence of unidentified fictional records.
public final class N1mRealClinicalStagingVault {
    public enum Failure: Error, Equatable {
        case badKey, unsafeDirectory, unexpectedFiles, symlink
        case incompleteStaging, sourceConflict, unverifiedSnapshot
        case damagedCiphertext, invalidReceipt, sizeExceeded
    }
    public enum Checkpoint: Equatable {
        case ciphertextWritten, ciphertextVerified, receiptWritten
    }
    public struct Prepared: Sendable {
        public let sourceSHA256: String
        public let semanticSHA256: String
        public let workers: Int
        public let attentions: Int
        public let drafts: Int
        public let movements: Int
        public let unresolvedConsumptions: Int
        /// This is STAGING ONLY, not authority to write to a clinical vault.
        public let canActivate: Bool
    }
    private struct Receipt: Codable {
        let version: Int
        let sourceSHA256: String
        let semanticSHA256: String
        let ciphertextSHA256: String
        let workers: Int
        let attentions: Int
        let drafts: Int
        let movements: Int
        let unresolvedConsumptions: Int
        let mac: String
    }

    private let directory: URL
    private let key: SymmetricKey
    private let fileManager = FileManager.default
    private let encryptedName = "complete-source.gcm"
    private let receiptName = "prepared-receipt.json"
    private static let scope = "DANPER-N1M-REAL-STAGING|v1"
    private static let maximum = 30 * 1024 * 1024
    private static let permitted = Set(["complete-source.gcm","prepared-receipt.json"])

    public init(directory: URL, keyData: Data) throws {
        guard keyData.count == 32 else { throw Failure.badKey }
        let path = directory.standardizedFileURL
        let temp = fileManager.temporaryDirectory.standardizedFileURL
        let appSupport = fileManager.urls(for:.applicationSupportDirectory,in:.userDomainMask)
            .first?.standardizedFileURL
        let synthetic = path.lastPathComponent.hasPrefix("danper-n1m-synthetic-") &&
            path.deletingLastPathComponent() == temp
        let native = path.lastPathComponent == "DANPER-N1M-REAL-STAGING" &&
            path.deletingLastPathComponent() == appSupport
        guard synthetic || native else { throw Failure.unsafeDirectory }
        if fileManager.fileExists(atPath:path.path) {
            let v=try path.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
            guard v.isDirectory == true && v.isSymbolicLink != true else {
                throw Failure.unsafeDirectory
            }
        } else {
            try fileManager.createDirectory(at:path,withIntermediateDirectories:false)
        }
        // Fail closed: no unexpected clinical vault, backups or fake demo state
        // may share this directory, even if the stage files are absent.
        let files=try fileManager.contentsOfDirectory(atPath:path.path)
        guard files.allSatisfy({Self.permitted.contains($0)}) else {
            throw Failure.unexpectedFiles
        }
        self.directory=path
        self.key=SymmetricKey(data:keyData)
    }
    private func url(_ name:String) -> URL {
        directory.appendingPathComponent(name,isDirectory:false)
    }
    private func read(_ name:String) throws -> Data? {
        let location=url(name)
        guard fileManager.fileExists(atPath:location.path) else { return nil }
        let meta=try location.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
        guard meta.isRegularFile == true && meta.isSymbolicLink != true else {
            throw Failure.symlink
        }
        return try Data(contentsOf:location)
    }
    private func write(_ bytes:Data,to name:String) throws {
        guard bytes.count <= Self.maximum + 4096 else { throw Failure.sizeExceeded }
        let dest=url(name)
        // Never write through a symlink even if a previous run left one.
        if fileManager.fileExists(atPath:dest.path) {
            let meta=try dest.resourceValues(forKeys:[.isSymbolicLinkKey,.isRegularFileKey])
            guard meta.isSymbolicLink != true && meta.isRegularFile == true else {
                throw Failure.symlink
            }
        }
        try bytes.write(to:dest,options:.atomic)
        #if canImport(UIKit)
        try fileManager.setAttributes([.protectionKey:FileProtectionType.complete],
                                       ofItemAtPath:dest.path)
        #endif
        guard try read(name) == bytes else { throw Failure.damagedCiphertext }
    }
    private static func sha(_ bytes:Data) -> String {
        SHA256.hash(data:bytes).map { String(format:"%02x",$0) }.joined()
    }
    private static func hex64(_ string:String) -> Bool {
        string.count == 64 && string.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }
    private func signature(_ r:Receipt) -> String {
        let msg=[Self.scope,String(r.version),r.sourceSHA256,
                 r.semanticSHA256,r.ciphertextSHA256,String(r.workers),
                 String(r.attentions),String(r.drafts),String(r.movements),
                 String(r.unresolvedConsumptions)].joined(separator:"|")
        return Data(HMAC<SHA256>.authenticationCode(for:Data(msg.utf8),using:key))
            .base64EncodedString()
    }
    private func validate(_ data:Data) throws -> N1lSourceAudit {
        guard !data.isEmpty && data.count <= Self.maximum else {
            throw Failure.sizeExceeded
        }
        do {
            let report=try N1lRealSnapshotGate.audit(data,destination:.verifiedEmpty)
            guard report.isStructurallyEligibleForReview else {
                throw Failure.unverifiedSnapshot
            }
            return report
        } catch { throw Failure.unverifiedSnapshot }
    }
    private func decode(_ encrypted:Data) throws -> Data {
        guard encrypted.count >= 28 && encrypted.count <= Self.maximum+4096 else {
            throw Failure.damagedCiphertext
        }
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined:encrypted),
                       using:key,authenticating:Data(Self.scope.utf8))
        } catch { throw Failure.damagedCiphertext }
    }
    private func receipt(_ data:Data) throws -> Receipt {
        guard data.count < 4096,
              let r=try? JSONDecoder().decode(Receipt.self,from:data),
              r.version == 1, r.workers >= 0, r.attentions >= 0,
              r.drafts >= 0, r.movements >= 0, r.unresolvedConsumptions >= 0,
              Self.hex64(r.sourceSHA256),Self.hex64(r.semanticSHA256),
              Self.hex64(r.ciphertextSHA256),r.mac == signature(r) else {
            throw Failure.invalidReceipt
        }
        return r
    }
    private func verified(_ encrypted:Data, _ receipt:Receipt) throws -> Prepared {
        guard Self.sha(encrypted) == receipt.ciphertextSHA256 else {
            throw Failure.damagedCiphertext
        }
        let source=try decode(encrypted)
        guard Self.sha(source) == receipt.sourceSHA256 else {
            throw Failure.damagedCiphertext
        }
        let reviewed=try validate(source)
        guard reviewed.semanticSHA256 == receipt.semanticSHA256,
              reviewed.manifest.workers == receipt.workers,
              reviewed.manifest.attentions == receipt.attentions,
              reviewed.drafts == receipt.drafts,
              reviewed.manifest.movements == receipt.movements,
              reviewed.unresolvedClinicalConsumptions == receipt.unresolvedConsumptions else {
            throw Failure.invalidReceipt
        }
        return Prepared(sourceSHA256:receipt.sourceSHA256,
                        semanticSHA256:receipt.semanticSHA256,
                        workers:receipt.workers,attentions:receipt.attentions,
                        drafts:receipt.drafts,movements:receipt.movements,
                        unresolvedConsumptions:receipt.unresolvedConsumptions,
                        canActivate:false)
    }
    /// No plaintext leaves this class. An orphan encrypted stage after a crash
    /// requires reselecting the SAME original source to resume (never resets).
    public func inspectPrepared() throws -> Prepared? {
        let original=try read(encryptedName)
        let receiptData=try read(receiptName)
        if original == nil && receiptData == nil { return nil }
        guard let original,let receiptData else { throw Failure.incompleteStaging }
        return try verified(original,receipt(receiptData))
    }
    /// Stages EXACT source bytes, without conversion to a lossy model.
    /// A second, different source cannot replace already encrypted bytes.
    /// Passing the same snapshot after a power interruption resumes safely.
    @discardableResult
    public func prepare(_ source:Data,
                        fault:((Checkpoint) throws -> Void)? = nil) throws -> Prepared {
        let report=try validate(source)
        let originalSHA=Self.sha(source)
        let cipher:Data
        if let previous=try read(encryptedName) {
            let prior=try decode(previous)
            guard prior == source else { throw Failure.sourceConflict }
            cipher=previous
        } else {
            guard try read(receiptName) == nil else { throw Failure.incompleteStaging }
            let sealed=try AES.GCM.seal(source,using:key,
                                         authenticating:Data(Self.scope.utf8))
            guard let combined=sealed.combined else { throw Failure.damagedCiphertext }
            cipher=combined
            try write(cipher,to:encryptedName)
            try fault?(.ciphertextWritten)
        }
        let constructed=Receipt(
            version:1,sourceSHA256:originalSHA,
            semanticSHA256:report.semanticSHA256,
            ciphertextSHA256:Self.sha(cipher),
            workers:report.manifest.workers,
            attentions:report.manifest.attentions,
            drafts:report.drafts,
            movements:report.manifest.movements,
            unresolvedConsumptions:report.unresolvedClinicalConsumptions,
            mac:"")
        let receipt=Receipt(version:constructed.version,
             sourceSHA256:constructed.sourceSHA256,
             semanticSHA256:constructed.semanticSHA256,
             ciphertextSHA256:constructed.ciphertextSHA256,
             workers:constructed.workers,attentions:constructed.attentions,
             drafts:constructed.drafts,movements:constructed.movements,
             unresolvedConsumptions:constructed.unresolvedConsumptions,
             mac:signature(constructed))
        // An existing receipt must be verified instead of overwritten.
        if let present=try read(receiptName) {
            let previous=try verified(cipher,self.receipt(present))
            guard previous.sourceSHA256 == originalSHA else {
                throw Failure.sourceConflict
            }
            return previous
        }
        _=try validate(try decode(cipher))
        try fault?(.ciphertextVerified)
        try write(try JSONEncoder().encode(receipt),to:receiptName)
        try fault?(.receiptWritten)
        return try verified(cipher,receipt)
    }
}
