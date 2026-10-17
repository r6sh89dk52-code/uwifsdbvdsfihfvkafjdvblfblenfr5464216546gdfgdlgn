import Foundation
import XCTest
@testable import DanperCore

final class N2NativeReadModelTests:XCTestCase {
    private func source() throws -> Data {
        let p=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:p)
            .appendingPathComponent("n1e-clinical-stock.json"))
    }
    private func raw(_ value:Any)throws->Data {
        try JSONSerialization.data(withJSONObject:value,options:[.sortedKeys])
    }
    func testClinicalPhysicalQuantityZeroAndUnverifiedNilStayDistinct()throws {
        let parsed=try N2NativeSnapshotReader.read(source())
        XCTAssertEqual(parsed.roster.count,5)
        XCTAssertEqual(parsed.visits.count,5)
        XCTAssertEqual(parsed.pendingClinicalLines,1)
        let same=try XCTUnwrap(parsed.visits.first{$0.id=="fundo-reuse"})
        XCTAssertEqual(same.consumptionR.first!,0)
        XCTAssertEqual(same.confirmedPhysicalLines,1)
        XCTAssertEqual(same.pendingPhysicalLines,0)
        let unknown=try XCTUnwrap(parsed.visits.first{$0.id=="pending-stock"})
        XCTAssertNil(unknown.consumptionR.first!)
        XCTAssertEqual(unknown.confirmedPhysicalLines,0)
        XCTAssertEqual(unknown.pendingPhysicalLines,1)
        XCTAssertEqual(unknown.frequency,"PRIMERA")
        XCTAssertEqual(parsed.findWorkers("00000003").first?.dni,"00000003")
    }
    func testSameWorkerAndDayFrequencyCountsVisitsNotProducts()throws {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:source()) as? [String:Any])
        var visits=root["attentions"] as! [[String:Any]]
        var second=visits.first{$0["id"] as? String=="fundo-unit"}!
        second["id"]="fundo-unit-second"
        second["time"]="14:05"
        var items=second["items"] as! [[String:Any]]
        for i in items.indices {items[i]["id"]="second-"+String(i)}
        second["items"]=items
        visits.append(second)
        root["attentions"]=visits
        let projected=try N2NativeSnapshotReader.read(raw(root))
        let same=projected.workerHistory("00000001").filter{$0.status=="saved"}
        XCTAssertEqual(same.count,2)
        XCTAssertEqual(Set(same.compactMap{$0.frequency}),Set(["PRIMERA","SEGUNDA"]))
        XCTAssertEqual(same.first{$0.id=="fundo-unit-second"}?.pendingPhysicalLines,1)
    }
    func testOfficialRosterSearchIsSeparateFromHistoricalWorkers()throws {
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:source()) as? [String:Any])
        var workers=root["workers"] as! [[String:Any]]
        workers[0]["rosterStatus"]="official"
        for i in 1..<workers.count {workers[i]["rosterStatus"]="excluded"}
        root["workers"]=workers
        let projected=try N2NativeSnapshotReader.read(raw(root))
        XCTAssertEqual(projected.roster.count,5)
        XCTAssertEqual(projected.searchableRoster.count,1)
        XCTAssertEqual(projected.visits.count,5) // no encounter purged
        XCTAssertEqual(projected.findWorkers("00000002").count,0)
        XCTAssertEqual(projected.workerHistory("00000002").count,1)
    }
    func testDraftDoesNotConsumeFrequencyOrInventStock()throws {
        let before=try source()
        let snapshot=try N2SnapshotEditor.upsertDraft(snapshot:before,id:"draft-in-progress",
                          changes:raw(["items":[["id":"untreated","quantity":0,"code":""]],
                                       "worker":["dni":"00000001"],
                                       "date":"2026-10-14"]),
                          at:1700000000000)
        let projected=try N2NativeSnapshotReader.read(snapshot)
        let row=try XCTUnwrap(projected.visits.first{$0.id=="draft-in-progress"})
        XCTAssertNil(row.frequency)
        XCTAssertTrue(row.consumptionR.isEmpty)
        XCTAssertEqual(projected.pendingClinicalLines,1)
    }
}
