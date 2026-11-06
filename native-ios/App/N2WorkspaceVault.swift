import SwiftUI
import DanperCore

/// Immutable source selection: a call can NEVER automatically switch from
/// the fictitious workspace to the protected clinical vault.
struct N2WorkspaceVault:Sendable {
    enum Mode:String,Sendable {case demo,clinical}
    let mode:Mode
    init(_ mode:Mode){self.mode=mode}
    static let demo=N2WorkspaceVault(.demo)
    static let clinical=N2WorkspaceVault(.clinical)
    var isClinical:Bool {mode == .clinical}

    private func verifiedChange(_ result:N2ProtectedStoreSummary,kind:String)->N2ProtectedStoreSummary {
        N2WorkspaceChanges.post(mode:mode,revision:result.revision,kind:kind)
        return result
    }

    func inspect() async throws -> N2ProtectedStoreSummary? {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.inspect()
        }
        return try await N2SyntheticTrialIOSVault.shared.inspect()
    }
    func currentRevision() async throws -> Int {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.currentRevision()
        }
        return try await N2SyntheticTrialIOSVault.shared.currentRevision()
    }
    func readDrafts() async throws -> [N2RecoverableDraft] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readDrafts()
        }
        return try await N2SyntheticTrialIOSVault.shared.readDrafts()
    }
    func readDraftsWithRevision() async throws
        ->(revision:Int,drafts:[N2RecoverableDraft]) {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readDraftsWithRevision()
        }
        return try await N2SyntheticTrialIOSVault.shared.readDraftsWithRevision()
    }
    func dispensingLines(visitID:String) async throws -> [N2DispensingLine] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.dispensingLines(visitID:visitID)
        }
        return try await N2SyntheticTrialIOSVault.shared.dispensingLines(visitID:visitID)
    }
    func dispensingStatus(visitID:String) async throws -> [String:String] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.dispensingStatus(visitID:visitID)
        }
        return try await N2SyntheticTrialIOSVault.shared.dispensingStatus(visitID:visitID)
    }
    /// Dashboard counters are computed from one fixed vault revision.
    /// The home counter needs only three integers, not a 9k-worker
    /// history read model. Preserve demo/clinical isolation.
    func dashboardSnapshot(today:String,weekStart:String) async throws->N2DashboardSnapshot? {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.dashboardSnapshot(today:today,weekStart:weekStart)
        }
        return try await N2SyntheticTrialIOSVault.shared.dashboardSnapshot(today:today,weekStart:weekStart)
    }
    func dashboardCounters(today:String,weekStart:String) async throws
        ->(today:Int,week:Int,month:Int,drafts:Int)? {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared
                .dashboardCounters(today:today,weekStart:weekStart)
        }
        return try await N2SyntheticTrialIOSVault.shared
            .dashboardCounters(today:today,weekStart:weekStart)
    }
    func readDashboard() async throws
        ->(history:N2NativeReadModel?,drafts:[N2RecoverableDraft]) {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readDashboard()
        }
        return try await N2SyntheticTrialIOSVault.shared.readDashboard()
    }
    func readHistoryWithRevision() async throws ->(revision:Int,model:N2NativeReadModel)? {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readHistoryWithRevision()
        }
        return try await N2SyntheticTrialIOSVault.shared.readHistoryWithRevision()
    }
    func readHistory() async throws -> N2NativeReadModel? {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readHistory()
        }
        return try await N2SyntheticTrialIOSVault.shared.readHistory()
    }
    func registerWorker(_ worker:Data,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.registerWorker(worker,at:at,expectedRevision:expectedRevision),kind:"workers")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.registerWorker(worker,at:at,expectedRevision:expectedRevision),kind:"workers")
    }
    func correctWorker(dni:String,worker:Data,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.correctWorker(dni:dni,worker:worker,at:at,expectedRevision:expectedRevision),kind:"workers")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.correctWorker(dni:dni,worker:worker,at:at,expectedRevision:expectedRevision),kind:"workers")
    }
    func reviewAllergiesRevision(dni:String,status:String,substances:String,
                                 at:Int64,expectedRevision:Int) async throws -> Int {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.reviewAllergiesRevision(
                dni:dni,status:status,substances:substances,
                at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.reviewAllergiesRevision(
            dni:dni,status:status,substances:substances,
            at:at,expectedRevision:expectedRevision)
    }
    func reviewAllergies(dni:String,status:String,substances:String,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.reviewAllergies(dni:dni,status:status,substances:substances,at:at,expectedRevision:expectedRevision),kind:"workers")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.reviewAllergies(dni:dni,status:status,substances:substances,at:at,expectedRevision:expectedRevision),kind:"workers")
    }
    func saveDraft(id:String,changes:Data,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.saveDraft(id:id,changes:changes,at:at,expectedRevision:expectedRevision),kind:"draft")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.saveDraft(id:id,changes:changes,at:at,expectedRevision:expectedRevision),kind:"draft")
    }
    func deleteDraft(id:String,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.deleteDraft(id:id,expectedRevision:expectedRevision),kind:"draft")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.deleteDraft(id:id,expectedRevision:expectedRevision),kind:"draft")
    }
    func confirmPendingDispensing(_ evidence:N2PendingDispensingEvidence,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.confirmPendingDispensing(evidence,expectedRevision:expectedRevision),kind:"inventory")}
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.confirmPendingDispensing(evidence,expectedRevision:expectedRevision),kind:"inventory")
    }
    func closeContainers(lotID:String,count:Int,disposition:String,operatorName:String,reason:String,at:Int64,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.closeContainers(lotID:lotID,count:count,disposition:disposition,operatorName:operatorName,reason:reason,at:at,expectedRevision:expectedRevision),kind:"inventory")}
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.closeContainers(lotID:lotID,count:count,disposition:disposition,operatorName:operatorName,reason:reason,at:at,expectedRevision:expectedRevision),kind:"inventory")
    }
    func auxiliaryAccounting() async throws->String {
        if isClinical {return try await N2ProtectedClinicalIOSVault.shared.auxiliaryAccounting()}
        return try await N2SyntheticTrialIOSVault.shared.auxiliaryAccounting()
    }
    func registerAuxiliaryLot(clinicalCode:String,lot:Data,operatorName:String,evidence:String,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.registerAuxiliaryLot(clinicalCode:clinicalCode,lot:lot,operatorName:operatorName,evidence:evidence,expectedRevision:expectedRevision),kind:"inventory")}
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.registerAuxiliaryLot(clinicalCode:clinicalCode,lot:lot,operatorName:operatorName,evidence:evidence,expectedRevision:expectedRevision),kind:"inventory")
    }
    func retryDispensing(visitID:String,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.retryDispensing(visitID:visitID,expectedRevision:expectedRevision),kind:"inventory")}
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.retryDispensing(visitID:visitID,expectedRevision:expectedRevision),kind:"inventory")
    }
    func confirmOperationalMapping(_ rule:N2OperationalMapping,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.confirmOperationalMapping(rule,expectedRevision:expectedRevision),kind:"inventory")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.confirmOperationalMapping(rule,expectedRevision:expectedRevision),kind:"inventory")
    }
    /// Form and drafts are always from one authenticated snapshot and
    /// one immutable revision. Demo/clinical separation is unchanged.
    func prepareClinicalForm() async throws
        ->(context:N2FormContext,drafts:[N2RecoverableDraft]) {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.prepareClinicalForm()
        }
        return try await N2SyntheticTrialIOSVault.shared.prepareClinicalForm()
    }
    func clinicalFormContext() async throws -> N2FormContext {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.clinicalFormContext()
        }
        return try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
    }
    /// Read-only accounting from the selected vault only.
    /// Do not switch silently between demo and clinical data.
    func automaticCutAccounting(through date:String) async throws
        ->N2AutomaticCutAccounting.Result {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared
                .automaticCutAccounting(through:date)
        }
        return try await N2SyntheticTrialIOSVault.shared
            .automaticCutAccounting(through:date)
    }

    func readPendingClinicalCorrection(visitID:String) async throws -> N2PendingClinicalCorrection? {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readPendingClinicalCorrection(visitID:visitID)
        }
        return try await N2SyntheticTrialIOSVault.shared.readPendingClinicalCorrection(visitID:visitID)
    }
    func savePendingClinicalCorrection(visitID:String,changes:Data,reason:String,operatorName:String,medicationDiscrepancy:String,expectedEffectiveSHA:String,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.savePendingClinicalCorrection(visitID:visitID,changes:changes,reason:reason,operatorName:operatorName,medicationDiscrepancy:medicationDiscrepancy,expectedEffectiveSHA:expectedEffectiveSHA,at:at,expectedRevision:expectedRevision),kind:"draft")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.savePendingClinicalCorrection(visitID:visitID,changes:changes,reason:reason,operatorName:operatorName,medicationDiscrepancy:medicationDiscrepancy,expectedEffectiveSHA:expectedEffectiveSHA,at:at,expectedRevision:expectedRevision),kind:"draft")
    }
    func deletePendingClinicalCorrection(visitID:String,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.deletePendingClinicalCorrection(visitID:visitID,expectedRevision:expectedRevision),kind:"draft")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.deletePendingClinicalCorrection(visitID:visitID,expectedRevision:expectedRevision),kind:"draft")
    }
    func readCorrectionHistory(visitID:String) async throws -> [N2CorrectionHistoryEntry] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readCorrectionHistory(visitID:visitID)
        }
        return try await N2SyntheticTrialIOSVault.shared.readCorrectionHistory(visitID:visitID)
    }
    func prepareClinicalCorrection(visitID:String) async throws->N2CorrectionReadContext {
        if isClinical {return try await N2ProtectedClinicalIOSVault.shared.prepareClinicalCorrection(visitID:visitID)}
        return try await N2SyntheticTrialIOSVault.shared.prepareClinicalCorrection(visitID:visitID)
    }
    func readCorrectionDetail(visitID:String) async throws -> N2CorrectionDetail {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readCorrectionDetail(visitID:visitID)
        }
        return try await N2SyntheticTrialIOSVault.shared.readCorrectionDetail(visitID:visitID)
    }
    func saveClinicalCorrection(visitID:String,eventID:String,changes:Data,reason:String,operatorName:String,medicationDiscrepancy:String,expectedEffectiveSHA:String,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.saveClinicalCorrection(visitID:visitID,eventID:eventID,changes:changes,reason:reason,operatorName:operatorName,medicationDiscrepancy:medicationDiscrepancy,expectedEffectiveSHA:expectedEffectiveSHA,at:at,expectedRevision:expectedRevision),kind:"history")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.saveClinicalCorrection(visitID:visitID,eventID:eventID,changes:changes,reason:reason,operatorName:operatorName,medicationDiscrepancy:medicationDiscrepancy,expectedEffectiveSHA:expectedEffectiveSHA,at:at,expectedRevision:expectedRevision),kind:"history")
    }
    func saveAttention(_ attention:Data,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.saveAttention(attention,at:at,expectedRevision:expectedRevision),kind:"history")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.saveAttention(attention,at:at,expectedRevision:expectedRevision),kind:"history")
    }
    func previewAttention(_ attention:Data,visitID:String,at:Int64,expectedRevision:Int) async throws -> [String:String] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.previewAttention(attention,visitID:visitID,at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.previewAttention(attention,visitID:visitID,at:at,expectedRevision:expectedRevision)
    }
    func verifyOriginalStockSite(eventID:String,lotID:String,site:String,reason:String,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.verifyOriginalStockSite(eventID:eventID,lotID:lotID,site:site,reason:reason,operatorName:"Felipe Azcárate Silva",at:at,expectedRevision:expectedRevision),kind:"inventory")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.verifyOriginalStockSite(eventID:eventID,lotID:lotID,site:site,reason:reason,at:at,expectedRevision:expectedRevision),kind:"inventory")
    }
    func addLot(_ lot:Data,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.addLot(lot,expectedRevision:expectedRevision),kind:"inventory")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.addLot(lot,expectedRevision:expectedRevision),kind:"inventory")
    }
    func correctUnusedLot(lotID:String,reference:String,expires:String,
        reason:String,operatorName:String,at:Int64,
        expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.correctUnusedLot(
                lotID:lotID,reference:reference,expires:expires,reason:reason,
                operatorName:operatorName,at:at,expectedRevision:expectedRevision),kind:"inventory")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.correctUnusedLot(
            lotID:lotID,reference:reference,expires:expires,reason:reason,
            operatorName:operatorName,at:at,expectedRevision:expectedRevision),kind:"inventory")
    }
    func receiveStock(movementID:String,lotID:String,at:Int64,sealedAdded:Int,looseAdded:Double,reason:String,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.receiveStock(movementID:movementID,lotID:lotID,at:at,sealedAdded:sealedAdded,looseAdded:looseAdded,reason:reason,expectedRevision:expectedRevision),kind:"inventory")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.receiveStock(movementID:movementID,lotID:lotID,at:at,sealedAdded:sealedAdded,looseAdded:looseAdded,reason:reason,expectedRevision:expectedRevision),kind:"inventory")
    }
    func reconcileCount(movementID:String,lotID:String,at:Int64,sealed:Int,loose:Double,opened:Double,reason:String,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.reconcileCount(movementID:movementID,lotID:lotID,at:at,sealed:sealed,loose:loose,opened:opened,reason:reason,expectedRevision:expectedRevision),kind:"inventory")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.reconcileCount(movementID:movementID,lotID:lotID,at:at,sealed:sealed,loose:loose,opened:opened,reason:reason,expectedRevision:expectedRevision),kind:"inventory")
    }
    func reconciliationEvents() async throws -> [N2ReconciliationEventRow] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.reconciliationEvents()
        }
        return try await N2SyntheticTrialIOSVault.shared.reconciliationEvents()
    }
    func appendReconciliationEvent(_ event:Data,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.appendReconciliationEvent(event,expectedRevision:expectedRevision),kind:"inventory")
        }
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.appendReconciliationEvent(event,expectedRevision:expectedRevision),kind:"inventory")
    }
    func exportVerifiedIndicatorWorkbook(start:String,end:String,subdivision:String,ids:Set<String>,allowPending:Bool=false) async throws -> N2VerifiedIndicatorWorkbook.Result {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.exportVerifiedIndicatorWorkbook(start:start,end:end,subdivision:subdivision,ids:ids,allowPending:allowPending)
        }
        return try await N2SyntheticTrialIOSVault.shared.exportVerifiedIndicatorWorkbook(start:start,end:end,subdivision:subdivision,ids:ids,allowPending:allowPending)
    }
    func exportOccupationalVigilance(start:String,end:String) async throws
        ->N2OccupationalVigilanceWorkbook.Result {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared
                .exportOccupationalVigilance(start:start,end:end)
        }
        return try await N2SyntheticTrialIOSVault.shared
            .exportOccupationalVigilance(start:start,end:end)
    }

    func exportVerifiedDailyNursingWorkbook(date:String,shift:String,responsible:String,site:String="") async throws -> N2VerifiedNursingWorkbook.Result {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.exportVerifiedDailyNursingWorkbook(date:date,shift:shift,responsible:responsible,site:site)
        }
        return try await N2SyntheticTrialIOSVault.shared.exportVerifiedDailyNursingWorkbook(date:date,shift:shift,responsible:responsible,site:site)
    }
    func exportVerifiedRangeNursingWorkbook(start:String,end:String,responsible:String,site:String="",reconstructFromCount:Bool=false) async throws -> N2VerifiedNursingWorkbook.Result {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.exportVerifiedRangeNursingWorkbook(start:start,end:end,responsible:responsible,site:site,reconstructFromCount:reconstructFromCount)
        }
        return try await N2SyntheticTrialIOSVault.shared.exportVerifiedRangeNursingWorkbook(start:start,end:end,responsible:responsible,site:site,reconstructFromCount:reconstructFromCount)
    }
    func exportPortableEncryptedBackup(password:String) async throws -> Data {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.exportPortableEncryptedBackup(password:password)
        }
        return try await N2SyntheticTrialIOSVault.shared.exportPortableEncryptedBackup(password:password)
    }
}

