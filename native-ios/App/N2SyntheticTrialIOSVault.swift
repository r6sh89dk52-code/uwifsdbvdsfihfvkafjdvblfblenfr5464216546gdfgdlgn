import Foundation
import CryptoKit
import Security
import DanperCore

/// Separate native clinical domain. Does not access build222, N1i or N1m
/// Keychain. No view starts migration or activation automatically.
actor N2SyntheticTrialIOSVault {
    static let shared=N2SyntheticTrialIOSVault()
    private let service="pe.danper.saludmovil.native.preview.n2.synthetic"
    private let account="n2-synthetic-trial-key-v1"
    enum Failure:LocalizedError {
        case missingKey, unavailableKeychain, keyInvalid, blockedMigration, resetIncomplete
        case keychainStatus(Int32)
        var errorDescription:String? {
            if case let .keychainStatus(code)=self {
                return "Keychain no disponible (OSStatus \(code)). No se han modificado datos."
            }
            if case .resetIncomplete=self {
                return "La clave de pruebas fue invalidada, pero quedaron archivos cifrados. Pulsa borrar nuevamente para terminar la limpieza. La bóveda clínica y build 222 no se modificaron."
            }
            return "No fue posible verificar la bóveda nativa. No se han modificado los datos de la build 222."
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
        let dir=base.appendingPathComponent("DANPER-N2-SYNTHETIC-VAULT")
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
        guard result==errSecSuccess else {
            throw Failure.keychainStatus(result)
        }
        guard let secret=output as? Data else{
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
        guard result==errSecSuccess else{
            throw Failure.keychainStatus(result)
        }
        guard try readKey()==secret else{
            throw Failure.unavailableKeychain
        }
        return secret
    }
    /// Explicit, irreversible cryptographic erasure of the N2 DEMO domain.
    /// Deletes the demo-only Keychain key FIRST, then its allowlisted encrypted
    /// journal directory. If file removal fails, retrying is safe because the
    /// lost key cannot be recreated while encrypted files remain.
    /// NEVER reads, deletes, or resets the independent clinical namespace.
    func eraseEntireDemo(confirmation:String)throws {
        guard confirmation==N2SyntheticResetScope.confirmation else {
            throw Failure.blockedMigration
        }
        let fm=FileManager.default
        guard let support=fm.urls(for:.applicationSupportDirectory,
                                 in:.userDomainMask).first?.standardizedFileURL else {
            throw Failure.blockedMigration
        }
        let target=support.appendingPathComponent(
            N2SyntheticResetScope.directoryName,isDirectory:true)
        guard N2SyntheticResetScope.canErase(support:support,target:target) else {
            throw Failure.blockedMigration
        }
        if fm.fileExists(atPath:target.path) {
            let info=try target.resourceValues(
                forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
            guard info.isDirectory==true,info.isSymbolicLink != true else {
                throw Failure.blockedMigration
            }
        }
        let result=SecItemDelete(query() as CFDictionary)
        guard result==errSecSuccess || result==errSecItemNotFound else {
            throw Failure.keychainStatus(result)
        }
        // The encryption key is now gone. A crash here leaves only unreadable
        // ciphertext; calling this method again completes the cleanup.
        do {
            if fm.fileExists(atPath:target.path) {
                try fm.removeItem(at:target)
            }
        } catch {
            throw Failure.resetIncomplete
        }
        // Remove ONLY temporary exports with the new explicit DEMO prefix.
        // Old unscoped filenames cannot safely be classified as clinical vs
        // demo, so they are not deleted; exported files in Files are external.
        do {
            let temp=fm.temporaryDirectory.standardizedFileURL
            let items=try fm.contentsOfDirectory(
                at:temp,includingPropertiesForKeys:[.isDirectoryKey,.isSymbolicLinkKey])
            for folder in items where
                    N2SyntheticResetScope.canEraseDemoTempFolder(
                        named:folder.lastPathComponent) {
                guard folder.standardizedFileURL.deletingLastPathComponent()==temp else {
                    throw Failure.resetIncomplete
                }
                let info=try folder.resourceValues(
                    forKeys:[.isDirectoryKey,.isSymbolicLinkKey])
                guard info.isDirectory==true,info.isSymbolicLink != true else {
                    throw Failure.resetIncomplete
                }
                try fm.removeItem(at:folder)
            }
        } catch {
            throw Failure.resetIncomplete
        }
        guard !fm.fileExists(atPath:target.path),
              try readKey()==nil else {
            throw Failure.resetIncomplete
        }
    }

    /// Counts only. Requires no key creation, no decryption unless encrypted
    /// vault is already present, and no access to the old application.
    func inspect()throws->N2ProtectedStoreSummary? {
        guard let secret=try deviceKey(create:false) else{return nil}
        return try N2ProtectedClinicalVaultCore(keyData:secret,namespace:.synthetic).inspect()
    }
    /// Fresh encrypted demonstration with no prepopulated workers or visits.
    /// Does not copy the fixed five-worker sample or import any clinical data.
    func startEmptyDemo()throws->N2ProtectedStoreSummary {
        guard try inspect()==nil else {throw Failure.blockedMigration}
        guard let secret=try deviceKey(create:true) else {
            throw Failure.unavailableKeychain
        }
        return try N2ProtectedClinicalVaultCore(keyData:secret,namespace:.synthetic)
            .activateEmptySynthetic(confirmed:true)
    }

    /// Opt-in sample fixture. Never implied by "start empty".
    /// A pre-existing demonstration is never silently reused on activation.
    func startSyntheticDemo()throws->N2ProtectedStoreSummary {
        guard try inspect()==nil else {throw Failure.blockedMigration}
        let fixture=try resource("n2-synthetic-clinical")
        guard let secret=try deviceKey(create:true) else{
            throw Failure.unavailableKeychain
        }
        return try N2ProtectedClinicalVaultCore(keyData:secret,namespace:.synthetic)
            .activateSyntheticFixture(fixture,confirmed:true)
    }
    func readDrafts()throws->[N2RecoverableDraft] {
        try protectedStore().readDrafts()
    }
    func dispensingLines(visitID:String)throws->[N2DispensingLine] {
        try protectedStore().dispensingLines(visitID:visitID)
    }
    func dispensingStatus(visitID:String)throws->[String:String] {
        try protectedStore().dispensingStatus(visitID:visitID)
    }
    func dashboardCounters(today:String,weekStart:String)throws
        ->(today:Int,week:Int,drafts:Int)? {
        try protectedStore().dashboardCounters(today:today,weekStart:weekStart)
    }
    func readDashboard()throws
        ->(history:N2NativeReadModel?,drafts:[N2RecoverableDraft]) {
        try protectedStore().readDashboard()
    }
    func readHistory()throws->N2NativeReadModel? {
        guard let secret=try deviceKey(create:false) else{return nil}
        return try N2ProtectedClinicalVaultCore(keyData:secret,namespace:.synthetic).readIndex()
    }
    private func protectedStore()throws->N2ProtectedClinicalVaultCore {
        guard let secret=try deviceKey(create:false) else{
            throw Failure.missingKey
        }
        return try N2ProtectedClinicalVaultCore(keyData:secret,namespace:.synthetic)
    }
    private func resource(_ name:String)throws->Data {
        guard let source=Bundle.main.url(forResource:name,withExtension:"json",
                   subdirectory:"N1sDemoResources") else{
            throw Failure.blockedMigration
        }
        return try Data(contentsOf:source)
    }
    func registerWorker(_ worker:Data,at:Int64,expectedRevision:Int)
        throws->N2ProtectedStoreSummary {
        guard let obj=try? JSONSerialization.jsonObject(with:worker) as? [String:Any],
              let dni=obj["dni"] as? String,
              let name=obj["name"] as? String,
              dni.utf8.count==8,
              dni.utf8.allSatisfy({(48...57).contains($0)}),
              name.trimmingCharacters(in:.whitespacesAndNewlines).count>=5 else {
            throw Failure.blockedMigration
        }
        return try protectedStore().registerWorker(worker,at:at,expectedRevision:expectedRevision)
    }
    func correctWorker(dni:String,worker:Data,at:Int64,
                       expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().correctWorker(dni:dni,worker:worker,
                                           at:at,expectedRevision:expectedRevision)
    }
    func reviewAllergies(dni:String,status:String,substances:String,
                        at:Int64,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().reviewAllergies(dni:dni,status:status,
                      substances:substances,at:at,expectedRevision:expectedRevision)
    }
    func saveDraft(id:String,changes:Data,at:Int64,expectedRevision:Int)
        throws->N2ProtectedStoreSummary {
        try protectedStore().saveDraft(id:id,changes:changes,at:at,
                                      expectedRevision:expectedRevision)
    }
    func deleteDraft(id:String,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().removeDraft(id:id,expectedRevision:expectedRevision)
    }
    /// The sandbox uses its own encrypted synthetic namespace. The
    /// accounting reader is read-only and never touches the clinical vault.
    func automaticCutAccounting(through date:String)throws
        ->N2AutomaticCutAccounting.Result {
        return try protectedStore().automaticCutAccounting(
            mappings:resource("n2-approved-mappings"),through:date)
    }
    func confirmPendingDispensing(_ evidence:N2PendingDispensingEvidence,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().confirmPendingDispensing(evidence,approvedCatalog:resource("n2-approved-mappings"),expectedRevision:expectedRevision)
    }
    func closeContainers(lotID:String,count:Int,disposition:String,operatorName:String,reason:String,at:Int64,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().closeContainers(lotID:lotID,count:count,disposition:disposition,operatorName:operatorName,reason:reason,at:at,expectedRevision:expectedRevision)
    }
    func auxiliaryAccounting()throws->String {try protectedStore().auxiliaryAccounting()}
    func registerAuxiliaryLot(clinicalCode:String,lot:Data,operatorName:String,evidence:String,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        let context=try clinicalFormContext()
        return try protectedStore().registerAuxiliaryLot(clinicalCode:clinicalCode,lot:lot,catalog:context.products,
            operatorName:operatorName,evidence:evidence,at:Int64(Date().timeIntervalSince1970*1000),expectedRevision:expectedRevision)
    }
    func retryDispensing(visitID:String,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().retryDispensing(visitID:visitID,approvedCatalog:resource("n2-approved-mappings"),
            at:Int64(Date().timeIntervalSince1970*1000),expectedRevision:expectedRevision)
    }
    func confirmOperationalMapping(_ rule:N2OperationalMapping,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        let context=try clinicalFormContext()
        return try protectedStore().confirmOperationalMapping(rule,catalog:context.products,
            explicitConsent:true,expectedRevision:expectedRevision)
    }
    /// Load both form inputs from one verified snapshot/revision.
    func prepareClinicalForm()throws
        ->(context:N2FormContext,drafts:[N2RecoverableDraft]) {
        let products=try resource("n2-ambulatory-products")
        let nursing=try resource("n2-nursing-catalog")
        let mappings=try resource("n2-approved-mappings")
        return try protectedStore().prepareClinicalForm(
            products:products,nursing:nursing,mappings:mappings)
    }
    func clinicalFormContext()throws->N2FormContext {
        let products=try resource("n2-ambulatory-products")
        let nursing=try resource("n2-nursing-catalog")
        let mappings=try resource("n2-approved-mappings")
        return try protectedStore().clinicalFormContext(
            products:products,nursing:nursing,mappings:mappings)
    }
    func readPendingClinicalCorrection(visitID:String)throws
        ->N2PendingClinicalCorrection? {
        try protectedStore().readPendingClinicalCorrection(visitID:visitID)
    }
    func savePendingClinicalCorrection(visitID:String,changes:Data,
        reason:String,operatorName:String,medicationDiscrepancy:String,
        expectedEffectiveSHA:String,at:Int64,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().savePendingClinicalCorrection(
            visitID:visitID,changes:changes,reason:reason,
            operatorName:operatorName,medicationDiscrepancy:medicationDiscrepancy,
            expectedEffectiveSHA:expectedEffectiveSHA,at:at,
            expectedRevision:expectedRevision)
    }
    func deletePendingClinicalCorrection(visitID:String,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().deletePendingClinicalCorrection(
            visitID:visitID,expectedRevision:expectedRevision)
    }
    func readCorrectionHistory(visitID:String)throws
        ->[N2CorrectionHistoryEntry] {
        try protectedStore().readCorrectionHistory(visitID:visitID)
    }
    func readCorrectionDetail(visitID:String)throws->N2CorrectionDetail {
        try protectedStore().readCorrectionDetail(visitID:visitID)
    }
    func saveClinicalCorrection(visitID:String,eventID:String,changes:Data,
        reason:String,operatorName:String,medicationDiscrepancy:String,
        expectedEffectiveSHA:String,at:Int64,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().saveClinicalCorrection(
            visitID:visitID,eventID:eventID,changes:changes,
            reason:reason,operatorName:operatorName,
            medicationDiscrepancy:medicationDiscrepancy,
            expectedEffectiveSHA:expectedEffectiveSHA,
            at:at,expectedRevision:expectedRevision)
    }
    func saveAttention(_ attention:Data,at:Int64,expectedRevision:Int)
        throws->N2ProtectedStoreSummary {
        try protectedStore().saveAttention(attention,
            approvedCatalog:resource("n2-approved-mappings"),
            at:at,expectedRevision:expectedRevision)
    }
    func previewAttention(_ attention:Data,visitID:String,at:Int64,expectedRevision:Int)throws->[String:String] {
        let result=try protectedStore().previewAttention(attention,
            approvedCatalog:resource("n2-approved-mappings"),at:at,expectedRevision:expectedRevision)
        let root=try JSONSerialization.jsonObject(with:result.snapshot) as? [String:Any]
        let visits=root?["attentions"] as? [[String:Any]]
        return visits?.first{$0["id"] as? String==visitID}?["nativeDispensing"] as? [String:String] ?? [:]
    }
    func verifyOriginalStockSite(eventID:String,lotID:String,site:String,reason:String,
        at:Int64,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().verifyOriginalStockSite(eventID:eventID,lotID:lotID,site:site,
            reason:reason,operatorName:"Felipe Azcárate Silva",at:at,expectedRevision:expectedRevision)
    }
    func addLot(_ lot:Data,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().registerStockLot(lot,
            nursingCatalog:resource("n2-nursing-catalog"),expectedRevision:expectedRevision)
    }
    func correctUnusedLot(lotID:String,reference:String,expires:String,
        reason:String,operatorName:String,at:Int64,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().correctUnusedLot(lotID:lotID,reference:reference,
            expires:expires,reason:reason,operatorName:operatorName,
            at:at,expectedRevision:expectedRevision)
    }
    func receiveStock(movementID:String,lotID:String,at:Int64,
                      sealedAdded:Int,looseAdded:Double,reason:String,
                      expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().receiveStock(movementID:movementID,lotID:lotID,at:at,
            sealedAdded:sealedAdded,looseAdded:looseAdded,reason:reason,
            expectedRevision:expectedRevision)
    }
    func reconcileCount(movementID:String,lotID:String,at:Int64,
                        sealed:Int,loose:Double,opened:Double,reason:String,
                        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().reconcilePhysicalCount(movementID:movementID,
            lotID:lotID,at:at,sealed:sealed,loose:loose,opened:opened,
            reason:reason,expectedRevision:expectedRevision)
    }
    /// May only be invoked from a Face ID/code authenticated screen after
    /// the user chooses a new passphrase; never persists plaintext to Files.
    func reconciliationEvents()throws->[N2ReconciliationEventRow] {
        try protectedStore().readReconciliationEvents()
    }
    func appendReconciliationEvent(_ event:Data,expectedRevision:Int)throws
        ->N2ProtectedStoreSummary {
        try protectedStore().appendReconciliationEvent(
            event,catalog:resource("n2-ambulatory-products"),
            expectedRevision:expectedRevision)
    }
    func exportVerifiedIndicatorWorkbook(
        start:String,end:String,subdivision:String,ids:Set<String>,allowPending:Bool=false)throws
        -> N2VerifiedIndicatorWorkbook.Result {
        guard let url=Bundle.main.url(
            forResource:"n1s-indicator-template-store",
            withExtension:"zip",subdirectory:"N1sDemoResources") else{
            throw Failure.blockedMigration
        }
        return try protectedStore().exportVerifiedIndicatorWorkbook(
            products:resource("n2-ambulatory-products"),
            mappings:resource("n2-approved-mappings"),
            template:Data(contentsOf:url),
            start:start,end:end,subdivision:subdivision,ids:ids,allowPending:allowPending)
    }

    func exportOccupationalVigilance(start:String,end:String)throws
        ->N2OccupationalVigilanceWorkbook.Result {
        try protectedStore().exportOccupationalVigilance(start:start,end:end)
    }

    func exportVerifiedDailyNursingWorkbook(date:String,shift:String,
        responsible:String,site:String="")throws->N2VerifiedNursingWorkbook.Result {
        guard let source=Bundle.main.url(
            forResource:"n1s-nursing-template-store",
            withExtension:"zip",subdirectory:"N1sDemoResources") else {
            throw Failure.blockedMigration
        }
        return try protectedStore().exportVerifiedDailyNursingWorkbook(
            catalog:resource("n2-nursing-catalog"),
            template:Data(contentsOf:source),
            date:date,shift:shift,responsible:responsible,site:site)
    }
    func exportVerifiedRangeNursingWorkbook(start:String,end:String,
        responsible:String,site:String="",reconstructFromCount:Bool=false)throws->N2VerifiedNursingWorkbook.Result {
        guard let source=Bundle.main.url(
            forResource:"n1s-nursing-template-store",
            withExtension:"zip",subdirectory:"N1sDemoResources") else {
            throw Failure.blockedMigration
        }
        return try protectedStore().exportVerifiedRangeNursingWorkbook(
            catalog:resource("n2-nursing-catalog"),
            template:Data(contentsOf:source),
            start:start,end:end,responsible:responsible,site:site,
            mappings:resource("n2-approved-mappings"),
            reconstructFromCount:reconstructFromCount)
    }
    func exportPortableEncryptedBackup(password:String)throws->Data {
        guard let secret=try deviceKey(create:false) else{
            throw Failure.missingKey
        }
        let source=try N2ProtectedClinicalVaultCore(keyData:secret,namespace:.synthetic)
            .sourceForEncryptedBackup()
        return try N2NativePortableBackupMaker.createVerified(
            snapshot:source,password:password)
    }
}

