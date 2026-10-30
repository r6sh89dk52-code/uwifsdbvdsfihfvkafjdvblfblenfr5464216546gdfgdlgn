import Foundation
import XCTest
@testable import DanperCore

/// Consumes encrypted files actually produced by the frozen Build 14 code.
final class N2Build14ForwardCompatibilityTests:XCTestCase {
    func testBuild14EncryptedJournalAndBackupUpgradeWithoutStockOrHistoryLoss()throws {
        let env=ProcessInfo.processInfo.environment
        let source=URL(fileURLWithPath:try XCTUnwrap(env["DANPER_BUILD14_FIXTURE_OUT"]))
        let proof=try XCTUnwrap(JSONSerialization.jsonObject(with:Data(contentsOf:source.appendingPathComponent("build14-fixture.json"))) as? [String:Any])
        XCTAssertEqual(proof["producerSHA"] as? String,"9b1da6d4cdead4729bcade6843abcbcfc287e870")
        XCTAssertEqual(proof["onlyFictionalData"] as? Bool,true)
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("danper-n2-synthetic-upgrade-"+UUID().uuidString)
        try FileManager.default.copyItem(at:source.appendingPathComponent("journal"),to:folder)
        defer {try? FileManager.default.removeItem(at:folder)}
        let journal=try N2EncryptedClinicalJournal(directory:folder,secret:Data(repeating:0xB4,count:32))
        let recovered=try XCTUnwrap(journal.recover())
        XCTAssertEqual(recovered.revision,1)
        XCTAssertEqual(N2SimpleInventory.digest(recovered.snapshot),proof["snapshotSHA256"] as? String)
        let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
        let originalStock=try encoder.encode(N2SimpleInventory.read(recovered.snapshot))
        XCTAssertEqual(N2SimpleInventory.digest(originalStock),proof["stockSHA256"] as? String)
        let archive=try Data(contentsOf:source.appendingPathComponent("build14-fictional.danperbackup"))
        XCTAssertEqual(N2SimpleInventory.digest(archive),proof["backupSHA256"] as? String)
        let password="FICTICIO-Respaldo-Seguro-2026"
        let oldBackup=try N2InventoryBackupCodec.verify(archive:archive,password:password)
        XCTAssertEqual(oldBackup.schemaVersion,2);XCTAssertEqual(oldBackup.domain,.demo)
        XCTAssertEqual(oldBackup.snapshot,recovered.snapshot)
        let before=try N2SimpleInventory.object(recovered.snapshot)
        let detail=try N2ClinicalCorrections.detail(snapshot:recovered.snapshot,visitID:"planta-open")
        let corrected=try N2ClinicalCorrections.append(snapshot:recovered.snapshot,eventID:UUID().uuidString,
            visitID:"planta-open",changes:JSONSerialization.data(withJSONObject:["itemHistoricalOpenings":["box-2":0]]),
            reason:"Rectificación ficticia de compatibilidad",operatorName:"OPERADOR FICTICIO",
            medicationDiscrepancy:"",expectedEffectiveSHA:detail.effectiveSHA256,at:1795114800000)
        _=try journal.commit(corrected,expectedRevision:1)
        let store=N2ProtectedClinicalVaultCore(testJournal:journal,directory:folder)
        XCTAssertEqual(try store.reviewAllergiesRevision(dni:"00000001",status:"none",substances:"",
            at:1795114800100,expectedRevision:2),3)
        let reopened=try N2EncryptedClinicalJournal(directory:folder,secret:Data(repeating:0xB4,count:32))
        let after=try XCTUnwrap(reopened.recover())
        XCTAssertEqual(try encoder.encode(N2SimpleInventory.read(after.snapshot)),originalStock)
        let final=try N2SimpleInventory.object(after.snapshot)
        for field in ["workers","attentions","simpleInventory","stockLots","stockMovements"] {
            XCTAssertEqual(try JSONSerialization.data(withJSONObject:before[field]!,options:.sortedKeys),
                try JSONSerialization.data(withJSONObject:final[field]!,options:.sortedKeys),field)
        }
        XCTAssertEqual(try N2ClinicalCorrections.detail(snapshot:after.snapshot,visitID:"planta-open")
            .medications.first{$0.id=="box-2"}?.historicalOpeningR,0)
        let fresh=try N2InventoryBackupCodec.createVerified(snapshot:after.snapshot,password:password,domain:.demo)
        XCTAssertEqual(try N2InventoryBackupCodec.verify(archive:fresh,password:password).snapshot,after.snapshot)
        let result:[String:Any]=["sourceSHA":try XCTUnwrap(env["DANPER_COMPAT_CONSUMER_SHA"]),
            "producerSHA":"9b1da6d4cdead4729bcade6843abcbcfc287e870","tests":1,"failures":0,
            "build14JournalRead":true,"build14BackupRead":true,"stockUnchanged":true,
            "workersAndOriginalVisitsUnchanged":true,"historicalRectificationPersisted":true,
            "newBackupRoundTrip":true,"physicalDeviceValidated":false]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
            .write(to:source.deletingLastPathComponent().appendingPathComponent("compatibility.json"))
    }
}