private struct N2WorkspaceVaultEnvironmentKey:EnvironmentKey {
    static let defaultValue=N2WorkspaceVault.demo
}
extension EnvironmentValues {
    var n2WorkspaceVault:N2WorkspaceVault {
        get {self[N2WorkspaceVaultEnvironmentKey.self]}
        set {self[N2WorkspaceVaultEnvironmentKey.self]=newValue}
    }
}

extension N2WorkspaceVault {
    func simpleInventoryContext() async throws->N2SimpleInventoryContext {
        if isClinical {return try await N2ProtectedClinicalIOSVault.shared.simpleInventoryContext()}
        return try await N2SyntheticTrialIOSVault.shared.simpleInventoryContext()
    }
    func inspectSimpleBackup(_ archive:Data,password:String) async throws->N2SimpleBackupReview {
        if isClinical {return try await N2ProtectedClinicalIOSVault.shared.inspectSimpleBackup(archive,password:password)}
        return try await N2SyntheticTrialIOSVault.shared.inspectSimpleBackup(archive,password:password)
    }
    func activateSimpleInventory(archive:Data,password:String,request:N2SimpleActivation,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.activateSimpleInventory(archive:archive,password:password,request:request,expectedRevision:expectedRevision),kind:"inventory")}
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.activateSimpleInventory(archive:archive,password:password,request:request,expectedRevision:expectedRevision),kind:"inventory")
    }
    func applySimpleInventoryCommand(_ command:N2SimpleInventoryCommand,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.applySimpleInventoryCommand(command,expectedRevision:expectedRevision),kind:"inventory")}
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.applySimpleInventoryCommand(command,expectedRevision:expectedRevision),kind:"inventory")
    }
    func restoreSimpleClinical(archive:Data,password:String,eventID:String,operatorName:String,at:Int64,confirmed:Bool,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.restoreSimpleClinical(archive:archive,password:password,eventID:eventID,operatorName:operatorName,at:at,confirmed:confirmed,expectedRevision:expectedRevision),kind:"restore")}
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.restoreSimpleClinical(archive:archive,password:password,eventID:eventID,operatorName:operatorName,at:at,confirmed:confirmed,expectedRevision:expectedRevision),kind:"restore")
    }
    func recoverPortableSource(archive:Data,password:String,confirmed:Bool) async throws->N2ProtectedStoreSummary {
        if isClinical {return verifiedChange(try await N2ProtectedClinicalIOSVault.shared.recoverPortableSource(archive:archive,password:password,confirmed:confirmed),kind:"restore")}
        return verifiedChange(try await N2SyntheticTrialIOSVault.shared.recoverPortableSource(archive:archive,password:password,confirmed:confirmed),kind:"restore")
    }
}

extension N2WorkspaceVault {
    func simpleInventoryCut(code:String,through:String,archive:Data?,password:String?) async throws->N2SimpleCutPreview {
        if isClinical {return try await N2ProtectedClinicalIOSVault.shared.simpleInventoryCut(code:code,through:through,archive:archive,password:password)}
        return try await N2SyntheticTrialIOSVault.shared.simpleInventoryCut(code:code,through:through,archive:archive,password:password)
    }
}
