import Foundation
import XCTest
@testable import DanperCore

final class N2ClinicalSourceEvidenceTests:XCTestCase {
    func testMissingAndEmptyDirectoriesHaveNoClinicalFileEvidence() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("DANPER-B15-SYNTHETIC-EVIDENCE-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        XCTAssertFalse(N2ClinicalSourceEvidence.hasFiles(at:root))
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        XCTAssertFalse(N2ClinicalSourceEvidence.hasFiles(at:root))
    }

    func testAnyFileAndNondirectoryRootRetainProtectedInspection() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("DANPER-B15-SYNTHETIC-EVIDENCE-"+UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let marker=root.appendingPathComponent("fictitious-unrecognized-file")
        try Data("FICTIONAL; not a clinical vault".utf8).write(to:marker)
        XCTAssertTrue(N2ClinicalSourceEvidence.hasFiles(at:root))
        XCTAssertTrue(N2ClinicalSourceEvidence.hasFiles(at:marker))
    }

    func testPermissionAndUnrecognizedErrorsAreNotAbsence() {
        for error in [NSError(domain:NSCocoaErrorDomain,code:CocoaError.fileReadNoPermission.rawValue),
                      NSError(domain:NSPOSIXErrorDomain,code:Int(POSIXErrorCode.EACCES.rawValue)),
                      NSError(domain:NSPOSIXErrorDomain,code:Int(POSIXErrorCode.ENOTDIR.rawValue)),
                      NSError(domain:"unrecognized-storage-provider",code:CocoaError.fileReadNoSuchFile.rawValue)] {
            XCTAssertFalse(N2ClinicalSourceEvidence.isConfirmedAbsence(error))
        }
    }

    func testCocoaMissingErrorCannotHideUnderlyingAccessOrDirectoryFailure() {
        for code in [POSIXErrorCode.EACCES,POSIXErrorCode.ENOTDIR] {
            let underlying=NSError(domain:NSPOSIXErrorDomain,code:Int(code.rawValue))
            let error=NSError(domain:NSCocoaErrorDomain,code:CocoaError.fileReadNoSuchFile.rawValue,
                userInfo:[NSUnderlyingErrorKey:underlying])
            XCTAssertFalse(N2ClinicalSourceEvidence.isConfirmedAbsence(error))
        }
        let missing=NSError(domain:NSPOSIXErrorDomain,code:Int(POSIXErrorCode.ENOENT.rawValue))
        let absent=NSError(domain:NSCocoaErrorDomain,code:CocoaError.fileReadNoSuchFile.rawValue,
            userInfo:[NSUnderlyingErrorKey:missing])
        XCTAssertTrue(N2ClinicalSourceEvidence.isConfirmedAbsence(absent))
        XCTAssertTrue(N2ClinicalSourceEvidence.isConfirmedAbsence(missing))
    }
}
