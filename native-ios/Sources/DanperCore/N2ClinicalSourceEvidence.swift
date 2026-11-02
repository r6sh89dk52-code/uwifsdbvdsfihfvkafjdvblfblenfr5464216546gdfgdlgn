import Foundation

/// File evidence only, never authorization or proof of clinical integrity.
/// Unknown/inaccessible storage must continue through protected inspection.
public enum N2ClinicalSourceEvidence {
    public static func hasFiles(at directory:URL)->Bool {
        do {
            return !(try FileManager.default.contentsOfDirectory(atPath:directory.path)).isEmpty
        } catch {
            return !isConfirmedAbsence(error as NSError)
        }
    }

    static func isConfirmedAbsence(_ error:NSError)->Bool {
        let missing=Int(POSIXErrorCode.ENOENT.rawValue)
        if error.domain==NSPOSIXErrorDomain {return error.code==missing}
        guard error.domain==NSCocoaErrorDomain,
              [CocoaError.fileNoSuchFile.rawValue,CocoaError.fileReadNoSuchFile.rawValue].contains(error.code)
        else{return false}
        if let underlying=error.userInfo[NSUnderlyingErrorKey] as? NSError {
            // Cocoa's broad "not found" category must not conceal EACCES,
            // ENOTDIR, or another underlying filesystem error.
            return underlying.domain==NSPOSIXErrorDomain && underlying.code==missing
        }
        return true
    }
}
