import Foundation

/// Strictly allowlisted on-device destruction scope for the demonstrator.
/// Never accepts the real N2 clinical vault, the build 222 app, N1x stages,
/// Application Support itself, or an arbitrary path supplied by UI.
public enum N2SyntheticResetScope {
    public static let confirmation="BORRAR PRUEBAS"
    public static let directoryName="DANPER-N2-SYNTHETIC-VAULT"
    public static let clinicalDirectoryName="DANPER-N2-CLINICAL-VAULT"

    private static let demoTempPrefixes=[
        "danper-n2-demo-indicator-",
        "danper-n2-demo-kardex-",
        "danper-n2-demo-encrypted-share-"
    ]

    public static func canEraseDemoTempFolder(named name:String)->Bool {
        for prefix in demoTempPrefixes where name.hasPrefix(prefix) {
            let suffix=String(name.dropFirst(prefix.count))
            return UUID(uuidString:suffix) != nil
        }
        return false
    }

    public static func canErase(support:URL,target:URL)->Bool {
        let base=support.standardizedFileURL
        let path=target.standardizedFileURL
        let expected=base.appendingPathComponent(directoryName,isDirectory:true)
            .standardizedFileURL
        let clinical=base.appendingPathComponent(clinicalDirectoryName,isDirectory:true)
            .standardizedFileURL
        return path==expected && path != clinical &&
               path.deletingLastPathComponent()==base &&
               path.lastPathComponent==directoryName
    }
}
