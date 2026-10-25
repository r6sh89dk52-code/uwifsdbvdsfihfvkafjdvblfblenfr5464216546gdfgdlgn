import Foundation
import XCTest
@testable import DanperCore

final class N2IncidentExportScopeTests:XCTestCase {
    private let movements:[[String:Any]]=[
        ["id":"MOVE-A","dispenseRef":["attentionId":"ATT-A","itemId":"ITEM-A"]],
        ["id":"MOVE-B","dispenseRef":["attentionId":"ATT-B","itemId":"ITEM-B"]]
    ]
    private func incident(_ movement:String,_ id:String="INC-1")->[String:Any] {
        ["id":id,"movementId":movement,
         "attentionId":movement=="MOVE-A" ? "ATT-A":"ATT-B",
         "itemId":movement=="MOVE-A" ? "ITEM-A":"ITEM-B",
         "kind":"returned","quantity":1,"reason":"Devolución revisada",
         "at":1_790_000_000_000 as Int64,"stockRestored":false]
    }
    func testHistoricIncidentOutsideSelectedPeriodDoesNotBlock()throws {
        XCTAssertFalse(try N2VerifiedIndicatorWorkbook.hasIncidentInSelectedVisits(
            [incident("MOVE-B")],movements:movements,
            selectedVisitIDs:Set(["ATT-A"])))
        XCTAssertTrue(try N2VerifiedIndicatorWorkbook.hasIncidentInSelectedVisits(
            [incident("MOVE-B")],movements:movements,
            selectedVisitIDs:Set(["ATT-B"])))
    }
    func testDuplicateOrInvalidIncidentNeverPassesReview()throws {
        let duplicate=[incident("MOVE-B","ONE"),incident("MOVE-B","TWO")]
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.hasIncidentInSelectedVisits(
            duplicate,movements:movements,selectedVisitIDs:Set(["ATT-A"])))
        var invalid=incident("MOVE-A")
        invalid["stockRestored"]=true
        XCTAssertThrowsError(try N2VerifiedIndicatorWorkbook.hasIncidentInSelectedVisits(
            [invalid],movements:movements,selectedVisitIDs:Set(["ATT-A"])))
    }
}
