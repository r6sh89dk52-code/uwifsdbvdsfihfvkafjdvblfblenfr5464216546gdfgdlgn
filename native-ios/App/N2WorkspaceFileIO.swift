import Foundation
import DanperCore

/// File reads/writes run on this actor, never on SwiftUI's main actor.
/// Security-scoped access lives for the entire read; protection/limits remain.
actor N2WorkspaceFileIO {
    static let shared=N2WorkspaceFileIO()
    func readBackup(_ url:URL)throws->Data {
        let scoped=url.startAccessingSecurityScopedResource()
        defer {if scoped {url.stopAccessingSecurityScopedResource()}}
        let info=try url.resourceValues(forKeys:[.isRegularFileKey,.isSymbolicLinkKey,.fileSizeKey])
        guard info.isRegularFile==true,info.isSymbolicLink != true,
              let size=info.fileSize,(100...42*1024*1024).contains(size) else {
            throw N2InventoryBackupCodec.Failure.envelope
        }
        return try Data(contentsOf:url)
    }
    func writeProtectedExport(_ data:Data,to url:URL)throws {
        try data.write(to:url,options:[.atomic,.completeFileProtection])
    }
}
