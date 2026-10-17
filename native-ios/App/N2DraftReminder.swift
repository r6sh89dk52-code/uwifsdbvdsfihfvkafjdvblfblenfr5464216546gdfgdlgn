import Foundation
import UserNotifications

/// Reminder for inactive N2 drafts. The notification body and identifier
/// contain no worker, DNI, clinical content, diagnosis, or vault data.
enum N2DraftReminder {
    static func schedule(id:String) async {
        guard UUID(uuidString:id) != nil else{return}
        let center=UNUserNotificationCenter.current()
        let settings=await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {return}
        let notification=UNMutableNotificationContent()
        notification.title="DANPER Salud"
        notification.body="Tienes un registro pendiente por revisar."
        notification.sound=.default
        let request=UNNotificationRequest(
            identifier:"danper.n2.pending."+id,
            content:notification,
            trigger:UNTimeIntervalNotificationTrigger(timeInterval:3600,repeats:false))
        // Replacing an identifier moves the reminder to 60 min since the last edit.
        try? await center.add(request)
    }

    static func cancel(id:String) {
        guard UUID(uuidString:id) != nil else{return}
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers:["danper.n2.pending."+id])
    }
}
