import Foundation

/// Audit of a legacy backup before a future real restore.
/// Only validates and summarizes. It never exposes or writes patient records.
public struct N1BackupManifest: Equatable, Sendable {
    public let workers: Int
    public let attentions: Int
    public let allergies: Int
    public let lots: Int
    public let movements: Int
    public let catalogMappings: Int
    public let deliveryIncidents: Int
    public let ambulatoryReconciliation: Int
    public let unresolvedClinicalItems: Int
    public let notificationsEnabled: Bool
}

public enum N1BackupManifestError: Error, Equatable {
    case incompatibleCollections
    case unsupportedOrEmptyBackup
}

public enum N1BackupAdmission {
    /// Validates all nine fields exported by secureDemoStore's DemoSnapshot.
    /// A valid manifest is NOT an authorization to import or overwrite a device.
    public static func preview(data: Data) throws -> N1BackupManifest {
        let summary = try LegacySnapshotReader.inspect(data)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mappings = root["catalogMappings"] as? [Any], mappings.count <= 500,
              let incidents = root["deliveryIncidents"] as? [Any], incidents.count <= 500,
              let reconciliation = root["ambulatoryReconciliation"] as? [Any],
              reconciliation.count <= 1_200,
              let notifications = root["notifications"] as? Bool
        else { throw N1BackupManifestError.incompatibleCollections }
        guard summary.workers > 0 || summary.attentions > 0 ||
              summary.stockLots > 0 || summary.stockMovements > 0 ||
              summary.allergies > 0 || !mappings.isEmpty || !incidents.isEmpty ||
              !reconciliation.isEmpty else {
            throw N1BackupManifestError.unsupportedOrEmptyBackup
        }
        return N1BackupManifest(
            workers: summary.workers, attentions: summary.attentions,
            allergies: summary.allergies, lots: summary.stockLots,
            movements: summary.stockMovements, catalogMappings: mappings.count,
            deliveryIncidents: incidents.count,
            ambulatoryReconciliation: reconciliation.count,
            unresolvedClinicalItems: summary.unmappedAttentionConsumptions,
            notificationsEnabled: notifications
        )
    }
}
