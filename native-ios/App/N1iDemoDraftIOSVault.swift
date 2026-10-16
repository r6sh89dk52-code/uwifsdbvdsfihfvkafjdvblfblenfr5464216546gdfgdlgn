import Foundation
import CryptoKit
import Security
import DanperCore

/// N1i: A DIFFERENT local Keychain service and Application Support directory
/// from build222 and from N1's counter-only lab.
/// Key material is never included in logs or committed source.
/// Only N1g's closed fictional demo catalog is accepted by the core codec.
actor N1iDemoDraftIOSVault {
    static let shared = N1iDemoDraftIOSVault()
    private let service = "pe.danper.saludmovil.native.preview.n1i.demo-only"
    private let account = "fictitious-drafts-aes256-key-v1"

    enum VaultIssue: LocalizedError {
        case missingKeyForExistingDemo, keychainUnavailable, invalidKey
        var errorDescription: String? {
            "No se pudo verificar el almacén cifrado de pruebas. No se modificó ninguna historia clínica real."
        }
    }

    private func query() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account,
         kSecAttrSynchronizable as String: kCFBooleanFalse as Any]
    }
    private func findKey() throws -> Data? {
        var q = query()
        q[kSecReturnData as String] = kCFBooleanTrue
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var output: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &output)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = output as? Data else {
            throw VaultIssue.keychainUnavailable
        }
        guard data.count == 32 else { throw VaultIssue.invalidKey }
        return data
    }
    private func location() throws -> URL {
        guard let appSupport = FileManager.default.urls(
            for:.applicationSupportDirectory,in:.userDomainMask).first else {
            throw VaultIssue.keychainUnavailable
        }
        let directory = appSupport.appendingPathComponent("DANPER-N1I-DEMO",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,
             attributes:[.protectionKey:FileProtectionType.complete])
        try FileManager.default.setAttributes([.protectionKey:FileProtectionType.complete],
             ofItemAtPath:directory.path)
        var url=directory
        var attrs=URLResourceValues()
        attrs.isExcludedFromBackup=true
        try url.setResourceValues(attrs)
        return url
    }
    private func key(at dir: URL) throws -> Data {
        if let existing = try findKey() { return existing }
        if FileManager.default.fileExists(
            atPath:dir.appendingPathComponent("active-demo-draft.json").path) {
            // Never mint a replacement key for existing ciphertext.
            throw VaultIssue.missingKeyForExistingDemo
        }
        let random = SymmetricKey(size:.bits256).withUnsafeBytes { Data($0) }
        var q = query()
        q[kSecValueData as String] = random
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(q as CFDictionary,nil)
        if status == errSecDuplicateItem, let concurrentKey = try findKey() {
            return concurrentKey
        }
        guard status == errSecSuccess, try findKey() == random else {
            throw VaultIssue.keychainUnavailable
        }
        return random
    }
    func load() throws -> N1gClinic? {
        let folder=try location()
        let keyData=try key(at:folder)
        return try N1iEncryptedDemoDraftVault(root:folder,keyData:keyData).load()
    }
    func save(_ clinic: N1gClinic) throws {
        // Validate before Keychain or file system access.
        _ = try clinic.exportFictionalDrafts()
        let folder=try location()
        let keyData=try key(at:folder)
        try N1iEncryptedDemoDraftVault(root:folder,keyData:keyData).save(clinic)
    }
}
