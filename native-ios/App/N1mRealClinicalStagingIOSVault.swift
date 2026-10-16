import Foundation
import CryptoKit
import Security
import DanperCore

/// iPhone-only adaptor RESERVED for future explicit single-source authorization.
/// NO view calls prepareSingleSource in N1m. No real data is loaded at startup.
/// The original build222 bundle ID, its Keychain services and N1g demo vault
/// are not accessed. This stage cannot activate a clinical database.
actor N1mRealClinicalStagingIOSVault {
    static let shared = N1mRealClinicalStagingIOSVault()
    private let service = "pe.danper.saludmovil.native.preview.n1m.real-staging"
    private let account = "single-build222-source-aes256-v1"

    private enum Issue: Error {
        case unableToLocateStorage, keyMissingForExistingCiphertext
        case keychainUnavailable, invalidKey
    }
    private func query() -> [String:Any] {
        [kSecClass as String:kSecClassGenericPassword,
         kSecAttrService as String:service,
         kSecAttrAccount as String:account,
         kSecAttrSynchronizable as String:kCFBooleanFalse as Any]
    }
    private func directory() throws -> URL {
        guard let support=FileManager.default.urls(
            for:.applicationSupportDirectory,in:.userDomainMask).first else {
            throw Issue.unableToLocateStorage
        }
        var directory=support.appendingPathComponent("DANPER-N1M-REAL-STAGING",
                                                      isDirectory:true)
        try FileManager.default.createDirectory(
            at:directory,withIntermediateDirectories:true,
            attributes:[.protectionKey:FileProtectionType.complete])
        try FileManager.default.setAttributes(
            [.protectionKey:FileProtectionType.complete],ofItemAtPath:directory.path)
        var metadata=URLResourceValues()
        metadata.isExcludedFromBackup=true
        try directory.setResourceValues(metadata)
        return directory
    }
    private func existingKey() throws -> Data? {
        var input=query()
        input[kSecReturnData as String]=kCFBooleanTrue
        input[kSecMatchLimit as String]=kSecMatchLimitOne
        var raw:CFTypeRef?
        let status=SecItemCopyMatching(input as CFDictionary,&raw)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess,let secret=raw as? Data else {
            throw Issue.keychainUnavailable
        }
        guard secret.count == 32 else { throw Issue.invalidKey }
        return secret
    }
    private func stagePresent(in location:URL) -> Bool {
        let parent=FileManager.default
        return parent.fileExists(
            atPath:location.appendingPathComponent("complete-source.gcm").path) ||
            parent.fileExists(
            atPath:location.appendingPathComponent("prepared-receipt.json").path)
    }
    private func currentKey(at location:URL, allowCreation:Bool) throws -> Data? {
        if let key=try existingKey() { return key }
        if stagePresent(in:location) { throw Issue.keyMissingForExistingCiphertext }
        guard allowCreation else { return nil }
        let data=SymmetricKey(size:.bits256).withUnsafeBytes { Data($0) }
        var attrs=query()
        attrs[kSecValueData as String]=data
        attrs[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let result=SecItemAdd(attrs as CFDictionary,nil)
        if result == errSecDuplicateItem { return try existingKey() }
        guard result == errSecSuccess,try existingKey() == data else {
            throw Issue.keychainUnavailable
        }
        return data
    }
    /// Counts only. Does not request a new Keychain key on inspection.
    func preparedSummary() throws -> N1mRealClinicalStagingVault.Prepared? {
        let location=try directory()
        guard let key=try currentKey(at:location,allowCreation:false) else {
            return nil
        }
        return try N1mRealClinicalStagingVault(
            directory:location,keyData:key).inspectPrepared()
    }
    /// Not invoked by SwiftUI in N1m. Once provenance and patient-data
    /// safeguards are approved, the future UI may pass ONE local decrypted
    /// snapshot to this staging-only method. Never commits a clinical vault.
    func prepareSingleSource(_ plaintextSnapshot:Data) throws ->
        N1mRealClinicalStagingVault.Prepared {
        let location=try directory()
        // Gate the source BEFORE creating a new sensitive Keychain secret.
        let audit=try N1lRealSnapshotGate.audit(
            plaintextSnapshot,destination:.verifiedEmpty)
        guard audit.isStructurallyEligibleForReview else {
            throw N1mRealClinicalStagingVault.Failure.unverifiedSnapshot
        }
        guard let key=try currentKey(at:location,allowCreation:true) else {
            throw Issue.keychainUnavailable
        }
        return try N1mRealClinicalStagingVault(
            directory:location,keyData:key).prepare(plaintextSnapshot)
    }
}
