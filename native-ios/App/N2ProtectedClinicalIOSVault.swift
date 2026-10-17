import Foundation
import CryptoKit
import Security
import DanperCore

/// Separate native clinical domain. Does not access build222, N1i or N1m
/// Keychain. No view starts migration or activation automatically.
actor N2ProtectedClinicalIOSVault {
    static let shared=N2ProtectedClinicalIOSVault()
    private let service="pe.danper.saludmovil.native.preview.n2.clinical"
    private let account="n2-one-source-clinical-aes256-v1"
    enum Failure:LocalizedError {
        case missingKey, unavailableKeychain, keyInvalid, blockedMigration
        var errorDescription:String? {
            "No fue posible verificar la bóveda nativa. No se han modificado los datos de la build 222."
        }
    }
    private func query()->[String:Any] {
        [kSecClass as String:kSecClassGenericPassword,
         kSecAttrService as String:service,
         kSecAttrAccount as String:account,
         kSecAttrSynchronizable as String:kCFBooleanFalse as Any]
    }
    private func hasClinicalFiles()->Bool {
        guard let base=FileManager.default.urls(
            for:.applicationSupportDirectory,in:.userDomainMask).first else {
            return true // Fail closed.
        }
        let dir=base.appendingPathComponent("DANPER-N2-CLINICAL-VAULT")
        guard FileManager.default.fileExists(atPath:dir.path) else{return false}
        guard let items=try? FileManager.default.contentsOfDirectory(
            atPath:dir.path) else{return true}
        return !items.isEmpty
    }
    private func readKey()throws->Data? {
        var q=query()
        q[kSecReturnData as String]=kCFBooleanTrue
        q[kSecMatchLimit as String]=kSecMatchLimitOne
        var output:CFTypeRef?
        let result=SecItemCopyMatching(q as CFDictionary,&output)
        if result==errSecItemNotFound{return nil}
        guard result==errSecSuccess,let secret=output as? Data else {
            throw Failure.unavailableKeychain
        }
        guard secret.count==32 else{throw Failure.keyInvalid}
        return secret
    }
    private func deviceKey(create:Bool)throws->Data? {
        if let existing=try readKey(){return existing}
        guard !hasClinicalFiles() else{throw Failure.missingKey}
        guard create else{return nil}
        let secret=SymmetricKey(size:.bits256).withUnsafeBytes{Data($0)}
        var q=query()
        q[kSecValueData as String]=secret
        q[kSecAttrAccessible as String]=kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let result=SecItemAdd(q as CFDictionary,nil)
        if result==errSecDuplicateItem{return try readKey()}
        guard result==errSecSuccess,try readKey()==secret else {
            throw Failure.unavailableKeychain
        }
        return secret
    }
    /// Counts only. Requires no key creation, no decryption unless encrypted
    /// vault is already present, and no access to the old application.
    func inspect()throws->N2ProtectedStoreSummary? {
        guard let secret=try deviceKey(create:false) else{return nil}
        return try N2ProtectedClinicalVaultCore(keyData:secret).inspect()
    }
    /// This is intentionally uncalled by the present evaluation screens.
    /// A future explicit restore review will pass ONE locally decrypted,
    /// independently validated source, with an on-screen confirmation.
    func activateOnlyWithConsent(_ source:Data,approvedByUser:Bool)
        throws->N2ProtectedStoreSummary {
        guard approvedByUser else{throw Failure.blockedMigration}
        guard let secret=try deviceKey(create:true) else{
            throw Failure.unavailableKeychain
        }
        return try N2ProtectedClinicalVaultCore(keyData:secret)
            .activateSingleVerifiedSource(source,explicitConsent:approvedByUser)
    }
    func readHistory()throws->N2NativeReadModel? {
        guard let secret=try deviceKey(create:false) else{return nil}
        return try N2ProtectedClinicalVaultCore(keyData:secret).readIndex()
    }
    /// May only be invoked from a Face ID/code authenticated screen after
    /// the user chooses a new passphrase; never persists plaintext to Files.
    func exportPortableEncryptedBackup(password:String)throws->Data {
        guard let secret=try deviceKey(create:false) else{
            throw Failure.missingKey
        }
        let source=try N2ProtectedClinicalVaultCore(keyData:secret)
            .sourceForEncryptedBackup()
        return try N2NativePortableBackupMaker.createVerified(
            snapshot:source,password:password)
    }
}
