import Foundation
import XCTest
import UserNotifications
import DanperCore
@testable import DANPERNative

private actor N2FakeAlertCenter:N2AlertNotificationCenter {
    var allowed=true
    var requests=[String:UNNotificationRequest]()
    var delivered=[String]()
    var additions=0
    func authorized()->Bool {allowed}
    func pending()->[UNNotificationRequest] {Array(requests.values)}
    func deliveredIDs()->[String] {delivered}
    func removePending(_ ids:[String]) {for id in ids {requests.removeValue(forKey:id)}}
    func removeDelivered(_ ids:[String]) {delivered.removeAll{ids.contains($0)}}
    func add(_ request:UNNotificationRequest) {requests[request.identifier]=request;additions+=1}
    func deny(){allowed=false}
    func deliverAll(){delivered=Array(requests.keys);requests.removeAll()}
    func count()->Int {additions}
}
final class N2AlertNotificationTests:XCTestCase {
    private func plan(_ day:String="2026-11-20")->[N2ClinicalAlert] {
        let p=N2SimpleProduct(code:"1",name:"NOMBRE FICTICIO PRIVADO",unit:"UND",mode:.units,quantity:1,expiry:day,expiryVerified:true)
        return N2ClinicalAlerts.plan(drafts:[],products:[p],now:Date(timeIntervalSince1970:1793966400))
    }
    func testRepeatedPlanDoesNotDuplicateAndContentsAreGeneric() async throws {
        let center=N2FakeAlertCenter()
        let subject=N2InventoryAlertNotifications(center:center)
        try await subject.reconcile(plan(),mode:.clinical)
        try await subject.reconcile(plan(),mode:.clinical)
        let requests=await center.pending(),count=await center.count()
        XCTAssertEqual(requests.count,2);XCTAssertEqual(count,2)
        for r in requests {
            XCTAssertEqual(r.content.title,"DANPER Salud")
            XCTAssertEqual(r.content.body,"Revisa las alertas de inventario dentro de DANPER.")
            XCTAssertTrue(r.content.userInfo.isEmpty)
            XCTAssertFalse(r.identifier.contains("PRIVADO"))
        }
    }
    func testResolvedAlertCancelsPendingAndDeliveredWithoutTouchingAnotherMode() async throws {
        let center=N2FakeAlertCenter()
        let scheduler=N2InventoryAlertNotifications(center:center)
        try await scheduler.reconcile(plan(),mode:.clinical)
        await center.deliverAll()
        try await scheduler.reconcile(plan(),mode:.demo)
        try await scheduler.reconcile([],mode:.clinical)
        let requests=await center.pending(),delivered=await center.deliveredIDs()
        XCTAssertEqual(requests.count,2);XCTAssertTrue(delivered.isEmpty)
        XCTAssertTrue(requests.allSatisfy{$0.identifier.hasPrefix("danper.n2.demo.")})
    }
    func testChangedDateReplacesOldIdentifiersAndDeniedPermissionRemovesOurRequests() async throws {
        let center=N2FakeAlertCenter()
        let subject=N2InventoryAlertNotifications(center:center)
        try await subject.reconcile(plan(),mode:.clinical)
        let old=Set(await center.pending().map(\.identifier))
        try await subject.reconcile(plan("2026-12-20"),mode:.clinical)
        let next=Set(await center.pending().map(\.identifier))
        XCTAssertEqual(next.count,2);XCTAssertTrue(old.isDisjoint(with:next))
        await center.deny()
        try await subject.reconcile(plan("2026-12-20"),mode:.clinical)
        let remaining=await center.pending();XCTAssertTrue(remaining.isEmpty)
    }
}
