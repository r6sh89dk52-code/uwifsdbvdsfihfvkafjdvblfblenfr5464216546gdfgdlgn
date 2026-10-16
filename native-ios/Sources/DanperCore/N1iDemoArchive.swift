import Foundation

/// N1i demo-only archive. No real identity, clinical free-text or backups
/// are accepted, even if the caller provides authentic encrypted bytes.
/// Strictly fixed fictitious roster + choice catalog, maximum 50 demo visits.
public struct N1iDemoArchive: Codable, Equatable, Sendable {
    public let version: Int
    public let workers: [N1gWorker]
    public let visits: [N1gVisit]
    public let allergies: [String:N1gAllergy]
    public let activeDraftID: UUID?
    public init(workers: [N1gWorker], visits: [N1gVisit],
                allergies: [String:N1gAllergy], activeDraftID: UUID?) {
        self.version = 1
        self.workers = workers
        self.visits = visits
        self.allergies = allergies
        self.activeDraftID = activeDraftID
    }
}
public enum N1iDemoArchiveFailure: Error, Equatable {
    case unsupported, outsideFictionalCatalog, conflictingHistory, oversized
}

public enum N1iDemoArchiveCodec {
    public static let marker = "DANPER-N1I-DEMO-ONLY|"
    public static let maxBytes = 65536

    public static func encode(_ clinic: N1gClinic) throws -> Data {
        let payload = N1iDemoArchive(workers: clinic.workers, visits: clinic.visits,
                     allergies: clinic.allergies, activeDraftID: clinic.activeDraftID)
        try validate(payload)
        let encoded = try JSONEncoder().encode(payload)
        guard encoded.count + marker.utf8.count <= maxBytes else { throw N1iDemoArchiveFailure.oversized }
        return Data(marker.utf8) + encoded
    }
    public static func decode(_ data: Data) throws -> N1gClinic {
        let prefix = Data(marker.utf8)
        guard data.starts(with: prefix) else { throw N1iDemoArchiveFailure.unsupported }
        guard data.count <= maxBytes else { throw N1iDemoArchiveFailure.oversized }
        let value: N1iDemoArchive
        do { value = try JSONDecoder().decode(N1iDemoArchive.self, from: data.dropFirst(prefix.count)) }
        catch { throw N1iDemoArchiveFailure.unsupported }
        try validate(value)
        return try N1gClinic(restoringFictional: value)
    }
    public static func validate(_ archive: N1iDemoArchive) throws {
        guard archive.version == 1, (2...6).contains(archive.workers.count),
              archive.visits.count <= 50, archive.allergies.count <= 6 else {
            throw N1iDemoArchiveFailure.unsupported
        }
        var expected = N1gClinic()
        while expected.workers.count < archive.workers.count {
            _ = try expected.addFictionalWorker()
        }
        guard expected.workers == archive.workers else {
            throw N1iDemoArchiveFailure.outsideFictionalCatalog
        }
        let allowedWorkers = Set(archive.workers.map(\.id))
        guard archive.allergies.keys.allSatisfy({ allowedWorkers.contains($0) }) else {
            throw N1iDemoArchiveFailure.outsideFictionalCatalog
        }
        var visitIDs = Set<UUID>(), confirmed = Set<UUID>()
        for visit in archive.visits {
            guard visitIDs.insert(visit.id).inserted,
                  visit.updatedAt >= 0, visit.quantity >= 1, visit.quantity <= 20,
                  N1gClinic.categories.contains(visit.category) || visit.category.isEmpty,
                  N1gClinic.diagnoses.contains(visit.diagnosis) || visit.diagnosis.isEmpty,
                  N1gClinic.procedures.contains(visit.procedure) || visit.procedure.isEmpty,
                  N1gClinic.products.contains(visit.product),
                  N1gClinic.results.contains(visit.result),
                  visit.workerID == nil || allowedWorkers.contains(visit.workerID!),
                  N1gClinic.allowedDates.contains(visit.detailed.date),
                  N1gClinic.allowedTimes.contains(visit.detailed.time),
                  N1gClinic.systems.contains(visit.detailed.system) || visit.detailed.system.isEmpty,
                  N1gClinic.segments.contains(visit.detailed.segment),
                  ["NO","SI"].contains(visit.detailed.permission),
                  visit.detailed.permissionTime.isEmpty ||
                     N1gClinic.allowedTimes.contains(visit.detailed.permissionTime),
                  (!visit.detailed.returned || visit.detailed.blueBandage),
                  Set(visit.detailed.standaloneProcedures).count == visit.detailed.standaloneProcedures.count,
                  visit.detailed.standaloneProcedures.allSatisfy({
                    N1gClinic.standaloneDemoProcedures.contains($0)
                  }) else {
                throw N1iDemoArchiveFailure.outsideFictionalCatalog
            }
            let expectedResult = visit.detailed.permission == "SI" ?
                N1gClinic.results[1] : N1gClinic.results[0]
            guard visit.result == expectedResult else {
                throw N1iDemoArchiveFailure.conflictingHistory
            }
            if visit.status == .saved {
                guard visit.originID == nil, visit.workerID != nil,
                      !visit.category.isEmpty, !visit.diagnosis.isEmpty,
                      !visit.procedure.isEmpty else {
                    throw N1iDemoArchiveFailure.conflictingHistory
                }
                confirmed.insert(visit.id)
            } else if let original = visit.originID, original == visit.id {
                throw N1iDemoArchiveFailure.conflictingHistory
            }
        }
        for v in archive.visits where v.status == .draft && v.originID != nil {
            guard confirmed.contains(v.originID!) else {
                throw N1iDemoArchiveFailure.conflictingHistory
            }
        }
        if let activeID = archive.activeDraftID {
            guard archive.visits.contains(where: { $0.id == activeID && $0.status == .draft }) else {
                throw N1iDemoArchiveFailure.conflictingHistory
            }
        }
    }
}

extension N1gClinic {
    /// Unsafe (but fictional) value reconstruction is confined to this
    /// extension and always preceded by N1iDemoArchiveCodec.validate.
    public init(restoringFictional archive: N1iDemoArchive) throws {
        try N1iDemoArchiveCodec.validate(archive)
        self.init()
        while workers.count < archive.workers.count { _ = try addFictionalWorker() }
        visits = archive.visits
        allergies = archive.allergies
        activeDraftID = archive.activeDraftID
    }
    public func exportFictionalDrafts() throws -> Data {
        try N1iDemoArchiveCodec.encode(self)
    }
    public static func importFictionalDrafts(_ data: Data) throws -> N1gClinic {
        try N1iDemoArchiveCodec.decode(data)
    }
}
