import Foundation
import XCTest
@testable import DanperCore

final class N1eClinicalParityTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        guard let dir = ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"],
              !dir.isEmpty else { throw XCTSkip("Require synthetic TypeScript fixtures.") }
        return try Data(contentsOf: URL(fileURLWithPath:dir).appendingPathComponent(name))
    }
    private struct Expected: Decodable {
        let sha256: String
        let rows: [Double?]
        let attentions: Int
        let workers: Int
        let movements: Int
        let linked: Int
        let pending: Int
        let splitDeliveries: Int
    }
    func testRealTSLedgerAndClinicalRParitiesWithoutMutation() throws {
        let raw = try fixture("n1e-clinical-stock.json")
        let expected = try JSONDecoder().decode(Expected.self, from:
                                fixture("n1e-clinical-expected.json"))
        let report = try N1eLegacyClinicalAudit.inspect(raw)
        XCTAssertEqual(report.sourceSHA256, expected.sha256)
        XCTAssertEqual(report.workers, expected.workers)
        XCTAssertEqual(report.attentions, expected.attentions)
        XCTAssertEqual(report.linkedClinicalItems, expected.linked)
        XCTAssertEqual(report.pendingClinicalItems, expected.pending)
        XCTAssertEqual(report.physicalMovements, expected.movements)
        XCTAssertEqual(report.splitDeliveries, expected.splitDeliveries)
        XCTAssertEqual(report.savedClinicalItems, 5)
        XCTAssertEqual(report.consumptionR.count, 5)
        XCTAssertEqual(report.consumptionR[0], 5)
        XCTAssertEqual(report.consumptionR[1], 1)
        XCTAssertEqual(report.consumptionR[2], 0, "Confirmed previously opened box is real R=0")
        XCTAssertEqual(report.consumptionR[3], 12)
        XCTAssertNil(report.consumptionR[4], "No verified stock must NOT become R=0")
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(raw), report)
        XCTAssertEqual(raw, try fixture("n1e-clinical-stock.json"), "Read-only validator must not rewrite data")
    }
    func testTruncatedMultilotRejected() throws {
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(fixture("n1e-truncated.json")))
    }
    func testDuplicateWorkerRejected() throws {
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(fixture("n1e-double-worker.json")))
    }
    func testIncorrectOfficialRRejected() throws {
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(fixture("n1e-wrong-R.json")))
    }
    func testInconsistentCurrentLotRejected() throws {
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(fixture("n1e-missing-stock.json")))
    }
    func testClinicalChangesAfterDispensingRejected() throws {
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(fixture("n1e-clinical-tamper.json")))
    }
    func testDuplicatePhysicalMovementRejected() throws {
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(fixture("n1e-dup-movement.json")))
    }
    func testLinkToNonexistentAttentionRejected() throws {
        XCTAssertThrowsError(try N1eLegacyClinicalAudit.inspect(fixture("n1e-bad-link.json")))
    }
}
