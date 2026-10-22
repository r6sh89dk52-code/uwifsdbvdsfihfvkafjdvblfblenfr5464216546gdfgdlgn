import Foundation
import XCTest
@testable import DanperCore

final class N2ClinicalTransactionsTests: XCTestCase {
    private let timestamp:Int64 = 1_760_472_000_000 // replaced by explicit parse below
    private func read(_ file:String) throws -> Data {
        let root=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:root,isDirectory:true).appendingPathComponent(file))
    }
    private func at() -> Int64 {1_760_473_600_000} // 2025 is overridden by ISO helper
    private func time(_ day:String="2026-10-14",hour:String="18:00") -> Int64 {
        let date=ISO8601DateFormatter().date(from:day+"T"+hour+":00Z")!
        return Int64(date.timeIntervalSince1970*1000)
    }
    private func source() throws -> [String:Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with:read("n1e-clinical-stock.json")) as? [String:Any])
    }
    private func data(_ object:Any) throws -> Data {
        try JSONSerialization.data(withJSONObject:object,options:[.sortedKeys])
    }
    private func sample(_ source:[String:Any],id:String="n2-new",unit:Bool=true,
                        quantity:Int=3,physical:Double?=nil,approved:Bool=false)->[String:Any] {
        let visits=source["attentions"] as! [[String:Any]]
        var visit=visits.first(where:{$0["id"] as? String==(unit ? "fundo-unit":"fundo-reuse")})!
        visit["id"]=id
        visit["date"]="2026-10-14"
        var items=visit["items"] as! [[String:Any]]
        items[0]["id"]=id+"-item"
        items[0]["quantity"]=quantity
        items[0].removeValue(forKey:"physicalUse")
        if let physical {
            items[0]["physicalUse"]=[
                "lotId":"later-sealed-box",
                "quantity":physical,
                "confirmNewContainer":approved
            ] as [String:Any]
        }
        visit["items"]=items
        return visit
    }
    func testNewIndividualUsesFEFOAndKeepsNineCollections() throws {
        let original=try source()
        let snapshot=try data(original)
        let initial=try N1eLegacyClinicalAudit.inspect(snapshot)
        let visit=sample(original)
        let output=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:snapshot,visit:data(visit),
            approvedCatalog:read("n2-reviewed-approved.json"),at:time())
        XCTAssertEqual(output.linked,1)
        XCTAssertEqual(output.pending,0)
        XCTAssertEqual(output.physicalMovementsAdded,1)
        let after=try N1eLegacyClinicalAudit.inspect(output.snapshot)
        XCTAssertEqual(after.linkedClinicalItems,initial.linkedClinicalItems+1)
        XCTAssertEqual(after.attentions,initial.attentions+1)
        XCTAssertEqual(after.consumptionR.last!,3)
        let next=try XCTUnwrap(JSONSerialization.jsonObject(with:output.snapshot) as? [String:Any])
        XCTAssertEqual(Set(next.keys),Set(original.keys))
        XCTAssertEqual(next["allergies"] as? [String:String], original["allergies"] as? [String:String])
        XCTAssertEqual((next["catalogMappings"] as? [[String:Any]])?.count,0)
        let repeated=try N2NativeClinicalTransaction.retryCurrentSavedVisit(
            snapshot:output.snapshot,visitID:"n2-new",
            approvedCatalog:read("n2-reviewed-approved.json"),at:time())
        XCTAssertEqual(repeated.alreadyLinked,1)
        XCTAssertEqual(repeated.physicalMovementsAdded,0)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(repeated.snapshot).physicalMovements,
                       after.physicalMovements)
    }
    func testExistingOpenBoxEmitsZeroRAndNoNewOpening() throws {
        let original=try source()
        let visit=sample(original,id:"n2-reuse",unit:false,quantity:1,physical:1)
        let result=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:data(original),visit:data(visit),
            approvedCatalog:read("n2-reviewed-approved.json"),at:time())
        XCTAssertEqual(result.linked,1)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(result.snapshot).consumptionR.last!,0)
    }
    func testMultiLotNewBottleBlockedUntilExplicitConsent() throws {
        var root=try source()
        var lots=root["stockLots"] as! [[String:Any]]
        var extra=lots.first(where:{$0["id"] as? String=="later-sealed-box"})!
        extra["id"]="future-sealed-box"
        extra["lot"]="future-sealed-box"
        extra["expires"]="2027-08-01"
        extra["sealedContainers"]=1
        extra["looseUnits"]=0
        extra["openedRemaining"]=0
        lots.append(extra)
        root["stockLots"]=lots
        let before=try data(root)
        _=try N1eLegacyClinicalAudit.inspect(before)
        let blocked=sample(root,id:"n2-split",unit:false,quantity:1,physical:99)
        let denied=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:before,visit:data(blocked),
            approvedCatalog:read("n2-reviewed-approved.json"),at:time())
        XCTAssertEqual(denied.linked,0)
        XCTAssertEqual(denied.pending,1)
        XCTAssertEqual(denied.physicalMovementsAdded,0)
        let prior=try N1eLegacyClinicalAudit.inspect(before)
        let deniedReport=try N1eLegacyClinicalAudit.inspect(denied.snapshot)
        XCTAssertEqual(deniedReport.physicalMovements,prior.physicalMovements)
        XCTAssertNil(deniedReport.consumptionR.last!)
        let authorized=sample(root,id:"n2-split",unit:false,quantity:1,physical:99,approved:true)
        let posted=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:before,visit:data(authorized),
            approvedCatalog:read("n2-reviewed-approved.json"),at:time())
        XCTAssertEqual(posted.linked,1)
        XCTAssertEqual(posted.physicalMovementsAdded,2)
        XCTAssertEqual(try N1eLegacyClinicalAudit.inspect(posted.snapshot).consumptionR.last!,1)
    }
    func testDuplicateAndUnapprovedMappingsNeverMutateHistory() throws {
        let root=try source()
        let visit=sample(root,id:"fundo-unit")
        XCTAssertThrowsError(try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:data(root),visit:data(visit),
            approvedCatalog:read("n2-reviewed-approved.json"),at:time())) {
            XCTAssertEqual($0 as? N2ClinicalError,.duplicateVisit)
        }
        var map=try XCTUnwrap(JSONSerialization.jsonObject(with:read("n2-reviewed-approved.json")) as? [[String:Any]])
        map[0]["clinicalCode"]="99999999"
        XCTAssertThrowsError(try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:data(root),visit:data(sample(root)),
            approvedCatalog:data(map),at:time())) {
            XCTAssertEqual($0 as? N2ClinicalError,.invalidApprovedCatalog)
        }
    }
    func testHistoricalSavedVisitDispensesAutomaticallyWhenLotChronologyAllows() throws {
        let original=try source()
        var historic=sample(original,id:"n2-historical-automatic")
        historic["date"]="2026-10-15"
        historic["time"]="10:00"
        let output=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:data(original),visit:data(historic),
            approvedCatalog:read("n2-reviewed-approved.json"),
            at:time("2026-10-22"))
        XCTAssertEqual(output.linked,1)
        XCTAssertEqual(output.pending,0)
        let root=try XCTUnwrap(JSONSerialization.jsonObject(with:output.snapshot) as? [String:Any])
        let movements=try XCTUnwrap(root["stockMovements"] as? [[String:Any]])
        let dated=movements.filter {
            let link=$0["dispenseRef"] as? [String:Any]
            return link?["attentionId"] as? String=="n2-historical-automatic"
        }
        XCTAssertFalse(dated.isEmpty)
        for movement in dated {
            let at=try XCTUnwrap(movement["at"] as? NSNumber)
            XCTAssertEqual(at.int64Value,time("2026-10-15",hour:"15:00"))
        }
        let repeated=try N2NativeClinicalTransaction.retryCurrentSavedVisit(
            snapshot:output.snapshot,visitID:"n2-historical-automatic",
            approvedCatalog:read("n2-reviewed-approved.json"),
            at:time("2026-10-22"))
        XCTAssertEqual(repeated.physicalMovementsAdded,0)
        XCTAssertEqual(repeated.alreadyLinked,1)
    }
    func testHistoricalAndInsufficientStockRemainClinicallyPending() throws {
        let root=try source()
        var old=sample(root,id:"n2-old")
        old["date"]="2026-10-13"
        let blocked=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:data(root),visit:data(old),
            approvedCatalog:read("n2-reviewed-approved.json"),at:time())
        XCTAssertEqual(blocked.pending,1)
        XCTAssertEqual(blocked.physicalMovementsAdded,0)
        let pending=try N2NativeClinicalTransaction.retryCurrentSavedVisit(
            snapshot:data(root),visitID:"pending-stock",
            approvedCatalog:read("n2-reviewed-approved.json"),at:time())
        XCTAssertEqual(pending.pending,1)
        XCTAssertEqual(pending.physicalMovementsAdded,0)
    }
}
