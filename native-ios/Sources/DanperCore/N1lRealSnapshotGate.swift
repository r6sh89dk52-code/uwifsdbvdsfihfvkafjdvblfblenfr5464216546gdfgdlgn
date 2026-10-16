import Foundation
import Crypto

/// N1l: read-only audit of a complete build222 snapshot.
/// Never exposes a merged collection or performs a write/restore.
/// A checksum proves integrity, NOT real-world provenance.
public enum N1lDestinationState: String, Sendable {
    case verifiedEmpty, containsDemonstration, containsClinicalData, uncertain
}
public enum N1lImportRestriction: String, Equatable, Sendable {
    case notEmpty, destinationNotVerified, fictionalRecords, unresolvedCorrections
    case sourceIdentityNotConfirmed, importerNotEnabled, missingRosterReferences
}
public struct N1lSourceAudit: Sendable {
    public let manifest: N1BackupManifest
    public let saved: Int
    public let drafts: Int
    public let corrections: Int
    public let allergyKnown: Int
    public let allergyNone: Int
    public let allergyUnknown: Int
    public let unknownFutureFieldsPreserved: Bool
    public let semanticSHA256: String
    public let obviousDemoWorkerMarkers: Int
    public let obviousDemoClinicalMarkers: Int
    public let danglingCorrections: Int
    public let missingRosterReferences: Int
    public let unresolvedClinicalConsumptions: Int
    public let destination: N1lDestinationState
    public let restrictions: [N1lImportRestriction]
    /// Preparatory check only: cannot authorize write to disk.
    public let isStructurallyEligibleForReview: Bool
    /// Always false in N1l. The real importer does not exist here.
    public let canCommitToClinicalStorage: Bool
}

public enum N1lAuditError: Error, Equatable {
    case invalidSnapshot, duplicateLot, incompleteLot, invalidCorrectionChain
    case unsupportedOrEmpty
}

public enum N1lRealSnapshotGate {
    public static let collections = [
        "workers", "attentions", "allergies", "notifications",
        "stockLots", "stockMovements", "catalogMappings",
        "deliveryIncidents", "ambulatoryReconciliation"
    ]
    /// These exact patterns are N1g/N1f synthetic lab identities.
    /// Real/fake status CANNOT be reliably decided just from strings;
    /// this is a conservative recognizer, not a real-record classifier.
    private static func marked(_ s: String) -> Bool {
        let normalized = s.folding(options:[.caseInsensitive,.diacriticInsensitive],
                                   locale:Locale(identifier:"es_PE")).uppercased()
        return normalized.contains("PERSONA FICTICIA") ||
            normalized.contains("TRABAJADOR FICTICIO") ||
            normalized.contains("PACIENTE FICTICIO") ||
            normalized.contains("REGISTRO DEMO N1")
    }
    private static func anyText(_ x: Any?) -> String? { x as? String }
    /// Provides a transparent preview of the *single* source snapshot.
    /// The target state comes from an independent clinical vault audit;
    /// N1g fake demo workers may NOT serve as the target.
    public static func audit(_ data: Data,
                             destination: N1lDestinationState = .uncertain) throws -> N1lSourceAudit {
        guard data.count <= 30 * 1024 * 1024,
              let root = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              Set(Self.collections).isSubset(of:Set(root.keys)),
              let workers = root["workers"] as? [[String:Any]],
              let visits = root["attentions"] as? [[String:Any]],
              let lots = root["stockLots"] as? [[String:Any]],
              let allergies = root["allergies"] as? [String:Any] else {
            throw N1lAuditError.invalidSnapshot
        }
        let report = try N1fLosslessFieldGate.inspect(data)
        let manifest = try N1BackupAdmission.preview(data:data)
        guard !workers.isEmpty || !visits.isEmpty else {
            // Some historical stock-only backups can be inspected by N1,
            // but cannot yet become an authoritative real worker/visit base.
            throw N1lAuditError.unsupportedOrEmpty
        }

        var lotIDs = Set<String>()
        for l in lots {
            // Never manufacture or delete a lot ID during a one-source audit.
            // Missing/duplicate IDs must be handled with a clinical review.
            guard let key = anyText(l["id"]), !key.isEmpty else {
                throw N1lAuditError.incompleteLot
            }
            guard lotIDs.insert(key).inserted else { throw N1lAuditError.duplicateLot }
        }

        let roster = Set(workers.compactMap { anyText($0["dni"]) })
        let savedByID = Dictionary(uniqueKeysWithValues: visits.compactMap { v -> (String, Bool)? in
            guard let id=anyText(v["id"]) else { return nil }
            return (id, anyText(v["status"]) == "saved")
        })
        let markedWorkers = workers.filter { marked(anyText($0["name"]) ?? "") }.count
        let markedClinical = visits.filter { visit in
            guard let worker = visit["worker"] as? [String:Any] else { return false }
            return marked(anyText(worker["name"]) ?? "")
        }.count

        var dangling = 0, missingRoster = 0
        for visit in visits {
            if let origin = anyText(visit["originId"]), savedByID[origin] != true {
                dangling += 1
            }
            // Incomplete drafts can legitimately have no worker yet.
            if anyText(visit["status"]) == "saved",
               let worker = visit["worker"] as? [String:Any],
               let dni = anyText(worker["dni"]), !roster.contains(dni) {
                missingRoster += 1
            }
        }
        // Allergies keyed by DNI may legitimately contain statuses for
        // workers whose roster entry has not yet been synced; keep and flag
        // but NEVER silently trim those records in the planned import.
        _ = allergies

        var restrictions:[N1lImportRestriction] = [.sourceIdentityNotConfirmed,.importerNotEnabled]
        switch destination {
        case .verifiedEmpty: break
        case .containsDemonstration,.containsClinicalData:
            restrictions.append(.notEmpty)
        case .uncertain:
            restrictions.append(.destinationNotVerified)
        }
        if markedWorkers > 0 || markedClinical > 0 { restrictions.append(.fictionalRecords) }
        if dangling > 0 { restrictions.append(.unresolvedCorrections) }
        if missingRoster > 0 { restrictions.append(.missingRosterReferences) }
        let structurallyEligible = destination == .verifiedEmpty &&
            markedWorkers == 0 && markedClinical == 0 &&
            dangling == 0 && missingRoster == 0
        return N1lSourceAudit(
            manifest:manifest, saved:report.saved, drafts:report.drafts,
            corrections:report.corrections, allergyKnown:report.allergyKnown,
            allergyNone:report.allergyNone, allergyUnknown:report.allergyUnknown,
            unknownFutureFieldsPreserved:true,
            semanticSHA256:report.semanticSHA256,
            obviousDemoWorkerMarkers:markedWorkers,
            obviousDemoClinicalMarkers:markedClinical,
            danglingCorrections:dangling,
            missingRosterReferences:missingRoster,
            unresolvedClinicalConsumptions:manifest.unresolvedClinicalItems,
            destination:destination,
            restrictions:restrictions,
            isStructurallyEligibleForReview:structurallyEligible,
            canCommitToClinicalStorage:false
        )
    }
    /// Reject all merge requests: the ONLY future operation permitted is a
    /// verified single-source replacement into an independent *empty* vault.
    /// No imported records, products, histories or prescriptions are appended.
    public static func requireEmptyReplacement(destination:N1lDestinationState) throws {
        guard destination == .verifiedEmpty else { throw N1lAuditError.invalidSnapshot }
    }
}
