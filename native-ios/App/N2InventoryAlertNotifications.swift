import Foundation
import UserNotifications
import DanperCore

protocol N2AlertNotificationCenter:Sendable {
    func authorized() async -> Bool
    func pending() async -> [UNNotificationRequest]
    func deliveredIDs() async -> [String]
    func removePending(_ ids:[String]) async
    func removeDelivered(_ ids:[String]) async
    func add(_ request:UNNotificationRequest) async throws
}
private struct N2SystemAlertNotificationCenter:N2AlertNotificationCenter {
    func authorized() async -> Bool {
        let status=await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }
    func pending() async -> [UNNotificationRequest] {await UNUserNotificationCenter.current().pendingNotificationRequests()}
    func deliveredIDs() async -> [String] {await UNUserNotificationCenter.current().deliveredNotifications().map{$0.request.identifier}}
    func removePending(_ ids:[String]) async {UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers:ids)}
    func removeDelivered(_ ids:[String]) async {UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers:ids)}
    func add(_ request:UNNotificationRequest) async throws {try await UNUserNotificationCenter.current().add(request)}
}

/// Reconciles only our inventory namespace. Contents are safe on a locked phone.
/// Previously scheduled triggers can fire while the app is closed; no background
/// execution is claimed. Revisions are hints; plans come from authenticated reads.
actor N2InventoryAlertNotifications {
    static let shared=N2InventoryAlertNotifications()
    private let center:any N2AlertNotificationCenter
    init(center:any N2AlertNotificationCenter) {self.center=center}
    init() {center=N2SystemAlertNotificationCenter()}
    private var generation=[String:Int]()
    private var tail:Task<Void,Error>?
    func reconcile(_ alerts:[N2ClinicalAlert],mode:N2WorkspaceVault.Mode) async throws {
        let scope="danper.n2."+mode.rawValue+".inventory."
        let token=(generation[scope] ?? 0)+1;generation[scope]=token
        let previous=tail
        let next=Task {
            _=try? await previous?.value
            try await self.apply(alerts,scope:scope,mode:mode,token:token)
        }
        tail=next
        try await next.value
    }
    private func apply(_ alerts:[N2ClinicalAlert],scope:String,mode:N2WorkspaceVault.Mode,token:Int) async throws {
        let permitted=await center.authorized()
        let pending=await center.pending()
        let delivered=await center.deliveredIDs()
        guard generation[scope]==token,!Task.isCancelled else{return}
        let draftScope="danper.n2."+mode.rawValue+".pending."
        func owns(_ id:String)->Bool {id.hasPrefix(scope) || id.hasPrefix(draftScope)}
        func identifier(_ alert:N2ClinicalAlert)->String {
            alert.kind == .draft ? draftScope+alert.sourceID:scope+alert.id
        }
        let relevant=alerts.filter{$0.kind != .outOfStock}
        let wanted=permitted ? Set(relevant.map(identifier)) : []
        let obsolete=Set(pending.map(\.identifier)+delivered)
            .filter{owns($0) && !wanted.contains($0)}
        await center.removePending(Array(obsolete))
        await center.removeDelivered(Array(obsolete))
        guard permitted else{return}
        let deliveredIDs=Set(delivered)
        let externalCount=pending.filter{!owns($0.identifier)}.count
        let capacity=max(0,60-externalCount)
        // Prefer the next event; retain stable identifiers to avoid duplicate alerts.
        let now=Int64(Date().timeIntervalSince1970*1000)
        let ordered=relevant.filter{!deliveredIDs.contains(identifier($0))}.sorted {
            let a=max($0.dueAt,now),b=max($1.dueAt,now)
            return a==b ? $0.id<$1.id:a<b
        }
        let selected=Array(ordered.prefix(capacity))
        let selectedIDs=Set(selected.map(identifier))
        await center.removePending(pending.map(\.identifier).filter{owns($0) && !selectedIDs.contains($0)})
        for alert in selected {
            guard generation[scope]==token,!Task.isCancelled else{return}
            let id=identifier(alert)
            if deliveredIDs.contains(id) {continue}
            if let existing=pending.first(where:{$0.identifier==id}) {
                if alert.kind != .draft {continue}
                if let due=(existing.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate(),
                   abs(due.timeIntervalSince1970-Double(alert.dueAt)/1000)<2 {continue}
            }
            let content=UNMutableNotificationContent();content.title="DANPER Salud"
            content.body=alert.kind == .draft ? "Tienes un registro pendiente por revisar.":"Revisa las alertas de inventario dentro de DANPER.";content.sound = .default
            let interval=max(1,Double(alert.dueAt)/1000-Date().timeIntervalSince1970)
            try await center.add(UNNotificationRequest(identifier:id,content:content,
                trigger:UNTimeIntervalNotificationTrigger(timeInterval:interval,repeats:false)))
            // A newer plan may have superseded us during center.add's await.
            if generation[scope] != token {await center.removePending([id]);return}
        }
    }
}
