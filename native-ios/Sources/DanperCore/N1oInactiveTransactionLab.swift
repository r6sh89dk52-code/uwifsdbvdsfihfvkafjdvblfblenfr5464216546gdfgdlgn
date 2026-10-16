import Foundation
import Crypto

/// N1o: a TWO-PHASE encrypted rehearsal in the OS temporary directory.
/// This is not a clinical database, importer, or live activation pointer.
/// The only committed pointer is explicitly marked INACTIVE, never exposed
/// to SwiftUI and never consulted by any production medical workflow.
internal final class N1oInactiveTransactionLab {
    enum Failure: Error, Equatable {
        case invalidDirectory, invalidKey, unexpectedFiles, unsafeEntry
        case invalidSource, sourceConflict, incomplete, recoveryRequired
        case invalidReceipt, alteredCiphertext, occupied, missingJournal
        case wrongKey, invalidState
    }
    enum Checkpoint: Equatable {
        case encryptedWritten, journalWritten, sealedRenamed, inactivePointerWritten
    }
    enum Recovery: Equatable {
        case empty, pending, inactiveVerified
    }
    struct Summary: Equatable {
        let sourceSHA256: String
        let semanticSHA256: String
        let collectionCounts: [String:Int]
        let collectionHashes: [String:String]
        let drafts: Int
        let corrections: Int
        let unresolvedConsumptions: Int
        let canActivate: Bool
    }
    private struct Receipt: Codable, Equatable {
        let version: Int
        let sourceSHA256: String
        let semanticSHA256: String
        let ciphertextSHA256: String
        let collectionCounts: [String:Int]
        let collectionHashes: [String:String]
        let drafts: Int
        let corrections: Int
        let unresolvedConsumptions: Int
        let mac: String
    }

    private let root: URL
    private let key: SymmetricKey
    private let fm = FileManager.default
    private let pendingName = "candidate.pending.gcm"
    private let sealedName = "candidate.sealed.gcm"
    private let journalName = "inactive-intent.json"
    private let pointerName = "inactive-verified.json"
    private static let aad = Data("DANPER|N1O|INACTIVE|v1".utf8)
    private static let sizeLimit = 30 * 1024 * 1024
    private static let permitted: Set<String> = [
        "candidate.pending.gcm", "candidate.sealed.gcm",
        "inactive-intent.json", "inactive-verified.json"
    ]

