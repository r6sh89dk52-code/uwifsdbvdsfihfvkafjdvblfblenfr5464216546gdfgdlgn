import Foundation
import XCTest
@testable import DanperCore

final class N2ClinicalAlertsTests:XCTestCase {
    private let now=Date(timeIntervalSince1970:1_793_966_400) // 2026-11-06 12:00 UTC
    private func product(_ code:String="1",quantity:Double=1,expiry:String="2026-11-20",verified:Bool=true)->N2SimpleProduct {
        N2SimpleProduct(code:code,name:"PRODUCTO FICTICIO",unit:"UND",mode:.units,quantity:quantity,expiry:expiry,expiryVerified:verified)
    }
    func testOnlyVerifiedRealCalendarDatesWithStockGenerateExpiryAlerts() {
        let values=[product("1",expiry:"2026-02-30"),product("2",verified:false),product("3",quantity:0)]
        let plan=N2ClinicalAlerts.plan(drafts:[],products:values,now:now)
        XCTAssertEqual(plan.count,1);XCTAssertEqual(plan[0].kind,.outOfStock)
        XCTAssertTrue(plan[0].actionable)
    }
    func testThirtyDayWarningAndExpiryAreStableAndDoNotMutateInventory() {
        let p=product()
        let first=N2ClinicalAlerts.plan(drafts:[],products:[p],now:now)
        XCTAssertEqual(first.count,2)
        XCTAssertEqual(first.filter(\.actionable).map(\.kind),[.expiryWarning])
        XCTAssertEqual(first,N2ClinicalAlerts.plan(drafts:[],products:[p],now:now))
        XCTAssertFalse(first[0].id.contains(p.name))
        XCTAssertEqual(p.quantity,1);XCTAssertEqual(p.expiry,"2026-11-20")
    }
    func testResolvedOrReprogrammedExpiryRemovesOldIdentifiers() {
        let old=N2ClinicalAlerts.plan(drafts:[],products:[product()],now:now)
        let next=N2ClinicalAlerts.plan(drafts:[],products:[product(expiry:"2026-12-20")],now:now)
        XCTAssertTrue(Set(old.map(\.id)).isDisjoint(with:next.map(\.id)))
        XCTAssertTrue(next.allSatisfy{!$0.actionable})
        XCTAssertTrue(N2ClinicalAlerts.plan(drafts:[],products:[],now:now).isEmpty)
    }
    func testExpiredProductHasOneActionableWarningAndNoGuessedMinimum() {
        let plan=N2ClinicalAlerts.plan(drafts:[],products:[product(expiry:"2026-10-01"),product("2",quantity:0.1,expiry:"")],now:now)
        XCTAssertEqual(plan.count,1);XCTAssertEqual(plan[0].kind,.expiryDay)
        XCTAssertTrue(plan[0].actionable)
    }
    func testDraftReminderUsesLastEditAndHasNoPatientData() {
        var form=N2NativeFormDraft(id:UUID().uuidString);form.dni="00000001"
        let timestamp=Int64(now.timeIntervalSince1970*1000)
        let draft=N2RecoverableDraft(id:form.id,updatedAt:timestamp-3_600_000,workerName:"FICTICIO",form:form,stage:0)
        let alert=N2ClinicalAlerts.plan(drafts:[draft],products:[],now:now)[0]
        XCTAssertEqual(alert.dueAt,timestamp);XCTAssertTrue(alert.actionable)
        XCTAssertFalse(alert.id.contains(form.id));XCTAssertFalse(alert.detail.contains(draft.workerName))
    }
}
