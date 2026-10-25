import XCTest
@testable import DanperCloudBridge
actor Journal: EncryptedSyncJournal {
    var operations = [CloudOperation](), acknowledged = [String](), conflicts = [String](), current = 0
    func pending() -> [CloudOperation] { operations }
    func append(_ operation: CloudOperation) { if !operations.contains(where:{$0.id == operation.id}) { operations.append(operation) } }
    func acknowledge(_ id: String) { acknowledged.append(id); operations.removeAll{$0.id == id} }
    func markConflict(_ id: String) { conflicts.append(id) }
    func cursor() -> Int { current }
    func apply(_ page: CloudPage) { current = page.cursor }
}
actor Transport: CloudTransport {
    var receipts = Set<String>(), fail = false
    func commit(_ operation: CloudOperation) throws { if fail { throw CloudFailure.revisionConflict }; receipts.insert(operation.id) }
    func changes(after cursor: Int) -> CloudPage { CloudPage(entities:[],cursor:cursor == 0 ? 1:cursor) }
    func setFail() { fail = true }
}
final class SyncCoordinatorTests: XCTestCase {
    func operation() -> CloudOperation { CloudOperation(id:"OP-FICTICIA",deviceId:"TEST",createdAt:1,changes:[CloudChange(collection:"workers",id:"00000001",expectedRevision:0,data:.object(["dni":.string("00000001")]))]) }
    func testDisabledUntilMigrationAndReconciliation() async throws {
        let c = SyncCoordinator(journal:Journal(),transport:Transport())
        do { try await c.enqueue(operation()); XCTFail("Debe estar desactivado") } catch { XCTAssertEqual(error as? CloudFailure,.disabled) }
        do { try await c.activate(migrationValidated:true,reconciliationValidated:false); XCTFail("Falta conciliación") } catch { XCTAssertEqual(error as? CloudFailure,.migrationNotValidated) }
    }
    func testIdempotentQueueAndIncrementalCursor() async throws {
        let journal = Journal(), transport = Transport(), op = operation()
        let c = SyncCoordinator(journal:journal,transport:transport)
        try await c.activate(migrationValidated:true,reconciliationValidated:true)
        try await c.enqueue(op); try await c.enqueue(op); try await c.synchronize(); try await c.synchronize()
        let receipts = await transport.receipts, cursor = await journal.cursor(), pending = await journal.pending()
        XCTAssertEqual(receipts.count,1); XCTAssertEqual(cursor,1); XCTAssertTrue(pending.isEmpty)
    }
    func testConflictRetainsOperation() async throws {
        let journal = Journal(), transport = Transport()
        let c = SyncCoordinator(journal:journal,transport:transport)
        try await c.activate(migrationValidated:true,reconciliationValidated:true)
        try await c.enqueue(operation()); await transport.setFail()
        do { try await c.synchronize(); XCTFail("Debe detectar conflicto") } catch { XCTAssertEqual(error as? CloudFailure,.revisionConflict) }
        let pending = await journal.pending(), conflicts = await journal.conflicts
        XCTAssertEqual(pending.count,1); XCTAssertEqual(conflicts,["OP-FICTICIA"])
    }
}
