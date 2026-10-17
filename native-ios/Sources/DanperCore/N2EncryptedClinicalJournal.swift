import Foundation
import Crypto

/// N2 encrypted journal for transactional synthetic clinical snapshots.
/// This core intentionally accepts ONLY a dedicated temporary test directory;
/// it is NOT connected to iPhone's real records or current build222 Keychain.
internal final class N2EncryptedClinicalJournal {
    enum Failure: Error, Equatable {
        case unsafeLocation, invalidKey, invalidSnapshot, missingGeneration
        case corruptJournal, authenticationFailed, staleRevision, interrupted
    }
    enum Checkpoint: Equatable {
        case encryptedGenerationWritten, pendingJournalWritten, activePointerWritten
    }
    struct Recovered {
        let revision:Int
        let snapshot:Data
    }
    private struct Receipt:Codable,Equatable {
        let version:Int
        let id:String
        let revision:Int
        let previousSHA:String
        let payloadSHA:String
        let mac:String
    }
    private let root:URL
    private let key:SymmetricKey
    private let fm=FileManager.default
    private let activeName="active-n2.json"
    private let pendingName="pending-n2.json"

    convenience init(directory:URL,secret:Data) throws {
        try self.init(location:directory,secret:secret,protected:false)
    }
    /// Dedicated App Support location is never the build222, N1i or N1m vault.
    /// Only the explicit iOS Keychain adaptor is permitted to provide its key.
    convenience init(protectedAppSupportDirectory:URL,secret:Data) throws {
        try self.init(location:protectedAppSupportDirectory,secret:secret,protected:true)
    }
    private init(location:URL,secret:Data,protected:Bool) throws {
        let path=location.standardizedFileURL
        if protected {
            guard let support=fm.urls(for:.applicationSupportDirectory,
                                     in:.userDomainMask).first?.standardizedFileURL,
                  path.deletingLastPathComponent()==support,
                  ["DANPER-N2-CLINICAL-VAULT",
                   "DANPER-N2-SYNTHETIC-VAULT"].contains(path.lastPathComponent) else {
                throw Failure.unsafeLocation
            }
        }else {
            guard path.deletingLastPathComponent() == fm.temporaryDirectory.standardizedFileURL,
                  path.lastPathComponent.hasPrefix("danper-n2-synthetic-") else {
                throw Failure.unsafeLocation
            }
        }
        guard secret.count==32 else{throw Failure.invalidKey}
        if !fm.fileExists(atPath:path.path) {
            #if os(iOS)
            let attrs:[FileAttributeKey:Any] = protected
                ? [.protectionKey: FileProtectionType.complete] : [:]
            try fm.createDirectory(at:path,withIntermediateDirectories:false,
                                   attributes:attrs)
            #else
            try fm.createDirectory(at:path,withIntermediateDirectories:false)
            #endif
        }
        let info=try path.resourceValues(forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
        guard info.isDirectory == true,info.isSymbolicLink != true else{
            throw Failure.unsafeLocation
        }
        if protected {
            #if os(iOS)
            try fm.setAttributes([.protectionKey:FileProtectionType.complete],
                                 ofItemAtPath:path.path)
            #endif
            var location=path
            var backup=URLResourceValues()
            backup.isExcludedFromBackup=true
            try location.setResourceValues(backup)
        }
        self.root=path
        self.key=SymmetricKey(data:secret)
    }
    private func file(_ name:String)->URL {
        root.appendingPathComponent(name,isDirectory:false)
    }
    private func sha(_ input:Data)->String {
        SHA256.hash(data:input).map{String(format:"%02x",$0)}.joined()
    }
    private func message(_ r:Receipt)->Data {
        Data("DANPER-N2|v1|\(r.id)|\(r.revision)|\(r.previousSHA)|\(r.payloadSHA)".utf8)
    }
    private func sign(_ r:Receipt)->String {
        Data(HMAC<SHA256>.authenticationCode(for:message(r),using:key)).base64EncodedString()
    }
    private func aad(_ id:String,_ revision:Int)->Data {
        Data("DANPER-N2-CLINICAL|v1|\(id)|\(revision)".utf8)
    }
    private func read(_ name:String) throws -> Data? {
        let path=file(name)
        guard fm.fileExists(atPath:path.path) else{return nil}
        let info=try path.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true else{
            throw Failure.corruptJournal
        }
        return try Data(contentsOf:path)
    }
    private func write(_ name:String,_ bytes:Data) throws {
        try bytes.write(to:file(name),options:.atomic)
        #if os(iOS)
        if ["DANPER-N2-CLINICAL-VAULT",
            "DANPER-N2-SYNTHETIC-VAULT"].contains(root.lastPathComponent) {
            try fm.setAttributes([.protectionKey:FileProtectionType.complete],
                                 ofItemAtPath:file(name).path)
        }
        #endif
        guard try read(name)==bytes else{throw Failure.corruptJournal}
    }
    private func checked(_ name:String)throws->Receipt? {
        guard let data=try read(name) else{return nil}
        guard data.count<2048,
              let r=try? JSONDecoder().decode(Receipt.self,from:data),
              r.version==1,(1...100_000).contains(r.revision),
              UUID(uuidString:r.id) != nil,
              r.previousSHA.isEmpty || r.previousSHA.count==64,
              r.payloadSHA.count==64,
              let mac=Data(base64Encoded:r.mac),mac.count==32,
              HMAC<SHA256>.isValidAuthenticationCode(mac,
                  authenticating:message(r),using:key) else {
            throw Failure.authenticationFailed
        }
        return r
    }
    private func validate(_ data:Data)throws {
        guard data.count>0,data.count<=30*1024*1024,
              (try? N1eLegacyClinicalAudit.inspect(data)) != nil,
              (try? N1fLosslessFieldGate.inspect(data)) != nil else {
            throw Failure.invalidSnapshot
        }
    }
    private func generation(_ r:Receipt)throws->Data {
        guard let encrypted=try read("gen-\(r.id).gcm") else{
            throw Failure.missingGeneration
        }
        guard encrypted.count>=28,encrypted.count<=35*1024*1024,
              let box=try? AES.GCM.SealedBox(combined:encrypted),
              let plaintext=try? AES.GCM.open(box,using:key,
                   authenticating:aad(r.id,r.revision)),sha(plaintext)==r.payloadSHA else {
            throw Failure.authenticationFailed
        }
        try validate(plaintext)
        return plaintext
    }
    private func removePending() throws {
        if fm.fileExists(atPath:file(pendingName).path) {
            try fm.removeItem(at:file(pendingName))
        }
    }
    /// No pending revision can supersede an active pointer after restart.
    @discardableResult
    func recover() throws -> Recovered? {
        let active=try checked(activeName)
        let pending=try checked(pendingName)
        if let active {
            let bytes=try generation(active)
            if let pending {
                if pending != active && pending.revision <= active.revision {
                    throw Failure.corruptJournal
                }
                try removePending()
            }
            return Recovered(revision:active.revision,snapshot:bytes)
        }
        if pending != nil {try removePending()}
        return nil
    }
    /// Copy-on-write: encrypted generation is verified before changing the
    /// single atomic active pointer. All previous generations remain intact.
    @discardableResult
    func commit(_ next:Data,expectedRevision:Int,
                fault:((Checkpoint)throws->Void)?=nil)throws->Int {
        try validate(next)
        let current=try recover()
        guard (current?.revision ?? 0) == expectedRevision,
              expectedRevision>=0,expectedRevision<100_000 else {
            throw Failure.staleRevision
        }
        let previousSHA=current.map{sha($0.snapshot)} ?? ""
        let id=UUID().uuidString
        let revision=expectedRevision+1
        let sealed=try AES.GCM.seal(next,using:key,
                     authenticating:aad(id,revision))
        guard let cipher=sealed.combined else{throw Failure.corruptJournal}
        try write("gen-\(id).gcm",cipher)
        try fault?(.encryptedGenerationWritten)
        var receipt=Receipt(version:1,id:id,revision:revision,
                           previousSHA:previousSHA,payloadSHA:sha(next),mac:"")
        receipt=Receipt(version:receipt.version,id:receipt.id,
                        revision:receipt.revision,previousSHA:receipt.previousSHA,
                        payloadSHA:receipt.payloadSHA,mac:sign(receipt))
        guard try generation(receipt)==next else{throw Failure.corruptJournal}
        try write(pendingName,try JSONEncoder().encode(receipt))
        try fault?(.pendingJournalWritten)
        try write(activeName,try JSONEncoder().encode(receipt))
        try fault?(.activePointerWritten)
        try removePending()
        return revision
    }
}
