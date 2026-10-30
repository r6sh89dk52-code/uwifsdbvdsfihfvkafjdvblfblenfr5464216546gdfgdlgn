import Foundation
import UIKit
import CryptoKit
import Security
import DanperCore

/// Separate native clinical domain. Does not access build222, N1i or N1m
/// Keychain. No view starts migration or activation automatically.
actor N2ProtectedClinicalIOSVault {
    static let shared=N2ProtectedClinicalIOSVault()
    private var sessionStore:(secret:Data,store:N2ProtectedClinicalVaultCore)?
    private init() {
        // Singleton lifetime observers, no patient fields in notifications.
        for name in [UIApplication.didEnterBackgroundNotification,
                     UIApplication.protectedDataWillBecomeUnavailableNotification] {
            _=NotificationCenter.default.addObserver(forName:name,object:nil,queue:nil) { [weak self] _ in
                Task {await self?.clearSessionCaches()}
            }
        }
    }
    func clearSessionCaches() {sessionStore=nil}
    private func sessionStore(for secret:Data)throws->N2ProtectedClinicalVaultCore {
        if let current=sessionStore,current.secret==secret {return current.store}
        sessionStore=nil
        let store=try N2ProtectedClinicalVaultCore(keyData:secret)
        sessionStore=(secret,store)
        return store
    }
    private let service="pe.danper.saludmovil.native.iloaderpreview.n2.clinical"
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
    func hasStoredClinicalSource()->Bool {hasClinicalFiles()}

    private var resourceCache=[String:Data]()
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
        do {
            guard let secret=try deviceKey(create:false) else {sessionStore=nil;return nil}
            return try sessionStore(for:secret).inspect()
        } catch {sessionStore=nil;throw error}
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
    /// Only the encrypted CLINICAL namespace can create or merge PERSONAL.
    /// Never uses or clears N2SyntheticTrialIOSVault, N1m or build222.
    func activateInitialPersonal(_ preview:N2PersonalImportPreview,
                                 site:String,approvedByUser:Bool)throws
        ->N2ProtectedStoreSummary {
        guard approvedByUser else{throw Failure.blockedMigration}
        guard let secret=try deviceKey(create:true) else {
            throw Failure.unavailableKeychain
        }
        return try N2ProtectedClinicalVaultCore(keyData:secret)
            .activateInitialPersonal(preview:preview,site:site,
                                     explicitConsent:approvedByUser)
    }
    func previewPersonalMerge(_ preview:N2PersonalImportPreview,
                              site:String)throws->N2PersonalImportResult {
        try protectedStore().previewPersonalMerge(preview:preview,site:site)
    }
    func mergePersonal(_ preview:N2PersonalImportPreview,
                       site:String,expectedRevision:Int)throws->N2PersonalImportResult {
        try protectedStore().mergePersonal(preview:preview,site:site,
                                           expectedRevision:expectedRevision)
    }

    func currentRevision()throws->Int {
        try protectedStore().currentRevision()
    }
    func readDrafts()throws->[N2RecoverableDraft] {
        try protectedStore().readDrafts()
    }
    func readDraftsWithRevision()throws->(revision:Int,drafts:[N2RecoverableDraft]) {
        try protectedStore().readDraftsWithRevision()
    }
    func dispensingLines(visitID:String)throws->[N2DispensingLine] {
        try protectedStore().dispensingLines(visitID:visitID)
    }
    func dispensingStatus(visitID:String)throws->[String:String] {
        try protectedStore().dispensingStatus(visitID:visitID)
    }
    func dashboardSnapshot(today:String,weekStart:String)throws->N2DashboardSnapshot? {
        try protectedStore().dashboardSnapshot(today:today,weekStart:weekStart)
    }
    func dashboardCounters(today:String,weekStart:String)throws
        ->(today:Int,week:Int,month:Int,drafts:Int)? {
        try protectedStore().dashboardCounters(today:today,weekStart:weekStart)
    }
    func readDashboard()throws
        ->(history:N2NativeReadModel?,drafts:[N2RecoverableDraft]) {
        try protectedStore().readDashboard()
    }
    func readHistory()throws->N2NativeReadModel? {
        do {
            guard let secret=try deviceKey(create:false) else {sessionStore=nil;return nil}
            return try sessionStore(for:secret).readIndex()
        } catch {sessionStore=nil;throw error}
    }
    private func protectedStore()throws->N2ProtectedClinicalVaultCore {
        do {
            // Always check the device-only Keychain. Cached proof cannot
            // bypass a locked device, a missing key or another key.
            guard let secret=try deviceKey(create:false) else{throw Failure.missingKey}
            return try sessionStore(for:secret)
        } catch {sessionStore=nil;throw error}
    }
    private func resource(_ name:String)throws->Data {
        if let cached=resourceCache[name] {return cached}
        guard let source=Bundle.main.url(forResource:name,withExtension:"json",
                   subdirectory:"N1sDemoResources") else{
            throw Failure.blockedMigration
        }
        let data=try Data(contentsOf:source)
        resourceCache[name]=data
        return data
    }
    func registerWorker(_ worker:Data,at:Int64,expectedRevision:Int)
        throws->N2ProtectedStoreSummary {
        try protectedStore().registerWorker(worker,at:at,expectedRevision:expectedRevision)
    }
    func correctWorker(dni:String,worker:Data,at:Int64,
                       expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().correctWorker(dni:dni,worker:worker,
                                           at:at,expectedRevision:expectedRevision)
    }
    func reviewAllergiesRevision(dni:String,status:String,substances:String,
                        at:Int64,expectedRevision:Int)throws->Int {
        try protectedStore().reviewAllergiesRevision(
            dni:dni,status:status,substances:substances,
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
    /// Same encrypted source as the Indicator and nursing Kardex.
    /// Read-only: never posts movements or reconfirms a completed visit.
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
    func prepareClinicalCorrection(visitID:String)throws->N2CorrectionReadContext {
        try protectedStore().prepareClinicalCorrection(visitID:visitID)
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
        try protectedStore().saveAttentionWithoutLegacyInventory(attention,
            approvedCatalog:resource("n2-approved-mappings"),
            at:at,expectedRevision:expectedRevision)
    }
    func previewAttention(_ attention:Data,visitID:String,at:Int64,
                          expectedRevision:Int)throws->[String:String] {
        let result=try protectedStore().previewAttentionWithoutLegacyInventory(attention,
            approvedCatalog:resource("n2-approved-mappings"),
            at:at,expectedRevision:expectedRevision)
        let root=try JSONSerialization.jsonObject(with:result.snapshot) as? [String:Any]
        let visits=root?["attentions"] as? [[String:Any]]
        return visits?.first{$0["id"] as? String==visitID}?["nativeDispensing"]
            as? [String:String] ?? [:]
    }
    func verifyOriginalStockSite(eventID:String,lotID:String,site:String,
                                 reason:String,operatorName:String,
                                 at:Int64,expectedRevision:Int)
        throws->N2ProtectedStoreSummary {
        try protectedStore().verifyOriginalStockSite(
            eventID:eventID,lotID:lotID,site:site,reason:reason,
            operatorName:operatorName,at:at,expectedRevision:expectedRevision)
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
        start:String,end:String,subdivision:String,ids:Set<String>,
        allowPending:Bool=false)throws
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
            start:start,end:end,subdivision:subdivision,ids:ids,
            allowPending:allowPending)
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
            date:date,shift:shift,responsible:responsible,site:site,mappings:resource("n2-approved-mappings"))
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
        let source=try N2ProtectedClinicalVaultCore(keyData:secret)
            .sourceForEncryptedBackup()
        return try N2NativePortableBackupMaker.createVerified(
            snapshot:source,password:password,domain:.clinical)
    }
}

