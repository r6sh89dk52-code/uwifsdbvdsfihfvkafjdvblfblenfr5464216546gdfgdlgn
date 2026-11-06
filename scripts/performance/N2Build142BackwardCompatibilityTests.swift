import Foundation
import XCTest
@testable import DanperCore

/// Compiled and executed by the frozen 14.1 implementation, not the candidate.
final class N2Build142BackwardCompatibilityTests:XCTestCase {
    func testOriginalBuild141ReadsAndPersistsUpdatedBuild142Backup()throws {
        let root=URL(fileURLWithPath:try XCTUnwrap(ProcessInfo.processInfo.environment["DANPER_BUILD14_FIXTURE_OUT"]))
        let archive=try Data(contentsOf:root.appendingPathComponent("build142-fictional.danperbackup"))
        let expected=try Data(contentsOf:root.appendingPathComponent("build142-expected-snapshot.json"))
        let verified=try N2InventoryBackupCodec.verify(archive:archive,password:"FICTICIO-Respaldo-Seguro-2026")
        XCTAssertEqual(verified.snapshot,expected);XCTAssertEqual(verified.schemaVersion,2)
        _=try N2VersionedSnapshotAudit.inspect(verified.snapshot)
        _=try N1fLosslessFieldGate.inspect(verified.snapshot)
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-build142-backward-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:folder)}
        let journal=try N2EncryptedClinicalJournal(directory:folder,secret:Data(repeating:0x42,count:32))
        XCTAssertEqual(try journal.commit(verified.snapshot,expectedRevision:0),1)
        XCTAssertEqual(try journal.recover()?.snapshot,expected)
        XCTAssertEqual(try N2ClinicalCorrections.detail(snapshot:expected,visitID:"planta-open").medications.first{$0.id=="box-2"}?.historicalOpeningR,0)
        try Data("PASS: original 14.1 reads, audits and persists 14.2 encrypted backup; synthetic only\n".utf8)
            .write(to:root.deletingLastPathComponent().appendingPathComponent("backward-compatibility.txt"))
    }
}
