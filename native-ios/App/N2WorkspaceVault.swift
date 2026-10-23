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

    func inspect() async throws -> N2ProtectedStoreSummary? {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.inspect()
        }
        return try await N2SyntheticTrialIOSVault.shared.inspect()
    }
    func readDrafts() async throws -> [N2RecoverableDraft] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readDrafts()
        }
        return try await N2SyntheticTrialIOSVault.shared.readDrafts()
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
    func readHistory() async throws -> N2NativeReadModel? {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readHistory()
        }
        return try await N2SyntheticTrialIOSVault.shared.readHistory()
    }
    func registerWorker(_ worker:Data,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.registerWorker(worker,at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.registerWorker(worker,at:at,expectedRevision:expectedRevision)
    }
    func correctWorker(dni:String,worker:Data,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.correctWorker(dni:dni,worker:worker,at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.correctWorker(dni:dni,worker:worker,at:at,expectedRevision:expectedRevision)
    }
    func reviewAllergies(dni:String,status:String,substances:String,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.reviewAllergies(dni:dni,status:status,substances:substances,at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.reviewAllergies(dni:dni,status:status,substances:substances,at:at,expectedRevision:expectedRevision)
    }
    func saveDraft(id:String,changes:Data,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.saveDraft(id:id,changes:changes,at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.saveDraft(id:id,changes:changes,at:at,expectedRevision:expectedRevision)
    }
    func deleteDraft(id:String,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.deleteDraft(id:id,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.deleteDraft(id:id,expectedRevision:expectedRevision)
    }
    func confirmPendingDispensing(_ evidence:N2PendingDispensingEvidence,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return try await N2ProtectedClinicalIOSVault.shared.confirmPendingDispensing(evidence,expectedRevision:expectedRevision)}
        return try await N2SyntheticTrialIOSVault.shared.confirmPendingDispensing(evidence,expectedRevision:expectedRevision)
    }
    func auxiliaryAccounting() async throws->String {
        if isClinical {return try await N2ProtectedClinicalIOSVault.shared.auxiliaryAccounting()}
        return try await N2SyntheticTrialIOSVault.shared.auxiliaryAccounting()
    }
    func registerAuxiliaryLot(clinicalCode:String,lot:Data,operatorName:String,evidence:String,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return try await N2ProtectedClinicalIOSVault.shared.registerAuxiliaryLot(clinicalCode:clinicalCode,lot:lot,operatorName:operatorName,evidence:evidence,expectedRevision:expectedRevision)}
        return try await N2SyntheticTrialIOSVault.shared.registerAuxiliaryLot(clinicalCode:clinicalCode,lot:lot,operatorName:operatorName,evidence:evidence,expectedRevision:expectedRevision)
    }
    func retryDispensing(visitID:String,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {return try await N2ProtectedClinicalIOSVault.shared.retryDispensing(visitID:visitID,expectedRevision:expectedRevision)}
        return try await N2SyntheticTrialIOSVault.shared.retryDispensing(visitID:visitID,expectedRevision:expectedRevision)
    }
    func confirmOperationalMapping(_ rule:N2OperationalMapping,expectedRevision:Int) async throws->N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.confirmOperationalMapping(rule,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.confirmOperationalMapping(rule,expectedRevision:expectedRevision)
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
            return try await N2ProtectedClinicalIOSVault.shared.savePendingClinicalCorrection(visitID:visitID,changes:changes,reason:reason,operatorName:operatorName,medicationDiscrepancy:medicationDiscrepancy,expectedEffectiveSHA:expectedEffectiveSHA,at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.savePendingClinicalCorrection(visitID:visitID,changes:changes,reason:reason,operatorName:operatorName,medicationDiscrepancy:medicationDiscrepancy,expectedEffectiveSHA:expectedEffectiveSHA,at:at,expectedRevision:expectedRevision)
    }
    func deletePendingClinicalCorrection(visitID:String,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.deletePendingClinicalCorrection(visitID:visitID,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.deletePendingClinicalCorrection(visitID:visitID,expectedRevision:expectedRevision)
    }
    func readCorrectionHistory(visitID:String) async throws -> [N2CorrectionHistoryEntry] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readCorrectionHistory(visitID:visitID)
        }
        return try await N2SyntheticTrialIOSVault.shared.readCorrectionHistory(visitID:visitID)
    }
    func readCorrectionDetail(visitID:String) async throws -> N2CorrectionDetail {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.readCorrectionDetail(visitID:visitID)
        }
        return try await N2SyntheticTrialIOSVault.shared.readCorrectionDetail(visitID:visitID)
    }
    func saveClinicalCorrection(visitID:String,eventID:String,changes:Data,reason:String,operatorName:String,medicationDiscrepancy:String,expectedEffectiveSHA:String,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.saveClinicalCorrection(visitID:visitID,eventID:eventID,changes:changes,reason:reason,operatorName:operatorName,medicationDiscrepancy:medicationDiscrepancy,expectedEffectiveSHA:expectedEffectiveSHA,at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.saveClinicalCorrection(visitID:visitID,eventID:eventID,changes:changes,reason:reason,operatorName:operatorName,medicationDiscrepancy:medicationDiscrepancy,expectedEffectiveSHA:expectedEffectiveSHA,at:at,expectedRevision:expectedRevision)
    }
    func saveAttention(_ attention:Data,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.saveAttention(attention,at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.saveAttention(attention,at:at,expectedRevision:expectedRevision)
    }
    func previewAttention(_ attention:Data,visitID:String,at:Int64,expectedRevision:Int) async throws -> [String:String] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.previewAttention(attention,visitID:visitID,at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.previewAttention(attention,visitID:visitID,at:at,expectedRevision:expectedRevision)
    }
    func verifyOriginalStockSite(eventID:String,lotID:String,site:String,reason:String,at:Int64,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.verifyOriginalStockSite(eventID:eventID,lotID:lotID,site:site,reason:reason,operatorName:"Felipe Azcárate Silva",at:at,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.verifyOriginalStockSite(eventID:eventID,lotID:lotID,site:site,reason:reason,at:at,expectedRevision:expectedRevision)
    }
    func addLot(_ lot:Data,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.addLot(lot,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.addLot(lot,expectedRevision:expectedRevision)
    }
    func receiveStock(movementID:String,lotID:String,at:Int64,sealedAdded:Int,looseAdded:Double,reason:String,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.receiveStock(movementID:movementID,lotID:lotID,at:at,sealedAdded:sealedAdded,looseAdded:looseAdded,reason:reason,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.receiveStock(movementID:movementID,lotID:lotID,at:at,sealedAdded:sealedAdded,looseAdded:looseAdded,reason:reason,expectedRevision:expectedRevision)
    }
    func reconcileCount(movementID:String,lotID:String,at:Int64,sealed:Int,loose:Double,opened:Double,reason:String,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.reconcileCount(movementID:movementID,lotID:lotID,at:at,sealed:sealed,loose:loose,opened:opened,reason:reason,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.reconcileCount(movementID:movementID,lotID:lotID,at:at,sealed:sealed,loose:loose,opened:opened,reason:reason,expectedRevision:expectedRevision)
    }
    func reconciliationEvents() async throws -> [N2ReconciliationEventRow] {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.reconciliationEvents()
        }
        return try await N2SyntheticTrialIOSVault.shared.reconciliationEvents()
    }
    func appendReconciliationEvent(_ event:Data,expectedRevision:Int) async throws -> N2ProtectedStoreSummary {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.appendReconciliationEvent(event,expectedRevision:expectedRevision)
        }
        return try await N2SyntheticTrialIOSVault.shared.appendReconciliationEvent(event,expectedRevision:expectedRevision)
    }
    func exportVerifiedIndicatorWorkbook(start:String,end:String,subdivision:String,ids:Set<String>,allowPending:Bool=false) async throws -> N2VerifiedIndicatorWorkbook.Result {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.exportVerifiedIndicatorWorkbook(start:start,end:end,subdivision:subdivision,ids:ids,allowPending:allowPending)
        }
        return try await N2SyntheticTrialIOSVault.shared.exportVerifiedIndicatorWorkbook(start:start,end:end,subdivision:subdivision,ids:ids,allowPending:allowPending)
    }
    func exportVerifiedDailyNursingWorkbook(date:String,shift:String,responsible:String,site:String="") async throws -> N2VerifiedNursingWorkbook.Result {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.exportVerifiedDailyNursingWorkbook(date:date,shift:shift,responsible:responsible,site:site)
        }
        return try await N2SyntheticTrialIOSVault.shared.exportVerifiedDailyNursingWorkbook(date:date,shift:shift,responsible:responsible,site:site)
    }
    func exportVerifiedRangeNursingWorkbook(start:String,end:String,responsible:String,site:String="") async throws -> N2VerifiedNursingWorkbook.Result {
        if isClinical {
            return try await N2ProtectedClinicalIOSVault.shared.exportVerifiedRangeNursingWorkbook(start:start,end:end,responsible:responsible,site:site)
        }
        return try await N2SyntheticTrialIOSVault.shared.exportVerifiedRangeNursingWorkbook(start:start,end:end,responsible:responsible,site:site)
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
