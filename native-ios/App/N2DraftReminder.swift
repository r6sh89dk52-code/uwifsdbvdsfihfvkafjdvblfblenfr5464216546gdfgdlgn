import Foundation
import UserNotifications

/// Notifications never contain patient identifiers. Demo and clinical sources
/// use independent identifiers so erasing the DEMO never cancels clinical work.
enum N2DraftReminder {
    private static func identifier(id:String,mode:N2WorkspaceVault.Mode)->String {
        "danper.n2."+mode.rawValue+".pending."+id
    }

    static func schedule(id:String,mode:N2WorkspaceVault.Mode = .demo) async {
        guard UUID(uuidString:id) != nil else{return}
        let center=UNUserNotificationCenter.current()
        let settings=await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else{return}
        let notification=UNMutableNotificationContent()
        notification.title="DANPER Salud"
        notification.body="Tienes un registro pendiente por revisar."
        notification.sound = .default
        let request=UNNotificationRequest(
            identifier:identifier(id:id,mode:mode),
            content:notification,
            trigger:UNTimeIntervalNotificationTrigger(timeInterval:3600,repeats:false))
        try? await center.add(request)
    }

    /// Cancels every demo reminder even if the deleted encrypted draft index
    /// was unreadable. Clinical identifiers are never included in this filter.
    static func cancelAllDemo() async {
        let center=UNUserNotificationCenter.current()
        let requests=await center.pendingNotificationRequests()
        let ids=requests.map(\.identifier).filter {
            $0.hasPrefix("danper.n2.demo.pending.") ||
            $0.hasPrefix("danper.n2.pending.")
        }
        if !ids.isEmpty {center.removePendingNotificationRequests(withIdentifiers:ids)}
    }

    static func cancel(id:String,mode:N2WorkspaceVault.Mode = .demo) {
        guard UUID(uuidString:id) != nil else{return}
        var ids=[identifier(id:id,mode:mode)]
        if mode == .demo {
            // Pre-routing B11 used this single legacy name for DEMO only.
            ids.append("danper.n2.pending."+id)
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers:ids)
    }
}
