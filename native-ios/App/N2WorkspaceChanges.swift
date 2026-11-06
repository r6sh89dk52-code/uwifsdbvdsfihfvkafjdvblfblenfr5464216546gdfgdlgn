import SwiftUI

/// Invalidation hints only. Every consumer authenticates its own revision.
/// No clinical values, identities, keys or archive contents are broadcast.
enum N2WorkspaceChanges {
    static let notification=Notification.Name("danper.workspace.verified-change")
    static func post(mode:N2WorkspaceVault.Mode,revision:Int,kind:String) {
        NotificationCenter.default.post(name:notification,object:mode.rawValue,
            userInfo:["revision":revision,"kind":kind])
    }
    static func matches(_ event:Notification,_ vault:N2WorkspaceVault)->Bool {
        event.object as? String == vault.mode.rawValue
    }
}
private struct N2WorkspaceTabKey:EnvironmentKey {static let defaultValue = -1}
extension EnvironmentValues {
    var n2WorkspaceTab:Int {
        get {self[N2WorkspaceTabKey.self]}
        set {self[N2WorkspaceTabKey.self]=newValue}
    }
}
