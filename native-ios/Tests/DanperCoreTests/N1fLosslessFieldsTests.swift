import Foundation
import XCTest
@testable import DanperCore

final class N1fLosslessFieldsTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        guard let dir = ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"],
              !dir.isEmpty else { throw XCTSkip("N1f synthetic fixture missing") }
        return try Data(contentsOf: URL(fileURLWithPath:dir).appendingPathComponent(name))
    }
    private struct Expected: Decodable {
        let sourceSHA256: String
        let semanticSHA256: String
        let nodes: Int
        let workers: Int
        let visits: Int
        let saved: Int
        let drafts: Int
        let corrections: Int
        let known: Int
        let none: Int
        let unknown: Int
        let incomplete: Int
    }
    func testAllFieldsMatchTypeScriptTreeIncludingUnknownExtensions() throws {
        let expected = try JSONDecoder().decode(Expected.self, from: fixture("n1f-expected.json"))
        let src = try fixture("n1f-source.json")
        let report = try N1fLosslessFieldGate.inspect(src)
        XCTAssertEqual(report.sourceSHA256, expected.sourceSHA256)
        XCTAssertEqual(report.semanticSHA256, expected.semanticSHA256)
        XCTAssertEqual(report.treeNodes, expected.nodes)
        XCTAssertEqual(report.workers, 2)
        XCTAssertEqual(report.attentions, 3)
        XCTAssertEqual(report.saved, 1)
        XCTAssertEqual(report.drafts, 2)
        XCTAssertEqual(report.corrections, 1)
        XCTAssertEqual(report.allergyKnown, 2)
        XCTAssertEqual(report.allergyNone, 1)
        XCTAssertEqual(report.allergyUnknown, 1)
        XCTAssertEqual(report.incompleteKnownAllergies, 1)
        XCTAssertTrue(report.notifications)
        try N1fLosslessFieldGate.verifyUnchanged(original: src, candidate: src)
    }
    func testObjectKeyOrderIsSemanticallyIrrelevant() throws {
        let first = try fixture("n1f-source.json")
        let second = try fixture("n1f-reordered.json")
        XCTAssertNotEqual(first, second)
        try N1fLosslessFieldGate.verifyUnchanged(original: first, candidate: second)
    }
    func testMissingFutureFieldsDetected() throws { try detect("n1f-lost-extension.json") }
    func testMissingNullDistinctFromAbsent() throws { try detect("n1f-lost-null.json") }
    func testUnknownAllergyNeverBecomesExplicitlyNone() throws { try detect("n1f-changed-allergy.json") }
    func testDraftsCannotDisappear() throws { try detect("n1f-lost-draft.json") }
    func testPhotoSentFlagCannotChange() throws { try detect("n1f-changed-photo.json") }
    func testDuplicateWorkerRejected() throws {
        XCTAssertThrowsError(try N1fLosslessFieldGate.inspect(fixture("n1f-duplicate-worker.json")))
    }
    func testInvalidAllergyStatusRejected() throws {
        XCTAssertThrowsError(try N1fLosslessFieldGate.inspect(fixture("n1f-invalid-allergy.json")))
    }
    func testDuplicateAttentionRejected() throws {
        XCTAssertThrowsError(try N1fLosslessFieldGate.inspect(fixture("n1f-duplicate-attention.json")))
    }
    private func detect(_ name: String) throws {
        let src = try fixture("n1f-source.json")
        XCTAssertThrowsError(try N1fLosslessFieldGate.verifyUnchanged(
            original: src, candidate: fixture(name))) { e in
                XCTAssertEqual(e as? N1fFieldError, .semanticDataLoss)
        }
    }
}
