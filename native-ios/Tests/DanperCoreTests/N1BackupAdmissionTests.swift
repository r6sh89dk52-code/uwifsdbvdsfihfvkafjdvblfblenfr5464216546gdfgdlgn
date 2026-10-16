import Foundation
import XCTest
@testable import DanperCore

final class N1BackupAdmissionTests: XCTestCase {
    private func snapshot(_ extra: String = "") -> Data {
        let json = """
        {"workers":[{"dni":"00000001"}],
         "attentions":[{"id":"A1","status":"saved","items":[{"id":"I1","quantity":1}]}],
         "allergies":{},"stockLots":[],"stockMovements":[],
         "catalogMappings":[],"deliveryIncidents":[],"ambulatoryReconciliation":[],
         "notifications":false\(extra)}
        """
        return Data(json.utf8)
    }

    func testPreviewIsCompleteAndDistinguishesUnverifiedConsumption() throws {
        let result = try N1BackupAdmission.preview(data: snapshot())
        XCTAssertEqual(result.workers, 1)
        XCTAssertEqual(result.attentions, 1)
        XCTAssertEqual(result.unresolvedClinicalItems, 1)
        XCTAssertEqual(result.movements, 0)
        XCTAssertEqual(result.catalogMappings, 0)
        XCTAssertFalse(result.notificationsEnabled)
    }

    func testIncompleteSnapshotCannotBeDeclaredReady() {
        let missing = Data("""
          {"workers":[],"attentions":[],"allergies":{},
           "stockLots":[],"stockMovements":[]}
        """.utf8)
        XCTAssertThrowsError(try N1BackupAdmission.preview(data: missing))
    }

    func testEmptySnapshotIsRejectedForMigrationReadiness() {
        let empty = Data("""
          {"workers":[],"attentions":[],"allergies":{},"stockLots":[],
           "stockMovements":[],"catalogMappings":[],"deliveryIncidents":[],
           "ambulatoryReconciliation":[],"notifications":false}
        """.utf8)
        XCTAssertThrowsError(try N1BackupAdmission.preview(data: empty))
    }

    func testDamagedClinicalMovementLinkIsRejected() {
        let raw = """
        {"workers":[{"dni":"00000001"}],
         "attentions":[{"id":"A1","status":"saved","items":[{"id":"I1","quantity":1}]}],
         "allergies":{},"stockLots":[],
         "stockMovements":[{"id":"M1","dispenseRef":{"attentionId":"MISSING","itemId":"I1"}}],
         "catalogMappings":[],"deliveryIncidents":[],"ambulatoryReconciliation":[],
         "notifications":false}
        """
        XCTAssertThrowsError(try N1BackupAdmission.preview(data: Data(raw.utf8)))
    }

    func testDuplicateAttentionRejected() {
        let raw = """
        {"workers":[{"dni":"00000001"}],
         "attentions":[{"id":"D","status":"saved","items":[]},
                       {"id":"D","status":"saved","items":[]}],
         "allergies":{},"stockLots":[],"stockMovements":[],
         "catalogMappings":[],"deliveryIncidents":[],"ambulatoryReconciliation":[],
         "notifications":false}
        """
        XCTAssertThrowsError(try N1BackupAdmission.preview(data: Data(raw.utf8)))
    }
}
