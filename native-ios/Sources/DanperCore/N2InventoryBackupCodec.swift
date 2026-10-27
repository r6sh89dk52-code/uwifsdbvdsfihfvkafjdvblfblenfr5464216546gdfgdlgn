import Foundation
import CoreFoundation
import Crypto
#if canImport(CommonCrypto)
import CommonCrypto
#endif

/// Proof can only be obtained by authenticating/decrypting an actual archive.
/// No password/key is retained and no clinical content is returned to UI summaries.
public enum N2InventoryBackupDomain:String,Codable,Sendable {case clinical,demo,unspecified}
public struct N2VerifiedInventoryBackup:Sendable {
    public let domain:N2InventoryBackupDomain
    public let archiveSHA256:String
    public let sourceSHA256:String
    public let schemaVersion:Int
    public let report:N1eClinicalParityReport
    let snapshot:Data
}
public enum N2InventoryBackupCodec {
    public enum Failure:Error,Equatable {case password,envelope,authentication,payload,oversize}
    private struct Envelope:Codable {
        let format:String
        let version:Int
        let kdf:String
        let iterations:Int
        let cipher:String
        let salt:String
        let nonce:String
        let data:String
    }
    private static func key(password:String,salt:Data)throws->SymmetricKey {
        guard (14...200).contains(password.utf16.count),!password.contains("\0") else{throw Failure.password}
        #if canImport(CommonCrypto)
        var derived=[UInt8](repeating:0,count:32)
        defer{for i in derived.indices{derived[i]=0}}
        let status=password.withCString {p in salt.withUnsafeBytes {s in derived.withUnsafeMutableBytes {d in
            CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),p,password.utf8.count,
                s.bindMemory(to:UInt8.self).baseAddress,salt.count,
                CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),310_000,
                d.bindMemory(to:UInt8.self).baseAddress,32)
        }}}
        guard status==kCCSuccess else{throw Failure.authentication}
        return SymmetricKey(data:Data(derived))
        #else
        let secret=SymmetricKey(data:Data(password.utf8))
        var block=salt;block.append(contentsOf:[0,0,0,1])
        var current=Array(HMAC<SHA256>.authenticationCode(for:block,using:secret)),output=[UInt8]()
        output=current
        defer{for i in output.indices{output[i]=0;current[i]=0}}
        for _ in 1..<310_000 {
            current=Array(HMAC<SHA256>.authenticationCode(for:Data(current),using:secret))
            for i in 0..<32{output[i] ^= current[i]}
        }
        return SymmetricKey(data:Data(output))
        #endif
    }
    private static func base64(_ s:String)->Data? {
        guard s.utf8.count<=42*1024*1024,let d=Data(base64Encoded:s),d.base64EncodedString()==s else{return nil}
        return d
    }
    public static func verify(archive:Data,password:String)throws->N2VerifiedInventoryBackup {
        guard (100...42*1024*1024).contains(archive.count),
              let e=try? JSONDecoder().decode(Envelope.self,from:archive),
              e.format=="DANPER-SALUD-PORTABLE-BACKUP",[1,2].contains(e.version),
              e.kdf=="PBKDF2-SHA256",e.iterations==310_000,e.cipher=="AES-256-GCM",
              let salt=base64(e.salt),salt.count==16,let nonce=base64(e.nonce),nonce.count==12,
              let sealed=base64(e.data),sealed.count>=16 else{throw Failure.envelope}
        let derived=try key(password:password,salt:salt)
        var plain:Data
        do {
            let box=try AES.GCM.SealedBox(nonce:AES.GCM.Nonce(data:nonce),
                ciphertext:sealed.dropLast(16),tag:sealed.suffix(16))
            plain=try AES.GCM.open(box,using:derived)
        }catch{throw Failure.authentication}
        defer{plain.resetBytes(in:0..<plain.count)}
        guard plain.count<=30*1024*1024,let root=try? N2SimpleInventory.object(plain),
              let schema=root["schema"] as? NSNumber,CFGetTypeID(schema) != CFBooleanGetTypeID(),
              schema.intValue==e.version,schema.doubleValue==Double(e.version),
              let snapshot=root["snapshot"] as? [String:Any] else{throw Failure.payload}
        let raw=try N2SimpleInventory.bytes(snapshot)
        guard (e.version==2)==N2SimpleInventory.isActive(raw) else{throw Failure.payload}
        let report:N1eClinicalParityReport
        do {
            report=try N2VersionedSnapshotAudit.inspect(raw,allowEmptySynthetic:true)
            _=try N1fLosslessFieldGate.inspect(raw)
        }catch{throw Failure.payload}
        let domain:N2InventoryBackupDomain
        if let raw=root["sourceDomain"] {
            guard let name=raw as? String,let value=N2InventoryBackupDomain(rawValue:name) else {throw Failure.payload}
            domain=value
        } else {
            guard e.version==1 else {throw Failure.payload}
            domain = .unspecified
        }
        return N2VerifiedInventoryBackup(domain:domain,archiveSHA256:N2SimpleInventory.digest(archive),
            sourceSHA256:try N2SimpleInventory.fingerprint(raw),schemaVersion:e.version,report:report,snapshot:raw)
    }
    public static func createVerified(snapshot:Data,password:String,domain:N2InventoryBackupDomain = .unspecified)throws->Data {
        _=try N2VersionedSnapshotAudit.inspect(snapshot,allowEmptySynthetic:true)
        _=try N1fLosslessFieldGate.inspect(snapshot)
        let version=N2SimpleInventory.isActive(snapshot) ? 2:1
        let plain=try N2SimpleInventory.bytes(["schema":version,"sourceDomain":domain.rawValue,
            "exportedAt":ISO8601DateFormatter().string(from:Date()),"snapshot":try N2SimpleInventory.object(snapshot)])
        guard plain.count<=30*1024*1024 else{throw Failure.oversize}
        let salt=SymmetricKey(size:.bits128).withUnsafeBytes{Data($0)}
        let nonce=AES.GCM.Nonce(),derived=try key(password:password,salt:salt)
        let sealed=try AES.GCM.seal(plain,using:derived,nonce:nonce)
        let e=Envelope(format:"DANPER-SALUD-PORTABLE-BACKUP",version:version,
            kdf:"PBKDF2-SHA256",iterations:310_000,cipher:"AES-256-GCM",
            salt:salt.base64EncodedString(),nonce:nonce.withUnsafeBytes{Data($0)}.base64EncodedString(),
            data:(sealed.ciphertext+sealed.tag).base64EncodedString())
        let archive=try JSONEncoder().encode(e)
        guard archive.count<=42*1024*1024 else{throw Failure.oversize}
        let proof=try verify(archive:archive,password:password)
        guard proof.sourceSHA256 == (try N2SimpleInventory.fingerprint(snapshot)) else{throw Failure.authentication}
        return archive
    }
}
