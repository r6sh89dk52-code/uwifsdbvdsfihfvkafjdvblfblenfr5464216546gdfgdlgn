import Foundation
import DanperCore

/// Format v1 remains readable by Build 222. V2 is explicitly versioned so old
/// readers cannot silently mistake the consolidated regime for an empty FEFO store.
enum N2NativePortableBackupMaker {
    static func createVerified(snapshot:Data,password:String,
        domain:N2InventoryBackupDomain = .unspecified)throws->Data {
        try N2InventoryBackupCodec.createVerified(snapshot:snapshot,password:password,domain:domain)
    }
}