extension N2ProtectedClinicalIOSVault {
    private func simpleCatalog()throws->N2NativeCatalogIndex {
        try N2NativeCatalogLoader.load(products:resource("n2-ambulatory-products"),
            nursing:resource("n2-nursing-catalog"),approvedMappings:resource("n2-approved-mappings"))
    }
    func simpleInventoryContext()throws->N2SimpleInventoryContext {
        try protectedStore().simpleInventoryContext(products:resource("n2-ambulatory-products"),
            nursing:resource("n2-nursing-catalog"),mappings:resource("n2-approved-mappings"))
    }
    func inspectSimpleBackup(_ archive:Data,password:String)throws->N2SimpleBackupReview {
        let proof=try N2InventoryBackupCodec.verify(archive:archive,password:password)
        guard proof.domain != .demo else{throw Failure.blockedMigration}
        return N2SimpleBackupReview(proof)
    }
    func activateSimpleInventory(archive:Data,password:String,request:N2SimpleActivation,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        let proof=try N2InventoryBackupCodec.verify(archive:archive,password:password)
        try Task.checkCancellation()
        return try protectedStore().activateSimpleInventory(backup:proof,request:request,
            catalog:simpleCatalog(),expectedRevision:expectedRevision)
    }
    func applySimpleInventoryCommand(_ command:N2SimpleInventoryCommand,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try protectedStore().applySimpleInventoryCommand(command,catalog:simpleCatalog(),expectedRevision:expectedRevision)
    }
    func restoreSimpleClinical(archive:Data,password:String,eventID:String,operatorName:String,
        at:Int64,confirmed:Bool,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        let proof=try N2InventoryBackupCodec.verify(archive:archive,password:password)
        try Task.checkCancellation()
        return try protectedStore().restoreSimpleClinical(backup:proof,eventID:eventID,
            operatorName:operatorName,at:at,confirmed:confirmed,expectedRevision:expectedRevision)
    }
    func recoverPortableSource(archive:Data,password:String,confirmed:Bool)throws->N2ProtectedStoreSummary {
        guard confirmed else{throw Failure.blockedMigration}
        let proof=try N2InventoryBackupCodec.verify(archive:archive,password:password)
        guard proof.domain != .demo else{throw Failure.blockedMigration}
        try Task.checkCancellation()
        guard let secret=try deviceKey(create:true) else{throw Failure.unavailableKeychain}
        return try N2ProtectedClinicalVaultCore(keyData:secret).recoverPortableSource(backup:proof,confirmed:confirmed)
    }
}

extension N2ProtectedClinicalIOSVault {
    func simpleInventoryCut(code:String,through:String,archive:Data?,password:String?)throws->N2SimpleCutPreview {
        let proof: N2VerifiedInventoryBackup?
        if let archive,let password {proof=try N2InventoryBackupCodec.verify(archive:archive,password:password)}
        else {proof=nil}
        return try protectedStore().simpleInventoryCut(code:code,through:through,catalog:simpleCatalog(),backup:proof)
    }
}
