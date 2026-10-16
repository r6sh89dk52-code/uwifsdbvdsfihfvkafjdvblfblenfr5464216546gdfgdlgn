import Foundation
import CryptoKit
import Security

/// N1: isolated encrypted proof of storage. Only a synthetic counter is accepted.
/// Never read/write legacy clinical app paths, bundle IDs, or Keychain entries.
actor NativeEncryptedLabVault {
    static let shared = NativeEncryptedLabVault()
    private let marker = "DANPER-N1-SYNTHETIC-ONLY"
    private let service = "pe.danper.saludmovil.native.preview.n1"
    private let keyAccount = "lab-aes256-v1"
    private let pointerAccount = "lab-active-generation-v1"

    private struct Record: Codable, Equatable {
        let marker: String
        let revision: Int
    }

    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private func getItem(_ account: String) throws -> Data? {
        var q = query(account)
        q[kSecReturnData as String] = kCFBooleanTrue
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: "DANPERN1.Keychain.Read", code: Int(status))
        }
        return data
    }

    private func setItem(_ account: String, value: Data) throws {
        let existing = try getItem(account)
        let status: OSStatus
        if existing == nil {
            var q = query(account)
            q[kSecValueData as String] = value
            q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(q as CFDictionary, nil)
        } else {
            status = SecItemUpdate(query(account) as CFDictionary,
                                   [kSecValueData as String: value] as CFDictionary)
        }
        guard status == errSecSuccess, try getItem(account) == value else {
            throw NSError(domain: "DANPERN1.Keychain.Write", code: Int(status))
        }
    }

    private func encryptionKey() throws -> SymmetricKey {
        if let existing = try getItem(keyAccount) {
            guard existing.count == 32 else { throw VaultError.invalidKey }
            return SymmetricKey(data: existing)
        }
        let newKey = SymmetricKey(size: .bits256)
        let data = newKey.withUnsafeBytes { Data($0) }
        try setItem(keyAccount, value: data)
        return newKey
    }

    private func directory() throws -> URL {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else {
            throw VaultError.storageUnavailable
        }
        let dir = root.appendingPathComponent("DANPER-N1-LAB", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var local = dir
        try local.setResourceValues(values)
        return dir
    }

    private func filename(_ uuid: UUID) -> String { "lab-\(uuid.uuidString.lowercased()).enc" }

    private func validatedFile(_ data: Data) throws -> String {
        guard let name = String(data: data, encoding: .utf8),
              name.hasPrefix("lab-"), name.hasSuffix(".enc"),
              let uuid = UUID(uuidString: String(name.dropFirst(4).dropLast(4))),
              filename(uuid) == name else { throw VaultError.invalidPointer }
        return name
    }

    private func readRecord(at filename: String) throws -> Record {
        let folder = try directory()
        let raw = try Data(contentsOf: folder.appendingPathComponent(filename))
        guard raw.count >= 28 && raw.count < 8192 else { throw VaultError.invalidRecord }
        let combined = try AES.GCM.SealedBox(combined: raw)
        let plain = try AES.GCM.open(combined, using: encryptionKey())
        guard plain.count < 1024 else { throw VaultError.invalidRecord }
        let record = try JSONDecoder().decode(Record.self, from: plain)
        guard record.marker == marker, record.revision >= 0 else { throw VaultError.invalidRecord }
        return record
    }

    private func currentRecord() throws -> Record? {
        guard let pointer = try getItem(pointerAccount) else { return nil }
        let filename = try validatedFile(pointer)
        return try readRecord(at: filename)
    }

    func readRevision() throws -> Int? { try currentRecord()?.revision }

    /// Copy-on-write: stage -> decrypt/verify -> activate Keychain pointer.
    /// Prior generation remains intact if staging fails. Never deletes an old generation.
    func saveNextSyntheticRevision() throws -> Int {
        let prior = try currentRecord()?.revision ?? 0
        guard prior < Int.max - 1 else { throw VaultError.invalidRecord }
        let next = Record(marker: marker, revision: prior + 1)
        let clear = try JSONEncoder().encode(next)
        let ciphertext = try AES.GCM.seal(clear, using: encryptionKey())
        guard let sealed = ciphertext.combined else { throw VaultError.invalidRecord }
        let name = filename(UUID())
        let destination = try directory().appendingPathComponent(name)
        try sealed.write(to: destination, options: [.atomic, .completeFileProtection])
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete],
                                               ofItemAtPath: destination.path)
        guard try readRecord(at: name) == next else { throw VaultError.verificationFailed }
        // Check for unexpected pointer changes before activation.
        guard (try currentRecord()?.revision ?? 0) == prior else { throw VaultError.concurrentChange }
        try setItem(pointerAccount, value: Data(name.utf8))
        guard try currentRecord() == next else { throw VaultError.verificationFailed }
        return next.revision
    }

    enum VaultError: LocalizedError {
        case invalidKey, invalidPointer, storageUnavailable, invalidRecord
        case verificationFailed, concurrentChange
        var errorDescription: String? {
            "El laboratorio cifrado no superó la verificación. No se han alterado datos clínicos."
        }
    }
}
