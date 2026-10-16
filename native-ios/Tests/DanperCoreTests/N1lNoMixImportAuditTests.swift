import Foundation
import XCTest
@testable import DanperCore

/// ALL fixtures are synthetic and loaded only from RUNNER_TEMP.
final class N1lNoMixImportAuditTests: XCTestCase {
    private func file() throws -> Data {
        guard let dir=ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"] else {
            throw XCTSkip("Synthetic fixture not generated")
        }
        return try Data(contentsOf:URL(fileURLWithPath:dir)
            .appendingPathComponent("n1f-source.json"))
    }
    private func changed(_ edit:(inout [String:Any])->Void) throws -> Data {
        var payload=try XCTUnwrap(
            JSONSerialization.jsonObject(with:file()) as? [String:Any])
        edit(&payload)
        return try JSONSerialization.data(withJSONObject:payload)
    }
    /// Names are synthetic but not the N1g lab identities.
    /// This does NOT prove "real" provenance; manual review stays mandatory.
    private func unmarked() throws -> Data {
        try changed { root in
            var w=root["workers"] as! [[String:Any]]
            w[0]["name"]="IDENTIDAD SINTETICA A"
            w[1]["name"]="IDENTIDAD SINTETICA B"
            root["workers"]=w
            var v=root["attentions"] as! [[String:Any]]
            var old=v[0]["worker"] as! [String:Any]
            old["name"]="IDENTIDAD SINTETICA A"
            v[0]["worker"]=old
            var correction=v[2]["worker"] as! [String:Any]
            correction["name"]="IDENTIDAD SINTETICA A"
            v[2]["worker"]=correction
            root["attentions"]=v
        }
    }
    func testRecognizesPreexistingFictionalSourceAndBlocksIt() throws {
        let s=try N1lRealSnapshotGate.audit(file(),destination:.verifiedEmpty)
        XCTAssertEqual(s.saved,1)
        XCTAssertEqual(s.drafts,2)
        XCTAssertEqual(s.corrections,1)
        XCTAssertEqual(s.allergyKnown,2)
        XCTAssertEqual(s.allergyNone,1)
        XCTAssertEqual(s.allergyUnknown,1)
        XCTAssertEqual(s.obviousDemoWorkerMarkers,2)
        XCTAssertEqual(s.obviousDemoClinicalMarkers,2)
        XCTAssertTrue(s.restrictions.contains(.fictionalRecords))
        XCTAssertFalse(s.isStructurallyEligibleForReview)
        XCTAssertFalse(s.canCommitToClinicalStorage)
    }
    func testUnmarkedSnapshotCanOnlyBeConsideredForManualReviewInEmptyVault() throws {
        let s=try N1lRealSnapshotGate.audit(unmarked(),destination:.verifiedEmpty)
        XCTAssertTrue(s.isStructurallyEligibleForReview)
        XCTAssertFalse(s.canCommitToClinicalStorage)
        XCTAssertTrue(s.restrictions.contains(.sourceIdentityNotConfirmed))
        XCTAssertTrue(s.restrictions.contains(.importerNotEnabled))
        XCTAssertEqual(s.unresolvedClinicalConsumptions,1)
        XCTAssertEqual(s.manifest.attentions,3)
    }
    func testCannotImportOrMergeIntoExistingDemoOrRealOrUnknown() throws {
        let original=try unmarked()
        for mode in [
            N1lDestinationState.containsDemonstration,.containsClinicalData,.uncertain
        ] {
            let s=try N1lRealSnapshotGate.audit(original,destination:mode)
            XCTAssertFalse(s.isStructurallyEligibleForReview)
            XCTAssertFalse(s.canCommitToClinicalStorage)
            XCTAssertThrowsError(try N1lRealSnapshotGate.requireEmptyReplacement(destination:mode))
        }
        XCTAssertNoThrow(try N1lRealSnapshotGate.requireEmptyReplacement(destination:.verifiedEmpty))
    }
    func testNoDroppedUnknownFutureFieldsOrBorradores() throws {
        let original=try unmarked()
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:original) as? [String:Any])
        let before=try N1lRealSnapshotGate.audit(original,destination:.verifiedEmpty)
        XCTAssertTrue(before.unknownFutureFieldsPreserved)
        XCTAssertEqual(before.drafts,2)
        XCTAssertEqual(before.corrections,1)
        let roundtrip=try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys])
        try N1fLosslessFieldGate.verifyUnchanged(original:original,candidate:roundtrip)
        object.removeValue(forKey:"futureTop")
        XCTAssertThrowsError(try N1fLosslessFieldGate.verifyUnchanged(
            original:original,candidate:JSONSerialization.data(withJSONObject:object)))
    }
    func testCannotPresentMissingCollectionAsComplete() throws {
        let payload=try changed { $0.removeValue(forKey:"deliveryIncidents") }
        XCTAssertThrowsError(try N1lRealSnapshotGate.audit(payload,destination:.verifiedEmpty))
    }
    func testDuplicateWorkersDetectedBeforeAnyMigration() throws {
        let payload=try changed { root in
            var records=root["workers"] as! [[String:Any]]
            records[1]["dni"]=records[0]["dni"]
            root["workers"]=records
        }
        XCTAssertThrowsError(try N1lRealSnapshotGate.audit(payload,destination:.verifiedEmpty))
    }
    func testDuplicateLotsNeverCombined() throws {
        let payload=try changed { root in
            root["stockLots"]=[["id":"SYN-LOT-A"],["id":"SYN-LOT-A"]]
        }
        XCTAssertThrowsError(try N1lRealSnapshotGate.audit(payload,destination:.verifiedEmpty)) {
            XCTAssertEqual($0 as? N1lAuditError,.duplicateLot)
        }
    }
    func testMissingLotIDBlocksAudit() throws {
        let payload=try changed { root in root["stockLots"]=[["lot":"X"]] }
        XCTAssertThrowsError(try N1lRealSnapshotGate.audit(payload,destination:.verifiedEmpty)) {
            XCTAssertEqual($0 as? N1lAuditError,.incompleteLot)
        }
    }
    func testUnknownCorrectionOriginIsReportedAndNotSilentlyDropped() throws {
        let payload=try changed { root in
            var visits=root["attentions"] as! [[String:Any]]
            visits[2]["originId"]="MISSING-SYN-ORIGIN"
            root["attentions"]=visits
        }
        let s=try N1lRealSnapshotGate.audit(payload,destination:.verifiedEmpty)
        XCTAssertEqual(s.danglingCorrections,1)
        XCTAssertTrue(s.restrictions.contains(.unresolvedCorrections))
        XCTAssertFalse(s.isStructurallyEligibleForReview)
        XCTAssertEqual(s.drafts,2)
    }
    func testMissingWorkerReferencePreservedAsRisk() throws {
        let payload=try changed { root in
            var visits=root["attentions"] as! [[String:Any]]
            var worker=visits[0]["worker"] as! [String:Any]
            worker["dni"]="99999999"
            visits[0]["worker"]=worker
            root["attentions"]=visits
        }
        let s=try N1lRealSnapshotGate.audit(payload,destination:.verifiedEmpty)
        XCTAssertEqual(s.missingRosterReferences,1)
        XCTAssertFalse(s.isStructurallyEligibleForReview)
        XCTAssertTrue(s.restrictions.contains(.missingRosterReferences))
    }
    func testOriginalN1gDemoNotUsedAsDestination() throws {
        let source=try unmarked()
        let mock=N1gClinic()
        XCTAssertEqual(mock.workers.count,2)
        let s=try N1lRealSnapshotGate.audit(source,destination:.containsDemonstration)
        XCTAssertFalse(s.isStructurallyEligibleForReview)
        XCTAssertFalse(s.canCommitToClinicalStorage)
        XCTAssertEqual(mock.workers.count,2)
        XCTAssertTrue(mock.visits.isEmpty)
    }
    func testAuditingSourceNeverCreatesClinicalRecords() throws {
        let src=try unmarked()
        for _ in 0..<3 {
            let audit=try N1lRealSnapshotGate.audit(src,destination:.uncertain)
            XCTAssertFalse(audit.canCommitToClinicalStorage)
            XCTAssertEqual(audit.manifest.workers,2)
            XCTAssertEqual(audit.manifest.attentions,3)
        }
        let again=try unmarked()
        try N1fLosslessFieldGate.verifyUnchanged(original:src,candidate:again)
    }
}
