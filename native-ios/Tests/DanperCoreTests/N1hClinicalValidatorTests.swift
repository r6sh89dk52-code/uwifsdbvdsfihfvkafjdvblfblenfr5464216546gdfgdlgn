import Foundation
import XCTest
@testable import DanperCore

final class N1hClinicalValidatorTests: XCTestCase {
    private struct Sample: Decodable {
        let label: String
        let form: N1hClinicalInput
        let context: N1hClinicalContext
        let expected: [[String]]
        let first: Int?
    }
    private func scenarios() throws -> [Sample] {
        guard let dir = ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"] else {
            throw XCTSkip("Synthetic N1h TypeScript fixture not generated")
        }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("n1h-ts-stage-parity.json")
        return try JSONDecoder().decode([Sample].self, from: Data(contentsOf: url))
    }
    func testEveryTSFixtureHasExactlyIdenticalSwiftFieldFailures() throws {
        let data = try scenarios()
        XCTAssertEqual(data.count,16)
        for sample in data {
            let actual = (0...3).map {
                N1hClinicalValidator.invalidFields(step: $0, form: sample.form, context: sample.context)
            }
            XCTAssertEqual(actual,sample.expected,"Mismatch on scenario \(sample.label)")
            XCTAssertEqual(N1hClinicalValidator.firstInvalidStage(form:sample.form,
                            context:sample.context), sample.first, sample.label)
        }
    }
    func testNamedLeapAndPermissionCasesMatchTS() throws {
        let samples = try scenarios()
        let leap = try XCTUnwrap(samples.first { $0.label == "leapInvalid" })
        XCTAssertEqual(N1hClinicalValidator.invalidFields(step:1,form:leap.form,
              context:leap.context),["clinical-date","clinical-time"])
        let time = try XCTUnwrap(samples.first { $0.label == "permissionTimeBad" })
        XCTAssertEqual(N1hClinicalValidator.invalidFields(step:3,form:time.form,
              context:time.context),["result-permission-time"])
    }
    func testUnknownAllergyReviewIsDistinctFromNotReviewed() throws {
        let samples = try scenarios()
        let unknown = try XCTUnwrap(samples.first { $0.label == "allergyNotReviewed" })
        XCTAssertEqual(N1hClinicalValidator.invalidFields(step:1,form:unknown.form,
              context:unknown.context),["allergy-status"])
        let known = try XCTUnwrap(samples.first { $0.label == "allergyKnownEmpty" })
        XCTAssertEqual(N1hClinicalValidator.invalidFields(step:1,form:known.form,
              context:known.context),["allergy-substances"])
    }
    func testOsteomuscularSegmentAndNumberOfItemFailures() throws {
        let samples = try scenarios()
        let osteo = try XCTUnwrap(samples.first { $0.label == "osteoNoSegment" })
        XCTAssertEqual(N1hClinicalValidator.invalidFields(step:1,form:osteo.form,
              context:osteo.context),["clinical-segment"])
        let items = try XCTUnwrap(samples.first { $0.label == "invalidItems" })
        XCTAssertEqual(N1hClinicalValidator.invalidFields(step:2,form:items.form,
              context:items.context),
              ["treatment-items","treatment-items","treatment-items","treatment-items"])
    }
}
