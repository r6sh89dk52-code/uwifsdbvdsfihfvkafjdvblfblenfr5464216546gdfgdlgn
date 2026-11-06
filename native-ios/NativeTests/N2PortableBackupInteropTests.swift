import XCTest
import Foundation
import DanperCore
import UIKit
import UniformTypeIdentifiers
@testable import DANPERNative

final class N2PortableBackupInteropTests:XCTestCase {
    private func sample() throws -> Data {
        let source:[String:Any] = [
            "workers":[["dni":"00000001","name":"PERSONA FICTICIA PRUEBA",
                        "area":"CAMPO","labor":"PRUEBA","sex":"F",
                        "age":"24","ubigeo":""]],
            "attentions":[],"allergies":[String:Any](),
            "notifications":false,
            "stockLots":[],"stockMovements":[],"catalogMappings":[],
            "deliveryIncidents":[],"ambulatoryReconciliation":[]
        ]
        return try JSONSerialization.data(withJSONObject:source)
    }
    func testNativeEncryptedBackupCanBeReadByExistingBuild222Reader() throws {
        let source=try sample()
        let password="N2-backup-validation-2026!"
        let encrypted=try N2NativePortableBackupMaker.createVerified(
            snapshot:source,password:password)
        let header=try XCTUnwrap(JSONSerialization.jsonObject(
            with:encrypted) as? [String:Any])
        XCTAssertEqual(header["format"] as? String,"DANPER-SALUD-PORTABLE-BACKUP")
        XCTAssertEqual(header["version"] as? Int,1)
        XCTAssertEqual(header["iterations"] as? Int,310000)
        XCTAssertEqual(header["kdf"] as? String,"PBKDF2-SHA256")
        XCTAssertEqual(header["cipher"] as? String,"AES-256-GCM")
        XCTAssertNil(header["workers"])
        let url=FileManager.default.temporaryDirectory
            .appendingPathComponent("n2-portable-"+UUID().uuidString+".danperbackup")
        try encrypted.write(to:url,options:.atomic)
        defer{try? FileManager.default.removeItem(at:url)}
        let copied=try N2BackupPickerCopy.stage(url)
        XCTAssertNotEqual(copied,url)
        XCTAssertEqual(try Data(contentsOf:copied),encrypted)
        let audited=try PortableBackupInspector.audit(url:copied,password:password)
        N2BackupPickerCopy.discard(copied)
        XCTAssertFalse(FileManager.default.fileExists(atPath:copied.path))
        XCTAssertEqual(try Data(contentsOf:url),encrypted)
        XCTAssertEqual(audited.manifest.workers,1)
        XCTAssertEqual(audited.manifest.attentions,0)
        XCTAssertThrowsError(try PortableBackupInspector.audit(
            url:url,password:"This-is-a-wrong-14-char-password"))
    }
    func testExplicitSyntheticN2ActivationEnablesClinicalTabsWithoutRealBackup() async throws {
        let before=try await N2SyntheticTrialIOSVault.shared.inspect()
        let clinicalBefore=try await N2ProtectedClinicalIOSVault.shared.inspect()
        let created:N2ProtectedStoreSummary
        if let before {created=before}
        else {created=try await N2SyntheticTrialIOSVault.shared.startEmptyDemo()}
        XCTAssertEqual(created.workers,0)
        XCTAssertEqual(created.attentions,0)
        XCTAssertEqual(created.physicalMovements,0)
        XCTAssertEqual(created.revision,before?.revision ?? 1)
        let model=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
        XCTAssertEqual(model.workers.count,0)
        XCTAssertEqual(model.products.clinical.count,432)
        XCTAssertEqual(model.products.nursing.count,98)
        XCTAssertEqual(model.revision,created.revision)
        let reopened=try await N2SyntheticTrialIOSVault.shared.inspect()
        let again=try XCTUnwrap(reopened)
        XCTAssertEqual(again.revision,created.revision)
        do {
            _=try await N2SyntheticTrialIOSVault.shared.startEmptyDemo()
            XCTFail("No debe reemplazar una fuente ya activada")
        } catch N2SyntheticTrialIOSVault.Failure.blockedMigration {}
        // The fictional startup does not create or import the protected
        // clinical vault of the old build222 or native real-source flow.
        let actualRealSource=try await N2ProtectedClinicalIOSVault.shared.inspect()
        XCTAssertEqual(actualRealSource?.revision,clinicalBefore?.revision)
        XCTAssertEqual(actualRealSource?.workers,clinicalBefore?.workers)
        XCTAssertEqual(actualRealSource?.attentions,clinicalBefore?.attentions)
    }
    func testBuild222EncryptedSourceReviewCannotBeChangedBeforeRestore() throws {
        // An entirely invented identity, only in an ephemeral XCTest archive.
        let source:[String:Any]=[
            "workers":[["dni":"87654321","name":"Mariana Torres Salazar",
                        "area":"Prueba","labor":"Operaria","sex":"F","age":"27",
                        "ubigeo":"","site":"PLVENTUROSA"]],
            "attentions":[],"allergies":[String:Any](),
            "notifications":false,
            "stockLots":[],"stockMovements":[],"catalogMappings":[],
            "deliveryIncidents":[],"ambulatoryReconciliation":[]
        ]
        let snapshot=try JSONSerialization.data(withJSONObject:source)
        let pass="N2-interop-synthetic-backup-2026"
        let first=try N2NativePortableBackupMaker.createVerified(
            snapshot:snapshot,password:pass)
        let file=FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString+".danperbackup")
        try first.write(to:file,options:.atomic)
        defer{try? FileManager.default.removeItem(at:file)}
        let review=try PortableBackupInspector.review(url:file,password:pass)
        XCTAssertTrue(review.canRestore)
        XCTAssertEqual(review.audit.manifest.workers,1)
        XCTAssertEqual(review.audit.manifest.attentions,0)
        XCTAssertEqual(review.audit.manifest.movements,0)
        XCTAssertEqual(review.audit.manifest.lots,0)
        XCTAssertEqual(review.encryptedSHA256.count,64)
        XCTAssertThrowsError(try PortableBackupInspector.review(
            url:file,password:"completely-different-passphrase"))
        let second=try N2NativePortableBackupMaker.createVerified(
            snapshot:snapshot,password:pass)
        try second.write(to:file,options:.atomic)
        let changed=try PortableBackupInspector.review(url:file,password:pass)
        XCTAssertNotEqual(changed.encryptedSHA256,review.encryptedSHA256,
                          "A differently encrypted archive must force a new review")
    }
    func testFullSyntheticClinicalBackupPreservesPhysicalHistoryAcrossReview()throws {
        let fixture=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"n2-synthetic-clinical",
                   withExtension:"json",subdirectory:"SyntheticFixtures"))
        let raw=try Data(contentsOf:fixture)
        let original=try N1eLegacyClinicalAudit.inspect(raw)
        let pass="N2-interop-full-clinical-backup-2026"
        let file=FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString+".danperbackup")
        let sealed=try N2NativePortableBackupMaker.createVerified(
            snapshot:raw,password:pass)
        try sealed.write(to:file,options:.atomic)
        defer {try? FileManager.default.removeItem(at:file)}
        let review=try PortableBackupInspector.review(url:file,password:pass)
        let originalAudit=try N1lRealSnapshotGate.audit(
            raw,destination:.verifiedEmpty)
        XCTAssertEqual(review.audit.semanticSHA256,originalAudit.semanticSHA256,
                       "El árbol completo debe conservar todos los campos y consumos")
        XCTAssertEqual(review.audit.manifest.workers,original.workers)
        XCTAssertEqual(review.audit.manifest.attentions,original.attentions)
        XCTAssertEqual(review.audit.manifest.movements,original.physicalMovements)
        XCTAssertEqual(review.audit.manifest.lots,original.stockLots)
        XCTAssertEqual(review.audit.unresolvedClinicalConsumptions,
                       original.pendingClinicalItems)
        // The source fixture includes provisional clinical consumptions. They
        // must stay pending; no physical movement is invented by reviewing.
    }
    @MainActor func testPickerDelegateDeliversProtectedCopyAndReportsEmptySelection() throws {
        let original=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".danperbackup")
        let bytes=Data(repeating:65,count:120)
        try bytes.write(to:original)
        defer {try? FileManager.default.removeItem(at:original)}
        var received:URL?,failure="",cancelled=false
        let picker=N2BackupDocumentPicker(onPicked:{received=$0},
            onCancelled:{cancelled=true},onError:{failure=$0})
        let delegate=picker.makeCoordinator()
        let controller=UIDocumentPickerViewController(forOpeningContentTypes:[.item],asCopy:true)
        delegate.documentPicker(controller,didPickDocumentsAt:[original])
        let copied=try XCTUnwrap(received)
        defer {N2BackupPickerCopy.discard(copied)}
        XCTAssertNotEqual(copied,original)
        XCTAssertEqual(try Data(contentsOf:copied),bytes)
        XCTAssertEqual(try Data(contentsOf:original),bytes)
        delegate.documentPicker(controller,didPickDocumentsAt:[])
        XCTAssertTrue(failure.hasPrefix("BACKUP_PICKER_EMPTY"))
        delegate.documentPickerWasCancelled(controller)
        XCTAssertTrue(cancelled)
    }
    func testSharedImportRejectsRemoteWrongExtensionSymlinkAndOversizeWithoutChangingOriginal() throws {
        XCTAssertThrowsError(try N2BackupPickerCopy.stage(URL(string:"https://example.invalid/file.danperbackup")!))
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:folder)}
        let wrong=folder.appendingPathComponent("file.txt")
        try Data(repeating:65,count:120).write(to:wrong)
        XCTAssertThrowsError(try N2BackupPickerCopy.stage(wrong))
        let link=folder.appendingPathComponent("link.danperbackup")
        try FileManager.default.createSymbolicLink(at:link,withDestinationURL:wrong)
        XCTAssertThrowsError(try N2BackupPickerCopy.stage(link))
        let large=folder.appendingPathComponent("large.danperbackup")
        FileManager.default.createFile(atPath:large.path,contents:nil)
        let handle=try FileHandle(forWritingTo:large)
        try handle.truncate(atOffset:UInt64(42*1024*1024+1));try handle.close()
        XCTAssertThrowsError(try N2BackupPickerCopy.stage(large))
        XCTAssertEqual(try Data(contentsOf:wrong).count,120)
    }
    func testInstalledAppRegistersBackupDocumentForFilesOpenIn() throws {
        let info=try XCTUnwrap(Bundle.main.infoDictionary)
        let declarations=try XCTUnwrap(info["UTExportedTypeDeclarations"] as? [[String:Any]])
        let declaration=try XCTUnwrap(declarations.first{$0["UTTypeIdentifier"] as? String == "pe.danper.saludmovil.backup"})
        let tags=try XCTUnwrap(declaration["UTTypeTagSpecification"] as? [String:Any])
        XCTAssertEqual(tags["public.filename-extension"] as? [String],["danperbackup"])
        let documents=try XCTUnwrap(info["CFBundleDocumentTypes"] as? [[String:Any]])
        XCTAssertTrue(documents.contains{($0["LSItemContentTypes"] as? [String])?.contains("pe.danper.saludmovil.backup")==true})
        XCTAssertEqual(UTType(filenameExtension:"danperbackup")?.identifier,"pe.danper.saludmovil.backup")
    }
    func testUnsafePasswordAndPlaintextAreRejected() throws {
        XCTAssertThrowsError(try N2NativePortableBackupMaker.createVerified(
            snapshot:try sample(),password:"short"))
        XCTAssertThrowsError(try N2NativePortableBackupMaker.createVerified(
            snapshot:Data("UNENCRYPTED".utf8),
            password:"long-and-safe-test-password"))
    }
}
