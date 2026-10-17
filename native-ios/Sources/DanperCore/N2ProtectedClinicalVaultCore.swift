import Foundation

/// Strongly isolated N2 native clinical vault. This API never opens the old
/// hybrid app's files or Keychain; all content is local AES-GCM ciphertext.
/// The caller MUST gate real source admission with explicit user consent.
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
    public init(keyData:Data) throws {
        guard let appSupport=FileManager.default.urls(
            for:.applicationSupportDirectory,in:.userDomainMask).first else {
            throw N2ProtectedStoreError.unsafeSource
        }
        directory=appSupport.appendingPathComponent(
            "DANPER-N2-CLINICAL-VAULT",isDirectory:true)
        journal=try N2EncryptedClinicalJournal(
            protectedAppSupportDirectory:directory,secret:keyData)
    }
    private func summary(_ record:N2EncryptedClinicalJournal.Recovered) throws
        -> N2ProtectedStoreSummary {
        let a=try N1eLegacyClinicalAudit.inspect(record.snapshot)
        let b=try N1fLosslessFieldGate.inspect(record.snapshot)
        return N2ProtectedStoreSummary(revision:record.revision,
            workers:a.workers,attentions:a.attentions,
            saved:b.saved,drafts:b.drafts,
            physicalMovements:a.physicalMovements,
            pendingClinicalLines:a.pendingClinicalItems)
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
    public func exportVerifiedIndicatorWorkbook(
        products:Data,mappings:Data,template:Data,
        start:String,end:String,subdivision:String,ids:Set<String>)throws
        -> N2VerifiedIndicatorWorkbook.Result {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        return try N2VerifiedIndicatorWorkbook.export(
            snapshot:active.snapshot,products:products,
            mappings:mappings,template:template,
            start:start,end:end,subdivision:subdivision,
            selectedVisitIDs:ids)
    }

    public func exportVerifiedDailyNursingWorkbook(
        catalog:Data,template:Data,date:String,shift:String,
        responsible:String)throws->N2VerifiedNursingWorkbook.Result {
        guard let active=try journal.recover() else {
            throw N2ProtectedStoreError.absentSource
        }
        return try N2VerifiedNursingWorkbook.export(
            snapshot:active.snapshot,catalog:catalog,template:template,
            date:date,shift:shift,responsible:responsible)
    }
    public func sourceForEncryptedBackup()throws->Data {
        guard let active=try journal.recover() else{
            throw N2ProtectedStoreError.absentSource
        }
        _=try N1eLegacyClinicalAudit.inspect(active.snapshot)
        return active.snapshot
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
        let revision=try journal.commit(next,expectedRevision:expectedRevision)
        guard let verified=try journal.recover(),verified.revision==revision else {
            throw N2ProtectedStoreError.unsafeSource
        }
        return try summary(verified)
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
