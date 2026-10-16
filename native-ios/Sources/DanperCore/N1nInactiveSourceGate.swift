import Foundation

/// Explicit consent enables INACTIVE encryption only, not a clinical import.
/// Human declarations cannot prove a backup contains exclusively real records.
public struct N1nAcknowledgment: Equatable, Sendable {
    public let originalBuild222: Bool
    public let reviewedForDemo: Bool
    public let understandsNoRestore: Bool

    public init(originalBuild222:Bool, reviewedForDemo:Bool, understandsNoRestore:Bool) {
        self.originalBuild222=originalBuild222
        self.reviewedForDemo=reviewedForDemo
        self.understandsNoRestore=understandsNoRestore
    }
}
public enum N1nGateError: Error, Equatable {
    case missingAcknowledgment, ineligibleSource
}
public struct N1nDecision: Equatable, Sendable {
    public let semanticSHA256:String
    public let workers:Int
    public let visits:Int
    public let drafts:Int
    public let unresolvedConsumptions:Int
    public let provenAuthentic:Bool
    public let canActivate:Bool
}
public enum N1nInactiveSourceGate {
    public static func authorize(_ raw:Data, acknowledgment:N1nAcknowledgment)
        throws -> N1nDecision {
        guard acknowledgment.originalBuild222 && acknowledgment.reviewedForDemo &&
              acknowledgment.understandsNoRestore else {
            throw N1nGateError.missingAcknowledgment
        }
        let report=try N1lRealSnapshotGate.audit(raw,destination:.verifiedEmpty)
        guard report.isStructurallyEligibleForReview,
              report.obviousDemoWorkerMarkers == 0,
              report.obviousDemoClinicalMarkers == 0,
              report.danglingCorrections == 0,
              report.missingRosterReferences == 0 else {
            throw N1nGateError.ineligibleSource
        }
        return N1nDecision(semanticSHA256:report.semanticSHA256,
              workers:report.manifest.workers,visits:report.manifest.attentions,
              drafts:report.drafts,
              unresolvedConsumptions:report.unresolvedClinicalConsumptions,
              provenAuthentic:false,canActivate:false)
    }
}
