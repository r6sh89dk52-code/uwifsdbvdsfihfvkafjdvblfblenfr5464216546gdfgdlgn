import Foundation
import XCTest
@testable import DanperCore

final class N2UserReviewedKardexLinksTests:XCTestCase {
    private func fixture(_ name:String)throws->Data {
        let root=try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"])
        return try Data(contentsOf:URL(fileURLWithPath:root).appendingPathComponent(name))
    }
    private func catalog()throws->N2NativeCatalogIndex {
        let indicator=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n1s-indicator-plan.json")) as? [String:Any])
        let nursing=try XCTUnwrap(JSONSerialization.jsonObject(
            with:fixture("n2-nursing-parity.json")) as? [String:Any])
        return try N2NativeCatalogLoader.load(
            products:JSONSerialization.data(withJSONObject:indicator["catalog"]!),
            nursing:JSONSerialization.data(withJSONObject:nursing["catalog"]!),
            approvedMappings:fixture("n2-reviewed-approved.json"))
    }
    func testSixReviewedConfirmationsAndSixExplicitExclusionsPreserve86Official()throws {
        let index=try catalog()
        XCTAssertEqual(index.clinical.count,432)
        XCTAssertEqual(index.nursing.count,98)
        XCTAssertEqual(index.approvals.count,86)
        XCTAssertEqual(N2UserReviewedKardexLinks.links.count,6)
        XCTAssertEqual(N2UserReviewedKardexLinks.unmatched,
                       Set(["E-25","E-81","E-82","E-84","E-85","E-98"]))
        let expected=[
            "16025008":"E-20",
            "16000178":"E-68",
            "16000019":"E-86",
            "10000929":"E-94",
            "16000127":"E-95",
            "16021493":"E-97"
        ]
        for (clinical,kardex) in expected {
            XCTAssertEqual(index.authorizedNursingOptions(for:clinical).map(\.id),[kardex])
        }
        XCTAssertTrue(index.nursing.contains{$0.id=="E-25"})
        XCTAssertTrue(index.nursing.contains{$0.id=="E-98"})
        XCTAssertTrue(index.authorizedNursingOptions(for:"99999999").isEmpty)
        // A user-confirmed match is NOT elevated to one of the 86 approvals.
        XCTAssertFalse(index.approvals.contains{$0.kardexID=="E-68"})
        XCTAssertFalse(index.approvals.contains{$0.kardexID=="E-86"})
        XCTAssertFalse(index.approvals.contains{$0.kardexID=="E-94"})
    }
    func testNoPhysicalLotsMeansZeroActualStockAndPendingNotInventedMovement()throws {
        let index=try catalog()
        let snapshot=try fixture("n1e-clinical-stock.json")
        var root=try XCTUnwrap(JSONSerialization.jsonObject(with:snapshot) as? [String:Any])
        var visits=try XCTUnwrap(root["attentions"] as? [[String:Any]])
        var visit=try XCTUnwrap(visits.first)
        visit["id"]="reviewed-without-lot"
        let match=try XCTUnwrap(index.clinical.first{$0.code=="16025008"})
        visit["items"]=[["id":"reviewed-no-lot-item","code":match.code,"name":match.name,
                          "unit":match.unit,"quantity":1,"procedure":"OBSERVACION"]]
        // Never claim a newly-entered zero-lot product has physical supply.
        let lots=try XCTUnwrap(root["stockLots"] as? [[String:Any]])
        XCTAssertFalse(lots.contains{$0["code"] as? String=="E-20"})
        let at=Int64(ISO8601DateFormatter().date(from:"2026-10-14T18:00:00Z")!.timeIntervalSince1970*1000)
        let result=try N2NativeClinicalTransaction.appendSavedVisit(
            snapshot:snapshot,
            visit:JSONSerialization.data(withJSONObject:visit),
            approvedCatalog:fixture("n2-reviewed-approved.json"),at:at)
        XCTAssertEqual(result.linked,0)
        XCTAssertEqual(result.pending,1)
        XCTAssertTrue(result.pendingReasons.contains{
            $0.contains("Sin existencias FEFO disponibles")
        })
        XCTAssertEqual(result.physicalMovementsAdded,0)
        let after=try XCTUnwrap(JSONSerialization.jsonObject(with:result.snapshot) as? [String:Any])
        let beforeEvents=try XCTUnwrap(root["stockMovements"] as? [[String:Any]])
        let afterEvents=try XCTUnwrap(after["stockMovements"] as? [[String:Any]])
        XCTAssertEqual(afterEvents.count,beforeEvents.count)
    }
}
