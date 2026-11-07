import Foundation
import XCTest
import DanperCore
@testable import DANPERNative

final class N2NotificationInboxPreferencesTests:XCTestCase {
    func testIndividualDismissalPersistsAndModesRemainSeparate()throws {
        let suite="DANPER-FICTICIO-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer{defaults.removePersistentDomain(forName:suite)}
        XCTAssertEqual(N2NotificationInboxPreferences.dismiss("draft.ficticio-A",mode:.clinical,defaults:defaults),["draft.ficticio-A"])
        XCTAssertEqual(N2NotificationInboxPreferences.dismiss("stock.ficticio-B",mode:.clinical,defaults:defaults),["draft.ficticio-A","stock.ficticio-B"])
        XCTAssertEqual(N2NotificationInboxPreferences.read(.clinical,defaults:try XCTUnwrap(UserDefaults(suiteName:suite))),["draft.ficticio-A","stock.ficticio-B"])
        XCTAssertTrue(N2NotificationInboxPreferences.read(.demo,defaults:defaults).isEmpty)
    }
    func testRestoringPresentationPreferencesDoesNotRemoveOtherStoredData()throws {
        let suite="DANPER-FICTICIO-"+UUID().uuidString
        let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
        defer{defaults.removePersistentDomain(forName:suite)}
        let data=Data("MARCADOR FICTICIO DE DATOS AJENOS".utf8)
        defaults.set(data,forKey:"unrelated-data")
        _=N2NotificationInboxPreferences.dismiss("ficticio",mode:.clinical,defaults:defaults)
        _=N2NotificationInboxPreferences.dismiss("otro",mode:.demo,defaults:defaults)
        XCTAssertTrue(N2NotificationInboxPreferences.restore(.clinical,defaults:defaults).isEmpty)
        XCTAssertTrue(N2NotificationInboxPreferences.read(.clinical,defaults:defaults).isEmpty)
        XCTAssertEqual(N2NotificationInboxPreferences.read(.demo,defaults:defaults),["otro"])
        XCTAssertEqual(defaults.data(forKey:"unrelated-data"),data)
    }
}

final class N2NotificationInboxPresentationTests:XCTestCase {
    private func product(_ code:String,_ expiry:String,quantity:Double=1)->N2SimpleProduct {
        N2SimpleProduct(code:code,name:"PRODUCTO FICTICIO "+code,unit:"UND",
                        mode:.units,quantity:quantity,expiry:expiry,expiryVerified:true)
    }
    func testOneExpiryRowPerProductBeforeExpiration() {
        let now=Date(timeIntervalSince1970:1_793_966_400) // 2026-11-06
        let items=[product("A","2026-11-20"),product("B","2026-12-01")]
        let plan=N2ClinicalAlerts.plan(drafts:[],products:items,now:now)
        XCTAssertEqual(plan.count,4,"The Core scheduler retains both distinct expiry events")
        let visible=N2NotificationInboxPresentation.uniqueExpiry(plan,now:now)
        XCTAssertEqual(visible.count,2)
        XCTAssertEqual(Set(visible.map(\.sourceID)),Set(["A","B"]))
        XCTAssertTrue(visible.allSatisfy{$0.kind == .expiryWarning})
        XCTAssertEqual(items[0].quantity,1)
    }
    func testExpiryDayTakesOverEvenIfInboxHasNotRefreshed() {
        let before=Date(timeIntervalSince1970:1_793_966_400)
        let after=ISO8601DateFormatter().date(from:"2026-11-21T12:00:00Z")!
        let plan=N2ClinicalAlerts.plan(drafts:[],products:[
            product("A","2026-11-20"),product("B","2026-12-01")],now:before)
        let visible=N2NotificationInboxPresentation.uniqueExpiry(plan,now:after)
        XCTAssertEqual(visible.count,2)
        XCTAssertEqual(visible.first{$0.sourceID=="A"}?.kind,.expiryDay)
        XCTAssertEqual(visible.first{$0.sourceID=="B"}?.kind,.expiryWarning)
        XCTAssertEqual(plan.count,4,"Only presentation is collapsed; notifications remain scheduled")
    }
    func testExpiryProjectionLeavesDraftsAndOutOfStockUntouched() {
        let now=Date(timeIntervalSince1970:1_793_966_400)
        var formA=N2NativeFormDraft(id:UUID().uuidString);formA.dni="00000001"
        var formB=N2NativeFormDraft(id:UUID().uuidString);formB.dni="00000002"
        let timestamp=Int64(now.timeIntervalSince1970*1000)-3_600_000
        let drafts=[
            N2RecoverableDraft(id:formA.id,updatedAt:timestamp,workerName:"FICTICIO",form:formA,stage:0),
            N2RecoverableDraft(id:formB.id,updatedAt:timestamp,workerName:"FICTICIO",form:formB,stage:0)
        ]
        let plan=N2ClinicalAlerts.plan(drafts:drafts,products:[
            product("A","2026-11-20"),product("B","",quantity:0)],now:now)
        let visible=N2NotificationInboxPresentation.uniqueExpiry(plan,now:now)
        XCTAssertEqual(visible.filter{$0.kind == .draft}.count,2)
        XCTAssertEqual(visible.filter{$0.kind == .outOfStock}.count,1)
        XCTAssertEqual(visible.filter{$0.kind == .expiryWarning}.count,1)
    }
}
