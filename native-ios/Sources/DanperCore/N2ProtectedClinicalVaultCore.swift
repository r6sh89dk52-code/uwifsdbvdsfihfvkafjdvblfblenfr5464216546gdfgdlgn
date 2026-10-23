import Foundation

/// Strongly isolated N2 native clinical vault. This API never opens the old
/// hybrid app's files or Keychain; all content is local AES-GCM ciphertext.
/// The caller MUST gate real source admission with explicit user consent.
public struct N2DispensingLine:Identifiable,Sendable {
    public let id:String
    public let name:String
    public let code:String
    public let quantity:Double
    public let result:String
}
public struct N2ProtectedStoreSummary: Sendable {
    public let revision:Int
    public let workers:Int
    public let attentions:Int
    public let saved:Int
    public let drafts:Int
    public let physicalMovements:Int
    public let pendingClinicalLines:Int
}
public enum N2ProtectedStoreError:Error,Equatable {
    case unsafeSource, targetNotEmpty, absentSource, staleRevision
}
public final class N2ProtectedClinicalVaultCore {
    private let journal:N2EncryptedClinicalJournal
    private let directory:URL
    public enum Namespace:Sendable {
        case clinical
        case synthetic
    }
    public init(keyData:Data,namespace:Namespace = .clinical) throws {
        guard let appSupport=FileManager.default.urls(
            for:.applicationSupportDirectory,in:.userDomainMask).first else {
            throw N2ProtectedStoreError.unsafeSource
        }
        directory=appSupport.appendingPathComponent(
            (namespace == .clinical ? "DANPER-N2-CLINICAL-VAULT" :
              "DANPER-N2-SYNTHETIC-VAULT"),isDirectory:true)
        journal=try N2EncryptedClinicalJournal(
            protectedAppSupportDirectory:directory,secret:keyData)
    }
    // Test-only dependency injection; internal, inaccessible to the app module.
    init(testJournal:N2EncryptedClinicalJournal,directory:URL) {
        journal=testJournal;self.directory=directory
    }
    private func summary(_ record:N2EncryptedClinicalJournal.Recovered) throws
        -> N2ProtectedStoreSummary {
        let a=try N1eLegacyClinicalAudit.inspect(
            record.snapshot,
            allowEmptySynthetic:directory.lastPathComponent=="DANPER-N2-SYNTHETIC-VAULT")
        let b=try N1fLosslessFieldGate.inspect(record.snapshot)
        return N2ProtectedStoreSummary(revision:record.revision,
            workers:a.workers,attentions:a.attentions,
            saved:b.saved,drafts:b.drafts,
            physicalMovements:a.physicalMovements,
            pendingClinicalLines:a.pendingClinicalItems)
    }
    public func auxiliaryAccounting()throws->String {
        guard let active=try journal.recover() else{throw N2ProtectedStoreError.absentSource}
        return try N2AuxiliaryInventory.accounting(snapshot:active.snapshot)
    }
    public func registerAuxiliaryLot(clinicalCode:String,lot:Data,catalog:N2NativeCatalogIndex,
                                     operatorName:String,evidence:String,at:Int64,
                                     expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2AuxiliaryInventory.register(snapshot:$0,clinicalCode:clinicalCode,lot:lot,
                catalog:catalog,operatorName:operatorName,evidence:evidence,at:at,explicitConsent:true)
        }
    }
    public func retryDispensing(visitID:String,approvedCatalog:Data,at:Int64,
                               expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2NativeClinicalTransaction.retryCurrentSavedVisit(snapshot:$0,visitID:visitID,
                approvedCatalog:approvedCatalog,at:at).snapshot
        }
    }
    public func confirmOperationalMapping(_ rule:N2OperationalMapping,catalog:N2NativeCatalogIndex,
                                         explicitConsent:Bool,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2OperationalMappings.append(snapshot:$0,rule:rule,catalog:catalog,explicitConsent:explicitConsent)
        }
    }
    public func inspect()throws->N2ProtectedStoreSummary? {
        guard let record=try journal.recover() else{return nil}
        return try summary(record)
    }
    public func readDrafts()throws->[N2RecoverableDraft] {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        return try N2NativeDraftRecovery.read(active.snapshot)
    }
    public func dispensingLines(visitID:String)throws->[N2DispensingLine] {
        guard let active=try journal.recover(),
              let root=try JSONSerialization.jsonObject(with:active.snapshot) as? [String:Any],
              let visits=root["attentions"] as? [[String:Any]],
              let visit=visits.first(where:{$0["id"] as? String==visitID}),
              let items=visit["items"] as? [[String:Any]],
              let movements=root["stockMovements"] as? [[String:Any]] else {
            throw N2ProtectedStoreError.absentSource
        }
        let outcomes=visit["nativeDispensing"] as? [String:String] ?? [:]
        return items.map { item in
            let id=item["id"] as? String ?? ""
            let linked=movements.contains { m in
                guard let ref=m["dispenseRef"] as? [String:Any] else{return false}
                return ref["attentionId"] as? String==visitID && ref["itemId"] as? String==id
            }
            return N2DispensingLine(id:id,name:item["name"] as? String ?? "",
                code:item["code"] as? String ?? "",quantity:(item["quantity"] as? NSNumber)?.doubleValue ?? 0,
                result:linked ? "Descontado" : (outcomes[id] ?? "Pendiente de conciliar: registro histórico sin salida verificada"))
        }
    }
    public func dispensingStatus(visitID:String)throws->[String:String] {
        guard let active=try journal.recover(),
              let root=try JSONSerialization.jsonObject(with:active.snapshot) as? [String:Any],
              let visits=root["attentions"] as? [[String:Any]],
              let visit=visits.first(where:{$0["id"] as? String==visitID}) else {
            throw N2ProtectedStoreError.absentSource
        }
        return visit["nativeDispensing"] as? [String:String] ?? [:]
    }
    public func readIndex()throws->N2NativeReadModel? {
        guard let active=try journal.recover() else{return nil}
        return try N2NativeSnapshotReader.read(active.snapshot)
    }
    public func clinicalFormContext(products:Data,nursing:Data,mappings:Data)
        throws->N2FormContext {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        let catalog=try N2NativeCatalogLoader.load(
            products:products,nursing:nursing,approvedMappings:mappings)
        return try N2NativeFormContextReader.read(
            snapshot:active.snapshot,revision:active.revision,products:catalog)
    }

    /// Caller must reauthenticate and encrypt this data into a portable
    /// backup before ever writing to Files/Share; no plaintext export allowed.
    public func readReconciliationEvents()throws->[N2ReconciliationEventRow] {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        return try N2NativeReconciliationEditor.list(snapshot:active.snapshot)
    }
    public func appendReconciliationEvent(_ event:Data,catalog:Data,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2NativeReconciliationEditor.append(
                snapshot:$0,event:event,catalog:catalog)
        }
    }
    public func exportVerifiedIndicatorWorkbook(
        products:Data,mappings:Data,template:Data,
        start:String,end:String,subdivision:String,ids:Set<String>,allowPending:Bool=false)throws
        -> N2VerifiedIndicatorWorkbook.Result {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        return try N2VerifiedIndicatorWorkbook.export(
            snapshot:active.snapshot,products:products,
            mappings:mappings,template:template,
            start:start,end:end,subdivision:subdivision,
            selectedVisitIDs:ids,allowPending:allowPending)
    }

    public func exportVerifiedDailyNursingWorkbook(
        catalog:Data,template:Data,date:String,shift:String,
        responsible:String,site:String="")throws->N2VerifiedNursingWorkbook.Result {
        guard let active=try journal.recover() else {
            throw N2ProtectedStoreError.absentSource
        }
        return try N2VerifiedNursingWorkbook.export(
            snapshot:active.snapshot,catalog:catalog,template:template,
            date:date,shift:shift,responsible:responsible,site:site)
    }
    public func exportVerifiedRangeNursingWorkbook(
        catalog:Data,template:Data,start:String,end:String,
        responsible:String,site:String="")throws->N2VerifiedNursingWorkbook.Result {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        return try N2VerifiedNursingWorkbook.exportRange(
            snapshot:active.snapshot,catalog:catalog,template:template,
            start:start,end:end,responsible:responsible,site:site)
    }
    /// Read-only 9th-day reconciliation against the encrypted single-source
    /// journal. Never writes a stock movement or returns raw clinical records
    /// to the SwiftUI screen.
    public func automaticCutAccounting(mappings:Data,through date:String)
        throws->N2AutomaticCutAccounting.Result {
        guard let active=try journal.recover() else {
            throw N2ProtectedStoreError.absentSource
        }
        return try N2AutomaticCutAccounting.calculate(
            snapshot:active.snapshot,mappings:mappings,through:date)
    }
    public func sourceForEncryptedBackup()throws->Data {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        _=try N1eLegacyClinicalAudit.inspect(active.snapshot)
        return active.snapshot
    }
    /// Starts a genuinely EMPTY encrypted practice vault. Unlike the bundled
    /// synthetic fixture it contains ZERO visits, workers, stock or movements.
    /// No prior files or encrypted generations may be overwritten.
    @discardableResult
    public func activateEmptySynthetic(confirmed:Bool)throws
        ->N2ProtectedStoreSummary {
        guard confirmed,
              directory.lastPathComponent=="DANPER-N2-SYNTHETIC-VAULT",
              try journal.recover()==nil,
              try FileManager.default.contentsOfDirectory(
                  at:directory,includingPropertiesForKeys:nil).isEmpty else {
            throw N2ProtectedStoreError.targetNotEmpty
        }
        let source=try N2EmptyDemoSnapshot.make()
        let n=try journal.commit(source,expectedRevision:0)
        guard let active=try journal.recover(),active.revision==n,
              active.snapshot==source else {
            throw N2ProtectedStoreError.unsafeSource
        }
        let result=try summary(active)
        guard result.workers==0,result.attentions==0,result.drafts==0,
              result.physicalMovements==0 else {
            throw N2ProtectedStoreError.unsafeSource
        }
        return result
    }

    /// Explicitly start an isolated sandbox containing ONLY the five documented
    /// fictional employees. This path cannot restore or mix actual patient
    /// records, and is physically separate from the clinical vault.
    @discardableResult
    public func activateSyntheticFixture(_ source:Data,confirmed:Bool)throws
        ->N2ProtectedStoreSummary {
        guard confirmed,directory.lastPathComponent=="DANPER-N2-SYNTHETIC-VAULT",
              try journal.recover()==nil,
              let root=try? JSONSerialization.jsonObject(with:source)
                 as? [String:Any],
              let workers=root["workers"] as? [[String:Any]],
              let visits=root["attentions"] as? [[String:Any]],
              N2SyntheticFixtureIdentity.matches(workers:workers,visits:visits) else {
            throw N2ProtectedStoreError.unsafeSource
        }
        _=try N1eLegacyClinicalAudit.inspect(source)
        _=try N1fLosslessFieldGate.inspect(source)
        let n=try journal.commit(source,expectedRevision:0)
        guard let active=try journal.recover(),active.revision==n,
              active.snapshot==source else{throw N2ProtectedStoreError.unsafeSource}
        return try summary(active)
    }

    /// Admission of ONE previously verified complete backup, never a merge.
    /// No silent bootstrap or automatic migration on first launch.
    @discardableResult
    public func activateSingleVerifiedSource(_ plaintext:Data,
                                             explicitConsent:Bool)throws
        -> N2ProtectedStoreSummary {
        guard explicitConsent else{throw N2ProtectedStoreError.unsafeSource}
        guard try journal.recover() == nil else{
            throw N2ProtectedStoreError.targetNotEmpty
        }
        // If an interrupted first-time import left encrypted orphan files,
        // refuse to initialize a different base on top of them.
        let contents=try FileManager.default.contentsOfDirectory(
            at:directory,includingPropertiesForKeys:nil)
        guard contents.isEmpty else{throw N2ProtectedStoreError.targetNotEmpty}
        let audit=try N1lRealSnapshotGate.audit(plaintext,
                                                 destination:.verifiedEmpty)
        guard audit.isStructurallyEligibleForReview,
              audit.unknownFutureFieldsPreserved,
              audit.obviousDemoWorkerMarkers==0,
              audit.obviousDemoClinicalMarkers==0,
              audit.missingRosterReferences==0,
              audit.danglingCorrections==0 else {
            throw N2ProtectedStoreError.unsafeSource
        }
        _=try N1eLegacyClinicalAudit.inspect(plaintext)
        let n=try journal.commit(plaintext,expectedRevision:0)
        guard let active=try journal.recover(),active.revision==n,
              active.snapshot==plaintext else{
            throw N2ProtectedStoreError.unsafeSource
        }
        return try summary(active)
    }

    /// Initial PERSONAL import requires a genuinely empty CLINICAL domain.
    /// Synthetic employees, histories and stock NEVER accompany these rows.
    public func activateInitialPersonal(preview:N2PersonalImportPreview,
                                        site:String,explicitConsent:Bool)throws
        ->N2ProtectedStoreSummary {
        guard directory.lastPathComponent=="DANPER-N2-CLINICAL-VAULT",
              explicitConsent else{throw N2ProtectedStoreError.unsafeSource}
        let source=try N2PersonalRosterImport.initialSnapshot(
            preview:preview,site:site)
        return try activateSingleVerifiedSource(source,
                                               explicitConsent:explicitConsent)
    }
    /// A read-only conflict check; no clinical source is ever returned to UI.
    public func previewPersonalMerge(preview:N2PersonalImportPreview,
                                     site:String)throws->N2PersonalImportResult {
        guard let active=try journal.recover() else {
            throw N2ProtectedStoreError.absentSource
        }
        return try N2PersonalRosterImport.merge(
            snapshot:active.snapshot,preview:preview,site:site).1
    }
    /// Single atomic generation; concurrent visits, stock or roster changes
    /// cause staleRevision and must be re-reviewed rather than retried blindly.
    public func mergePersonal(preview:N2PersonalImportPreview,site:String,
                              expectedRevision:Int)throws->N2PersonalImportResult {
        guard directory.lastPathComponent=="DANPER-N2-CLINICAL-VAULT",
              let active=try journal.recover() else {
            throw N2ProtectedStoreError.absentSource
        }
        guard active.revision==expectedRevision else {
            throw N2ProtectedStoreError.staleRevision
        }
        let (next,result)=try N2PersonalRosterImport.merge(
            snapshot:active.snapshot,preview:preview,site:site)
        guard next != active.snapshot else{return result}
        let revision=try journal.commit(next,expectedRevision:expectedRevision)
        guard let checked=try journal.recover(),checked.revision==revision,
              checked.snapshot==next else {
            throw N2ProtectedStoreError.unsafeSource
        }
        return result
    }

    /// Every edit is validated and promoted with a single atomic generation;
    /// no independent asynchronous workers/stock saves may be interleaved.
    private func modify(expectedRevision:Int,
                        _ f:(Data)throws->Data)throws->N2ProtectedStoreSummary {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        guard active.revision==expectedRevision else{
            throw N2ProtectedStoreError.staleRevision
        }
        let next=try f(active.snapshot)
        // Idempotent replay of a verified event must not waste a generation.
        guard next != active.snapshot else{return try summary(active)}
        let revision=try journal.commit(next,expectedRevision:expectedRevision)
        guard let verified=try journal.recover(),verified.revision==revision else {
            throw N2ProtectedStoreError.unsafeSource
        }
        return try summary(verified)
    }
    @discardableResult
    public func correctWorker(dni:String,worker:Data,at:Int64,
                              expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2SnapshotEditor.correctWorker(snapshot:$0,dni:dni,worker:worker,at:at)
        }
    }
    @discardableResult
    public func registerWorker(_ worker:Data,at:Int64,
                               expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2SnapshotEditor.addWorker(snapshot:$0,worker:worker,at:at)
        }
    }
    @discardableResult
    public func reviewAllergies(dni:String,status:String,substances:String,
                               at:Int64,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2SnapshotEditor.reviewAllergies(snapshot:$0,dni:dni,status:status,
                                                  substances:substances,at:at)
        }
    }
    @discardableResult
    public func saveDraft(id:String,changes:Data,at:Int64,
                          expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2SnapshotEditor.upsertDraft(snapshot:$0,id:id,changes:changes,at:at)
        }
    }
    @discardableResult
    public func removeDraft(id:String,
                            expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2SnapshotEditor.deleteDraft(snapshot:$0,id:id)
        }
    }
    /// Runs the exact physical planner against an in-memory copy. No journal commit,
    /// draft mutation, stock deduction or generation increment occurs in this method.
    public func previewAttention(_ attention:Data,approvedCatalog:Data,at:Int64,
                                 expectedRevision:Int)throws->N2ClinicalResult {
        guard let active=try journal.recover() else{throw N2ProtectedStoreError.absentSource}
        guard active.revision==expectedRevision else{throw N2ProtectedStoreError.staleRevision}
        return try N2NativeClinicalTransaction.appendSavedVisit(snapshot:active.snapshot,
            visit:attention,approvedCatalog:approvedCatalog,at:at)
    }
    @discardableResult
    public func verifyOriginalStockSite(eventID:String,lotID:String,site:String,
        reason:String,operatorName:String,at:Int64,expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2NativeInventoryCommands.verifyOriginalSite(snapshot:$0,eventID:eventID,
                lotID:lotID,site:site,reason:reason,operatorName:operatorName,at:at)
        }
    }
    @discardableResult
    public func registerStockLot(_ lot:Data,nursingCatalog:Data,
                                 expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2NativeInventoryCommands.registerLot(
                snapshot:$0,lot:lot,catalogData:nursingCatalog)
        }
    }
    @discardableResult
    public func receiveStock(movementID:String,lotID:String,at:Int64,
                             sealedAdded:Int,looseAdded:Double,reason:String,
                             expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2NativeInventoryCommands.extraordinary(snapshot:$0,
                movementID:movementID,lotID:lotID,at:at,
                sealedAdded:sealedAdded,looseAdded:looseAdded,reason:reason)
        }
    }
    @discardableResult
    public func reconcilePhysicalCount(movementID:String,lotID:String,at:Int64,
                                      sealed:Int,loose:Double,opened:Double,
                                      reason:String,expectedRevision:Int)throws
        ->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2NativeInventoryCommands.adjustment(snapshot:$0,
                movementID:movementID,lotID:lotID,at:at,
                newSealed:sealed,newLoose:loose,newOpened:opened,reason:reason)
        }
    }
    public func readPendingClinicalCorrection(visitID:String)throws
        ->N2PendingClinicalCorrection? {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        return try N2ClinicalCorrections.pendingDraft(
            snapshot:active.snapshot,visitID:visitID)
    }
    @discardableResult
    public func savePendingClinicalCorrection(visitID:String,changes:Data,
        reason:String,operatorName:String,medicationDiscrepancy:String,
        expectedEffectiveSHA:String,at:Int64,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2ClinicalCorrections.savePendingDraft(
                snapshot:$0,visitID:visitID,changes:changes,reason:reason,
                operatorName:operatorName,
                medicationDiscrepancy:medicationDiscrepancy,
                expectedEffectiveSHA:expectedEffectiveSHA,at:at)
        }
    }
    public func deletePendingClinicalCorrection(visitID:String,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2ClinicalCorrections.deletePendingDraft(
                snapshot:$0,visitID:visitID)
        }
    }
    public func readCorrectionHistory(visitID:String)throws
        ->[N2CorrectionHistoryEntry] {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        return try N2ClinicalCorrections.history(
            snapshot:active.snapshot,visitID:visitID)
    }
    public func readCorrectionDetail(visitID:String)throws->N2CorrectionDetail {
        guard let active=try journal.recover() else {
            throw N2ProtectedStoreError.absentSource
        }
        return try N2ClinicalCorrections.detail(snapshot:active.snapshot,visitID:visitID)
    }
    @discardableResult
    public func saveClinicalCorrection(visitID:String,eventID:String,changes:Data,
        reason:String,operatorName:String,medicationDiscrepancy:String,
        expectedEffectiveSHA:String,at:Int64,
        expectedRevision:Int)throws->N2ProtectedStoreSummary {
        try modify(expectedRevision:expectedRevision) {
            try N2ClinicalCorrections.append(snapshot:$0,eventID:eventID,
                visitID:visitID,changes:changes,reason:reason,
                operatorName:operatorName,
                medicationDiscrepancy:medicationDiscrepancy,
                expectedEffectiveSHA:expectedEffectiveSHA,at:at)
        }
    }
    public func saveAttention(_ visit:Data,approvedCatalog:Data,at:Int64,
                              expectedRevision:Int)throws
        -> N2ProtectedStoreSummary {
        let actor=N2AtomicClinicalCoordinator(journal:journal)
        _=try actor.save(visit:visit,approvedCatalog:approvedCatalog,
                         at:at,expectedRevision:expectedRevision)
        guard let committed=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        return try summary(committed)
    }
}

