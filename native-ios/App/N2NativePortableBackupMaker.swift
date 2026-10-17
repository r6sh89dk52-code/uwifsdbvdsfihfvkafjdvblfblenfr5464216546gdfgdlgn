import Foundation
import CryptoKit
import CommonCrypto
import Security
import DanperCore

/// Native reimplementation of build222 portable .danperbackup version 1.
/// No plaintext is stored or included in exported filenames or app resources.
enum N2NativePortableBackupMaker {
    enum Failure:Error {
        case invalidPassword, invalidClinicalSource, oversize, randomFailed
        case keyDerivationFailed, encryptionFailed
    }
    private static let maxPlain=30*1024*1024
    private static let maxText=42*1024*1024
    static func createVerified(snapshot:Data,password:String)throws->Data {
        guard password.count>=14,password.count<=200,
              !password.contains("\0") else{throw Failure.invalidPassword}
        guard snapshot.count<=maxPlain,
              (try? N1BackupAdmission.preview(data:snapshot)) != nil,
              let root=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any] else {
            throw Failure.invalidClinicalSource
        }
        let fmt=ISO8601DateFormatter()
        fmt.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let wrapped:[String:Any]=[
            "schema":1,"exportedAt":fmt.string(from:Date()),"snapshot":root
        ]
        let plain=try JSONSerialization.data(withJSONObject:wrapped)
        guard plain.count<=maxPlain else{throw Failure.oversize}
        var salt=[UInt8](repeating:0,count:16)
        var iv=[UInt8](repeating:0,count:12)
        let saltStatus=salt.withUnsafeMutableBytes{bytes in
            SecRandomCopyBytes(kSecRandomDefault,16,bytes.baseAddress!)
        }
        let ivStatus=iv.withUnsafeMutableBytes{bytes in
            SecRandomCopyBytes(kSecRandomDefault,12,bytes.baseAddress!)
        }
        guard saltStatus==errSecSuccess,ivStatus==errSecSuccess else{
            throw Failure.randomFailed
        }
        var key=[UInt8](repeating:0,count:32)
        defer{for i in key.indices{key[i]=0}}
        let status=password.withCString { pointer in
            salt.withUnsafeBytes { saltBytes in
                key.withUnsafeMutableBytes { target in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2),
                        pointer,password.utf8.count,
                        saltBytes.bindMemory(to:UInt8.self).baseAddress,salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),310_000,
                        target.bindMemory(to:UInt8.self).baseAddress,32)
                }
            }
        }
        guard status==kCCSuccess else{throw Failure.keyDerivationFailed}
        let encrypted=try AES.GCM.seal(plain,using:SymmetricKey(data:Data(key)),
                                nonce:AES.GCM.Nonce(data:Data(iv)))
        var payload=encrypted.ciphertext
        payload.append(encrypted.tag)
        // Verify before sharing so a corrupt output cannot be mistaken for a backup.
        let check=try AES.GCM.SealedBox(nonce:AES.GCM.Nonce(data:Data(iv)),
                                         ciphertext:payload.dropLast(16),
                                         tag:payload.suffix(16))
        guard try AES.GCM.open(check,using:SymmetricKey(data:Data(key)))==plain else{
            throw Failure.encryptionFailed
        }
        let envelope:[String:Any]=[
            "format":"DANPER-SALUD-PORTABLE-BACKUP",
            "version":1,"kdf":"PBKDF2-SHA256","iterations":310_000,
            "cipher":"AES-256-GCM",
            "salt":Data(salt).base64EncodedString(),
            "nonce":Data(iv).base64EncodedString(),
            "data":payload.base64EncodedString()
        ]
        let result=try JSONSerialization.data(withJSONObject:envelope)
        guard result.count<=maxText else{throw Failure.oversize}
        return result
    }
}
