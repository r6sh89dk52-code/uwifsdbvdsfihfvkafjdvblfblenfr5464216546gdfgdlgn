import Foundation
import XCTest
@testable import DANPERNative

final class N2BackupDocumentPickerTests:XCTestCase {
    func testEncryptedBackupSelectionUsesProtectedCopyWithoutChangingSource()throws {
        let bytes=Data(repeating:0x42,count:512)
        let original=FileManager.default.temporaryDirectory
            .appendingPathComponent("outside-backup-"+UUID().uuidString+".danperbackup")
        try bytes.write(to:original,options:.atomic)
        defer{try? FileManager.default.removeItem(at:original)}
        let imported=try N2BackupPickerCopy.stage(original)
        XCTAssertNotEqual(imported,original)
        XCTAssertTrue(FileManager.default.fileExists(atPath:imported.path))
        XCTAssertEqual(try Data(contentsOf:imported),bytes)
        N2BackupPickerCopy.discard(imported)
        XCTAssertFalse(FileManager.default.fileExists(atPath:imported.path))
        XCTAssertEqual(try Data(contentsOf:original),bytes)
    }
    func testInvalidBackupTypesAreRejectedWithoutTouchingFiles()throws {
        let original=FileManager.default.temporaryDirectory
            .appendingPathComponent("not-danper-"+UUID().uuidString+".txt")
        try Data(repeating:0x4d,count:512).write(to:original,options:.atomic)
        defer{try? FileManager.default.removeItem(at:original)}
        XCTAssertThrowsError(try N2BackupPickerCopy.stage(original))
        XCTAssertTrue(FileManager.default.fileExists(atPath:original.path))
        let empty=FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-"+UUID().uuidString+".danperbackup")
        try Data(repeating:0x11,count:10).write(to:empty,options:.atomic)
        defer{try? FileManager.default.removeItem(at:empty)}
        XCTAssertThrowsError(try N2BackupPickerCopy.stage(empty))
        XCTAssertTrue(FileManager.default.fileExists(atPath:empty.path))
    }
}
