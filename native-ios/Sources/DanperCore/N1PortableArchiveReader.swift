import Foundation
import Crypto

/// N1b cross-platform proof of compatibility with src/portableBackup.ts.
/// This API exposes only counts + a test fingerprint; it never writes records.
public enum N1PortableArchiveError: Error, Equatable {
    case invalidPassword, invalidArchive, unsupportedEnvelope, authenticationFailed
    case invalidPayload, invalidClinicalStructure
}
public struct N1ArchiveInspection: Equatable, Sendable {
    public let manifest: N1BackupManifest
    public let plaintextSHA256: String
    public let plaintextByteCount: Int
}
private struct N1PortableEnvelope: Decodable {
    let format: String
    let version: Int
    let kdf: String
    let iterations: Int
    let cipher: String
    let salt: String
    let nonce: String
    let data: String
}
public enum N1PortableArchiveReader {
    private static let textMax = 42 * 1024 * 1024
    private static let clearMax = 30 * 1024 * 1024

    private static func strictBase64(_ string: String) -> Data? {
        guard !string.isEmpty, string.utf8.count <= textMax,
              let raw = Data(base64Encoded: string),
              raw.base64EncodedString() == string else { return nil }
        return raw
    }

    /// PBKDF2-HMAC-SHA256, one 32-byte block; fixed 310,000 rounds by format v1.
    /// Apple Swift Crypto delegates to CryptoKit on iOS and to BoringSSL on Linux.
    private static func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let key = SymmetricKey(data: Data(password.utf8))
        var block = salt
        block.append(contentsOf: [0, 0, 0, 1])
        var current = Array(HMAC<SHA256>.authenticationCode(for: block, using: key))
        var output = current
        for _ in 1..<310_000 {
            current = Array(HMAC<SHA256>.authenticationCode(
                for: Data(current), using: key
            ))
            for i in 0..<32 { output[i] ^= current[i] }
        }
        return SymmetricKey(data: Data(output))
    }

    /// Local-only validation. No patient details, original password or plaintext
    /// are returned; tests compare a digest of the complete decrypted envelope.
    public static func inspect(archive: Data, password: String) throws -> N1ArchiveInspection {
        // JS string.length counts UTF-16 code units, not Swift Unicode scalars.
        guard (14...200).contains(password.utf16.count) else {
            throw N1PortableArchiveError.invalidPassword
        }
        guard (100...textMax).contains(archive.count) else {
            throw N1PortableArchiveError.invalidArchive
        }
        guard let record = try? JSONDecoder().decode(N1PortableEnvelope.self, from: archive),
              record.format == "DANPER-SALUD-PORTABLE-BACKUP",
              record.version == 1,
              record.kdf == "PBKDF2-SHA256",
              record.iterations == 310_000,
              record.cipher == "AES-256-GCM",
              let salt = strictBase64(record.salt), salt.count == 16,
              let nonce = strictBase64(record.nonce), nonce.count == 12,
              let payload = strictBase64(record.data),
              payload.count >= 16, payload.count <= textMax else {
            throw N1PortableArchiveError.unsupportedEnvelope
        }

        let plaintext: Data
        do {
            let sealed = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: nonce),
                ciphertext: Data(payload.dropLast(16)),
                tag: Data(payload.suffix(16)))
            plaintext = try AES.GCM.open(sealed,
                        using: deriveKey(password: password, salt: salt))
        } catch {
            throw N1PortableArchiveError.authenticationFailed
        }

        guard plaintext.count <= clearMax,
              let root = try? JSONSerialization.jsonObject(with: plaintext) as? [String: Any],
              root["schema"] as? Int == 1,
              let snapshot = root["snapshot"] as? [String: Any],
              JSONSerialization.isValidJSONObject(snapshot),
              let serialized = try? JSONSerialization.data(withJSONObject: snapshot)
        else { throw N1PortableArchiveError.invalidPayload }

        let manifest: N1BackupManifest
        do {
            manifest = try N1BackupAdmission.preview(data: serialized)
        } catch {
            throw N1PortableArchiveError.invalidClinicalStructure
        }
        let sha = SHA256.hash(data: plaintext)
            .map { String(format: "%02x", $0) }.joined()
        return N1ArchiveInspection(manifest: manifest,
                                  plaintextSHA256: sha,
                                  plaintextByteCount: plaintext.count)
    }
}