    init(directory: URL, keyData: Data) throws {
        guard keyData.count == 32 else { throw Failure.invalidKey }
        let path = directory.standardizedFileURL
        guard path.deletingLastPathComponent() == fm.temporaryDirectory.standardizedFileURL,
              path.lastPathComponent.hasPrefix("danper-n1o-synthetic-") else {
            throw Failure.invalidDirectory
        }
        if fm.fileExists(atPath:path.path) {
            let meta = try path.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
            guard meta.isDirectory == true && meta.isSymbolicLink != true else {
                throw Failure.invalidDirectory
            }
        } else {
            try fm.createDirectory(at:path,withIntermediateDirectories:false)
        }
        guard try fm.contentsOfDirectory(atPath:path.path)
                .allSatisfy({Self.permitted.contains($0)}) else {
            throw Failure.unexpectedFiles
        }
        root=path
        key=SymmetricKey(data:keyData)
    }
    private func path(_ name:String) -> URL {
        root.appendingPathComponent(name,isDirectory:false)
    }
    private func read(_ name:String) throws -> Data? {
        let location=path(name)
        // Directory enumeration catches dangling symlinks as well.
        guard try fm.contentsOfDirectory(atPath:root.path).contains(name) else { return nil }
        let meta=try location.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
        guard meta.isRegularFile == true && meta.isSymbolicLink != true else {
            throw Failure.unsafeEntry
        }
        return try Data(contentsOf:location)
    }
    private func write(_ bytes:Data, _ name:String) throws {
        guard bytes.count <= Self.sizeLimit + 4096 else { throw Failure.invalidState }
        if try fm.contentsOfDirectory(atPath:root.path).contains(name) {
            let meta=try path(name).resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
            guard meta.isRegularFile == true && meta.isSymbolicLink != true else {
                throw Failure.unsafeEntry
            }
        }
        try bytes.write(to:path(name),options:.atomic)
        guard try read(name) == bytes else { throw Failure.alteredCiphertext }
    }
    private static func hash(_ data:Data) -> String {
        SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
    }
    private static func digest(_ value:String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy{
            (48...57).contains($0) || (97...102).contains($0)
        }
    }
    private func macMessage(_ value:Receipt) -> Data {
        var parts=["DANPER|N1O|RECEIPT|v1",String(value.version),
                   value.sourceSHA256,value.semanticSHA256,value.ciphertextSHA256,
                   String(value.drafts),String(value.corrections),
                   String(value.unresolvedConsumptions)]
        for name in N1lRealSnapshotGate.collections.sorted() {
            parts.append(name)
            parts.append(String(value.collectionCounts[name] ?? -1))
            parts.append(value.collectionHashes[name] ?? "")
        }
        return Data(parts.joined(separator:"|").utf8)
    }
    private func seal(_ receipt:Receipt) -> Receipt {
        let code=Data(HMAC<SHA256>.authenticationCode(
            for:macMessage(receipt),using:key)).base64EncodedString()
        return Receipt(version:receipt.version,
                       sourceSHA256:receipt.sourceSHA256,
                       semanticSHA256:receipt.semanticSHA256,
                       ciphertextSHA256:receipt.ciphertextSHA256,
                       collectionCounts:receipt.collectionCounts,
                       collectionHashes:receipt.collectionHashes,
                       drafts:receipt.drafts,corrections:receipt.corrections,
                       unresolvedConsumptions:receipt.unresolvedConsumptions,mac:code)
    }
    private func readReceipt(_ name:String) throws -> Receipt? {
        guard let data=try read(name) else { return nil }
        guard data.count < 4096,
              let record=try? JSONDecoder().decode(Receipt.self,from:data),
              record.version == 1, record.drafts >= 0, record.corrections >= 0,
              record.unresolvedConsumptions >= 0,
              Self.digest(record.sourceSHA256),
              Self.digest(record.semanticSHA256),
              Self.digest(record.ciphertextSHA256),
              Set(record.collectionCounts.keys) == Set(N1lRealSnapshotGate.collections),
              Set(record.collectionHashes.keys) == Set(N1lRealSnapshotGate.collections),
              record.collectionCounts.values.allSatisfy({$0 >= 0}),
              record.collectionHashes.values.allSatisfy({Self.digest($0)}),
              let signature=Data(base64Encoded:record.mac),
              signature.count == 32 else { throw Failure.invalidReceipt }
        guard HMAC<SHA256>.isValidAuthenticationCode(
            signature,authenticating:macMessage(record),using:key) else {
            throw Failure.wrongKey
        }
        return record
    }
    private func sourceReport(_ raw:Data) throws -> (N1lSourceAudit,[String:Int],[String:String]) {
        guard !raw.isEmpty && raw.count <= Self.sizeLimit else {
            throw Failure.invalidSource
        }
        let audit:N1lSourceAudit
        do {
            let acknowledged=N1nAcknowledgment(originalBuild222:true,
                reviewedForDemo:true,understandsNoRestore:true)
            _=try N1nInactiveSourceGate.authorize(raw,acknowledgment:acknowledged)
            audit=try N1lRealSnapshotGate.audit(raw,destination:.verifiedEmpty)
        } catch { throw Failure.invalidSource }
        guard let root=try? JSONSerialization.jsonObject(with:raw) as? [String:Any] else {
            throw Failure.invalidSource
        }
        var counts:[String:Int]=[:],hashes:[String:String]=[:]
        for name in N1lRealSnapshotGate.collections {
            guard let value=root[name] else { throw Failure.invalidSource }
            let bytes=try JSONSerialization.data(withJSONObject:value,
                           options:[.sortedKeys,.fragmentsAllowed])
            let count:Int
            if let array=value as? [Any] { count=array.count }
            else if let object=value as? [String:Any] { count=object.count }
            else if value is NSNumber { count=1 }
            else { throw Failure.invalidSource }
            counts[name]=count
            hashes[name]=Self.hash(bytes)
        }
        return (audit,counts,hashes)
    }
    private func decrypt(_ encrypted:Data) throws -> Data {
        guard (28...Self.sizeLimit+4096).contains(encrypted.count),
              let sealed=try? AES.GCM.SealedBox(combined:encrypted),
              let plaintext=try? AES.GCM.open(sealed,using:key,
                                              authenticating:Self.aad) else {
            throw Failure.alteredCiphertext
        }
        return plaintext
    }
    private func check(_ receipt:Receipt,encrypted:Data) throws -> Summary {
        guard Self.hash(encrypted) == receipt.ciphertextSHA256 else {
            throw Failure.alteredCiphertext
        }
        let source=try decrypt(encrypted)
        guard Self.hash(source) == receipt.sourceSHA256 else {
            throw Failure.alteredCiphertext
        }
        let (audit,counts,hashes)=try sourceReport(source)
        guard audit.semanticSHA256 == receipt.semanticSHA256,
              receipt.collectionCounts == counts,
              receipt.collectionHashes == hashes,
              audit.drafts == receipt.drafts,
              audit.corrections == receipt.corrections,
              audit.unresolvedClinicalConsumptions == receipt.unresolvedConsumptions else {
            throw Failure.invalidReceipt
        }
        return Summary(sourceSHA256:receipt.sourceSHA256,
                       semanticSHA256:receipt.semanticSHA256,
                       collectionCounts:counts,collectionHashes:hashes,
                       drafts:audit.drafts,corrections:audit.corrections,
                       unresolvedConsumptions:audit.unresolvedClinicalConsumptions,
                       canActivate:false)
    }
    /// PREPARE phase: encrypted bytes first, verified journal second.
    /// If the journal is absent on restart, refuse silently clearing evidence.
    @discardableResult
    func stage(_ source:Data,fault:((Checkpoint)throws->Void)? = nil) throws -> Summary {
        let (audit,counts,hashes)=try sourceReport(source)
        if let pointer=try readReceipt(pointerName) {
            guard let cipher=try read(sealedName) else { throw Failure.incomplete }
            let existing=try check(pointer,encrypted:cipher)
            guard existing.sourceSHA256 == Self.hash(source) else {
                throw Failure.sourceConflict
            }
            return existing
        }
        if let journal=try readReceipt(journalName) {
            guard try read(sealedName) == nil else { throw Failure.recoveryRequired }
            guard let cipher=try read(pendingName) else { throw Failure.incomplete }
            let current=try check(journal,encrypted:cipher)
            guard current.sourceSHA256 == Self.hash(source) else {
                throw Failure.sourceConflict
            }
            return current
        }
        guard try read(pendingName) == nil && read(sealedName) == nil else {
            throw Failure.incomplete
        }
        let encryptedBox=try AES.GCM.seal(source,using:key,authenticating:Self.aad)
        guard let encrypted=encryptedBox.combined else { throw Failure.invalidState }
        try write(encrypted,pendingName)
        try fault?(.encryptedWritten)
        let unsigned=Receipt(version:1,sourceSHA256:Self.hash(source),
              semanticSHA256:audit.semanticSHA256,ciphertextSHA256:Self.hash(encrypted),
              collectionCounts:counts,collectionHashes:hashes,
              drafts:audit.drafts,corrections:audit.corrections,
              unresolvedConsumptions:audit.unresolvedClinicalConsumptions,mac:"")
        let receipt=seal(unsigned)
        _=try check(receipt,encrypted:encrypted)
        try write(try JSONEncoder().encode(receipt),journalName)
        try fault?(.journalWritten)
        return try check(receipt,encrypted:encrypted)
    }
    /// COMMIT is only an INACTIVE LAB pointer to the complete encrypted file.
    /// It is NEVER a pointer consumed by clinical readers.
    @discardableResult
    func commitInactive(fault:((Checkpoint)throws->Void)? = nil) throws -> Summary {
        guard try read(pointerName) == nil else { throw Failure.occupied }
        guard let journal=try readReceipt(journalName) else { throw Failure.missingJournal }
        guard try read(sealedName) == nil else { throw Failure.recoveryRequired }
        guard let cipher=try read(pendingName) else { throw Failure.incomplete }
        let report=try check(journal,encrypted:cipher)
        try fm.moveItem(at:path(pendingName),to:path(sealedName))
        try fault?(.sealedRenamed)
        guard try read(sealedName) == cipher else { throw Failure.alteredCiphertext }
        try write(try JSONEncoder().encode(journal),pointerName)
        try fault?(.inactivePointerWritten)
        guard try readReceipt(pointerName) == journal else { throw Failure.invalidReceipt }
        try fm.removeItem(at:path(journalName))
        return report
    }
    /// No automatic commit: on a crash between rename and pointer,
    /// move ciphertext BACK to pending and require explicit commitInactive.
    @discardableResult
    func recover() throws -> Recovery {
        let pointer=try readReceipt(pointerName)
        let journal=try readReceipt(journalName)
        let pending=try read(pendingName)
        let sealed=try read(sealedName)
        if let pointer {
            guard pending == nil, let sealed else { throw Failure.invalidState }
            if let journal, journal != pointer { throw Failure.invalidReceipt }
            _=try check(pointer,encrypted:sealed)
            if journal != nil { try fm.removeItem(at:path(journalName)) }
            return .inactiveVerified
        }
        if let journal {
            guard pending == nil || sealed == nil else { throw Failure.invalidState }
            if let pending {
                _=try check(journal,encrypted:pending)
                return .pending
            }
            if let sealed {
                _=try check(journal,encrypted:sealed)
                try fm.moveItem(at:path(sealedName),to:path(pendingName))
                return .pending
            }
            throw Failure.incomplete
        }
        guard pending == nil && sealed == nil else { throw Failure.incomplete }
        return .empty
    }
    func inspectInactive() throws -> Summary? {
        guard let pointer=try readReceipt(pointerName) else { return nil }
        guard try read(pendingName) == nil,
              let sealed=try read(sealedName) else { throw Failure.incomplete }
        return try check(pointer,encrypted:sealed)
    }
}
