import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([JSONValue]), object([String: JSONValue])
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self), v.isFinite { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}
public struct CloudChange: Codable, Equatable, Sendable {
    public let collection: String
    public let id: String
    public let expectedRevision: Int
    public let data: JSONValue
    public init(collection: String, id: String, expectedRevision: Int, data: JSONValue) {
        self.collection = collection; self.id = id; self.expectedRevision = expectedRevision; self.data = data
    }
}
public struct CloudOperation: Codable, Equatable, Sendable {
    public let id: String
    public let deviceId: String
    public let createdAt: Int64
    public let changes: [CloudChange]
    public let state: String
    public init(id: String = UUID().uuidString, deviceId: String, createdAt: Int64, changes: [CloudChange]) {
        self.id = id; self.deviceId = deviceId; self.createdAt = createdAt; self.changes = changes; self.state = "pending"
    }
}
public struct CloudEntity: Codable, Equatable, Sendable {
    public let key: String
    public let collection: String
    public let id: String
    public let revision: Int
    public let data: JSONValue
    public let operationId: String
    public let sequence: Int
}
public struct CloudPage: Sendable {
    public let entities: [CloudEntity]
    public let cursor: Int
    public init(entities: [CloudEntity], cursor: Int) { self.entities = entities; self.cursor = cursor }
}
public enum CloudFailure: Error, Equatable { case disabled, invalidOperation, revisionConflict, migrationNotValidated }

/// Implement using the existing encrypted journal. The bridge never opens,
/// deletes or rewrites the installed clinical vault by itself.
public protocol EncryptedSyncJournal: Sendable {
    func pending() async throws -> [CloudOperation]
    func append(_ operation: CloudOperation) async throws
    func acknowledge(_ id: String) async throws
    func markConflict(_ id: String) async throws
    func cursor() async throws -> Int
    /// Must apply records and cursor atomically. Dirty local records must be
    /// retained for explicit reconciliation, never overwritten by last-write-wins.
    func apply(_ page: CloudPage) async throws
}
public protocol CloudTransport: Sendable {
    /// Atomic CAS for all revisions, immutable receipt, lots and ledger events.
    func commit(_ operation: CloudOperation) async throws
    func changes(after cursor: Int) async throws -> CloudPage
}
public actor SyncCoordinator {
    private let journal: any EncryptedSyncJournal
    private let transport: any CloudTransport
    private var enabled = false
    private var running = false
    public init(journal: any EncryptedSyncJournal, transport: any CloudTransport) {
        self.journal = journal; self.transport = transport
    }
    public func activate(migrationValidated: Bool, reconciliationValidated: Bool) throws {
        guard migrationValidated && reconciliationValidated else { throw CloudFailure.migrationNotValidated }
        enabled = true
    }
    public func deactivate() { enabled = false }
    public func enqueue(_ operation: CloudOperation) async throws {
        guard enabled else { throw CloudFailure.disabled }
        let collections = Set(["workers","allergies","attentions","clinicalItems","lots","movements","mappings","reconciliations","emo","cholinesterase","leaves","alerts","corrections"])
        guard !operation.changes.isEmpty, operation.changes.count <= 180,
              !operation.id.isEmpty, !operation.id.contains("/"),
              Set(operation.changes.map { $0.collection + ":" + $0.id }).count == operation.changes.count,
              operation.changes.allSatisfy({ collections.contains($0.collection) && !$0.id.isEmpty && !$0.id.contains("/") && $0.expectedRevision >= 0 }) else { throw CloudFailure.invalidOperation }
        try await journal.append(operation)
    }
    public func synchronize() async throws {
        guard enabled else { throw CloudFailure.disabled }
        guard !running else { return }
        running = true; defer { running = false }
        for operation in try await journal.pending() {
            do { try await transport.commit(operation); try await journal.acknowledge(operation.id) }
            catch CloudFailure.revisionConflict {
                try await journal.markConflict(operation.id)
                throw CloudFailure.revisionConflict
            }
        }
        while true {
            let cursor = try await journal.cursor()
            let page = try await transport.changes(after: cursor)
            guard page.cursor >= cursor else { throw CloudFailure.invalidOperation }
            if page.cursor == cursor { return }
            try await journal.apply(page)
        }
    }
}
