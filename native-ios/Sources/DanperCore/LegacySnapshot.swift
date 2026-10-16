import Foundation

/// Validates the *structure* of a legacy clinical backup without mutating it.
/// Sensitive patient records are never sent to GitHub or any server.
public struct SnapshotSummary: Equatable, Sendable {
    public let workers: Int
    public let attentions: Int
    public let stockLots: Int
    public let stockMovements: Int
    public let allergies: Int
    public let unmappedAttentionConsumptions: Int

    public init(workers: Int, attentions: Int, stockLots: Int, stockMovements: Int,
                allergies: Int, unmappedAttentionConsumptions: Int) {
        self.workers = workers
        self.attentions = attentions
        self.stockLots = stockLots
        self.stockMovements = stockMovements
        self.allergies = allergies
        self.unmappedAttentionConsumptions = unmappedAttentionConsumptions
    }
}

public enum LegacySnapshotError: Error, Equatable {
    case invalidStructure
    case invalidCollections
    case duplicateAttention
    case duplicateMovement
    case invalidClinicalItem
    case unverifiedLink
}

public enum LegacySnapshotReader {
    /// Mirrors the v0.21.12 encrypted snapshot's top-level collection names.
    /// This is intentionally read-only: no merge, rewrite, or data migration.
    public static func inspect(_ data: Data) throws -> SnapshotSummary {
        guard data.count <= 30 * 1024 * 1024,
              let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { throw LegacySnapshotError.invalidStructure }
        return try inspectDictionary(raw)
    }

    public static func inspectDictionary(_ raw: [String: Any]) throws -> SnapshotSummary {
        guard let workers = raw["workers"] as? [[String: Any]],
              let attentions = raw["attentions"] as? [[String: Any]],
              let lots = raw["stockLots"] as? [[String: Any]],
              let movements = raw["stockMovements"] as? [[String: Any]],
              let allergies = raw["allergies"] as? [String: Any],
              workers.count <= 30_000, attentions.count <= 100_000,
              lots.count <= 500, movements.count <= 1_000
        else { throw LegacySnapshotError.invalidCollections }

        var attentionIDs = Set<String>()
        var consumedKeys = Set<String>()
        var clinicalItems = 0
        for attention in attentions {
            guard let id = attention["id"] as? String, !id.isEmpty,
                  attentionIDs.insert(id).inserted
            else { throw LegacySnapshotError.duplicateAttention }
            guard let items = attention["items"] as? [[String: Any]] else {
                throw LegacySnapshotError.invalidClinicalItem
            }
            var itemIDs = Set<String>()
            for item in items {
                guard let itemID = item["id"] as? String, !itemID.isEmpty,
                      itemIDs.insert(itemID).inserted,
                      let qty = item["quantity"] as? NSNumber,
                      qty.doubleValue > 0, qty.doubleValue.isFinite
                else { throw LegacySnapshotError.invalidClinicalItem }
                if (attention["status"] as? String) == "saved" {
                    clinicalItems += 1
                    consumedKeys.insert(id + "\u{001F}" + itemID)
                }
            }
        }
        var physicalLinked = Set<String>()
        var movementIDs = Set<String>()
        for movement in movements {
            guard let id = movement["id"] as? String, !id.isEmpty,
                  movementIDs.insert(id).inserted else {
                throw LegacySnapshotError.duplicateMovement
            }
            if let ref = movement["dispenseRef"] as? [String: Any] {
                guard let attentionID = ref["attentionId"] as? String,
                      let itemID = ref["itemId"] as? String,
                      consumedKeys.contains(attentionID + "\u{001F}" + itemID)
                else { throw LegacySnapshotError.unverifiedLink }
                physicalLinked.insert(attentionID + "\u{001F}" + itemID)
            }
        }
        return SnapshotSummary(workers: workers.count, attentions: attentions.count,
                               stockLots: lots.count, stockMovements: movements.count,
                               allergies: allergies.count,
                               unmappedAttentionConsumptions: clinicalItems - physicalLinked.count)
    }
}
