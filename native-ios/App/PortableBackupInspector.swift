import Foundation
import CryptoKit
import CommonCrypto
import DanperCore

enum BackupInspectionError: LocalizedError {
    case invalidPasswordLength
    case invalidFile
    case invalidEnvelope
    case authenticationFailed
    case invalidSnapshot

    var errorDescription: String? {
        switch self {
        case .invalidPasswordLength: "La contraseña debe tener entre 14 y 200 caracteres."
        case .invalidFile: "Selecciona un archivo .danperbackup válido, de hasta 42 MB."
        case .invalidEnvelope: "Respaldo incompatible con el formato de DANPER build 222."
        case .authenticationFailed: "Contraseña incorrecta o respaldo alterado. No se modificaron datos."
        case .invalidSnapshot: "La información descifrada no supera la validación de estructura."
        }
    }
}

private struct Envelope: Decodable {
    let format: String
    let version: Int
    let kdf: String
    let iterations: Int
    let cipher: String
    let salt: String
    let nonce: String
    let data: String
}

/// Read-only cross-platform backup verifier. No writes to Keychain or Files.
enum PortableBackupInspector {
    static func inspect(url: URL, password: String) throws -> N1BackupManifest {
        try audit(url:url,password:password).manifest
    }

    /// Decrypts and audits exactly ONE user-selected backup in memory.
    /// Does not import, append, replace, sync or persist any clinical records.
    static func audit(url: URL, password: String) throws -> N1lSourceAudit {
        try auditedSnapshot(url:url,password:password).1
    }

    /// Password and clear records are local to the selected iPhone backup.
    /// No SwiftUI state or logs contain decrypted clinical records.
    static func prepareInactive(url:URL,password:String,acknowledgment:N1nAcknowledgment)
        async throws -> N1mRealClinicalStagingVault.Prepared {
        var raw=try auditedSnapshot(url:url,password:password).0
        defer { raw.resetBytes(in:0..<raw.count) }
        _=try N1nInactiveSourceGate.authorize(raw,acknowledgment:acknowledgment)
        return try await N1mRealClinicalStagingIOSVault.shared.prepareSingleSource(raw)
    }

    private static func auditedSnapshot(url:URL,password:String)
        throws -> (Data,N1lSourceAudit) {
        guard password.count >= 14 && password.count <= 200 else {
            throw BackupInspectionError.invalidPasswordLength
        }
        guard url.pathExtension.lowercased() == "danperbackup" else {
            throw BackupInspectionError.invalidFile
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber,
              size.intValue >= 100 && size.intValue <= 42 * 1024 * 1024 else {
            throw BackupInspectionError.invalidFile
        }
        let source = try Data(contentsOf: url)
        let record = try JSONDecoder().decode(Envelope.self, from: source)
        guard record.format == "DANPER-SALUD-PORTABLE-BACKUP",
              record.version == 1, record.kdf == "PBKDF2-SHA256",
              record.iterations == 310_000, record.cipher == "AES-256-GCM",
              let salt = Data(base64Encoded: record.salt), salt.count == 16,
              let iv = Data(base64Encoded: record.nonce), iv.count == 12,
              let payload = Data(base64Encoded: record.data), payload.count >= 16
        else { throw BackupInspectionError.invalidEnvelope }

        var key = [UInt8](repeating: 0, count: 32)
        let result = password.withCString { passwordPointer in
            salt.withUnsafeBytes { saltBytes in
                key.withUnsafeMutableBytes { derivedBytes in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordPointer,
                        password.utf8.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256), 310_000,
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress, 32)
                }
            }
        }
        guard result == kCCSuccess else { throw BackupInspectionError.invalidEnvelope }
        defer {
            for i in key.indices { key[i] = 0 }
        }

        let content: Data
        do {
            let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: iv),
                ciphertext: payload.dropLast(16), tag: payload.suffix(16))
            content = try AES.GCM.open(box, using: SymmetricKey(data: Data(key)))
        } catch { throw BackupInspectionError.authenticationFailed }
        guard content.count <= 30 * 1024 * 1024,
              let root = try JSONSerialization.jsonObject(with: content) as? [String: Any],
              (root["schema"] as? Int) == 1,
              let snapshot = root["snapshot"] as? [String:Any]
        else { throw BackupInspectionError.invalidSnapshot }
        do {
            let raw=try JSONSerialization.data(withJSONObject:snapshot,options:[.sortedKeys])
            let result=try N1lRealSnapshotGate.audit(raw,destination:.uncertain)
            return (raw,result)
        } catch {
            throw BackupInspectionError.invalidSnapshot
        }
    }
}
