import Foundation
import XCTest
@testable import DanperCore

/// Fixture-only authorization checks; no actual patients or backup passwords.
final class N1nInactiveSourceTests:XCTestCase {
    let all=N1nAcknowledgment(originalBuild222:true,reviewedForDemo:true,
                               understandsNoRestore:true)
    private func source() throws -> Data {
        guard let base=ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"] else {
            throw XCTSkip("Requires synthetic N1f fixture")
        }
        let d=try Data(contentsOf:URL(fileURLWithPath:base)
            .appendingPathComponent("n1f-source.json"))
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:d) as? [String:Any])
        var people=root["workers"] as! [[String:Any]]
        people[0]["name"]="IDENTIDAD SINTETICA ALFA"
        people[1]["name"]="IDENTIDAD SINTETICA BETA"
        root["workers"]=people
        var visits=root["attentions"] as! [[String:Any]]
        for i in visits.indices {
            if var worker=visits[i]["worker"] as? [String:Any] {
                worker["name"]="IDENTIDAD SINTETICA ALFA"
                visits[i]["worker"]=worker
            }
        }
        root["attentions"]=visits
        return try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys])
    }
    private func changed(_ edit:(inout [String:Any])->Void) throws -> Data {
        let raw=try source()
        var r=try XCTUnwrap(JSONSerialization.jsonObject(with:raw) as? [String:Any])
        edit(&r)
        return try JSONSerialization.data(withJSONObject:r,options:[.sortedKeys])
    }
    func testCanOnlyPrepareNotActivate() throws {
        let result=try N1nInactiveSourceGate.authorize(source(),acknowledgment:all)
        XCTAssertEqual(result.workers,2)
        XCTAssertEqual(result.visits,3)
        XCTAssertEqual(result.drafts,2)
        XCTAssertEqual(result.unresolvedConsumptions,1)
        XCTAssertEqual(result.semanticSHA256.count,64)
        XCTAssertFalse(result.provenAuthentic)
        XCTAssertFalse(result.canActivate)
    }
    func testRejectsEachMissingConsent() throws {
        // Retrieve fixture outside XCTAssertThrowsError so XCTSkip cannot
        // be misclassified as a domain-level consent rejection.
        let raw=try source()
        for missing in 0...2 {
            let flags=(0...2).map{$0 != missing}
            let consent=N1nAcknowledgment(originalBuild222:flags[0],
                reviewedForDemo:flags[1],understandsNoRestore:flags[2])
            XCTAssertThrowsError(try N1nInactiveSourceGate.authorize(
                raw,acknowledgment:consent)) {
                XCTAssertEqual($0 as? N1nGateError,.missingAcknowledgment)
            }
        }
    }
    func testRecognizedDemoCannotBePrepared() throws {
        let dir=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        let raw=try Data(contentsOf:URL(fileURLWithPath:dir)
                        .appendingPathComponent("n1f-source.json"))
        XCTAssertThrowsError(try N1nInactiveSourceGate.authorize(
            raw,acknowledgment:all)) {
            XCTAssertEqual($0 as? N1nGateError,.ineligibleSource)
        }
    }
    func testMissingCollectionIsRejected() throws {
        let raw=try changed{$0.removeValue(forKey:"stockMovements")}
        XCTAssertThrowsError(try N1nInactiveSourceGate.authorize(raw,acknowledgment:all))
    }
    func testDuplicateIdentityIsRejected() throws {
        let raw=try changed { r in
            var people=r["workers"] as! [[String:Any]]
            people[1]["dni"]=people[0]["dni"]
            r["workers"]=people
        }
        XCTAssertThrowsError(try N1nInactiveSourceGate.authorize(raw,acknowledgment:all))
    }
    func testBrokenCorrectionChainIsRejected() throws {
        let raw=try changed { r in
            var visits=r["attentions"] as! [[String:Any]]
            visits[2]["originId"]="UNKNOWN-SAVED-ORIGIN"
            r["attentions"]=visits
        }
        XCTAssertThrowsError(try N1nInactiveSourceGate.authorize(raw,acknowledgment:all))
    }
    func testClinicalUnresolvedItemsStayCountedNotDiscarded() throws {
        let raw=try source(),a=try N1nInactiveSourceGate.authorize(raw,acknowledgment:all)
        let b=try N1lRealSnapshotGate.audit(raw,destination:.verifiedEmpty)
        XCTAssertEqual(a.unresolvedConsumptions,b.unresolvedClinicalConsumptions)
        XCTAssertEqual(a.semanticSHA256,b.semanticSHA256)
    }
}
