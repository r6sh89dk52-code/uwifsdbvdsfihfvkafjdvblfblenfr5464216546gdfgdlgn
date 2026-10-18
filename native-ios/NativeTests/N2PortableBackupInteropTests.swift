import XCTest
import Foundation
import DanperCore
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
        let audited=try PortableBackupInspector.audit(url:url,password:password)
        XCTAssertEqual(audited.manifest.workers,1)
        XCTAssertEqual(audited.manifest.attentions,0)
        XCTAssertThrowsError(try PortableBackupInspector.audit(
            url:url,password:"This-is-a-wrong-14-char-password"))
    }
    func testExplicitSyntheticN2ActivationEnablesClinicalTabsWithoutRealBackup() async throws {
        // CI deliberately builds the Simulator app without code signing.
        // On that runner, Security.framework can refuse Keychain with
        // errSecMissingEntitlement (-34018). Do not treat this as a passed
        // iPhone/SideStore Keychain test: the encrypted core still has its
        // independent Swift tests, and physical-device Keychain must be checked.
        let before:N2ProtectedStoreSummary?
        let created:N2ProtectedStoreSummary
        do {
            before=try await N2SyntheticTrialIOSVault.shared.inspect()
            created=try await N2SyntheticTrialIOSVault.shared.startSyntheticDemo()
        } catch N2SyntheticTrialIOSVault.Failure.keychainStatus(let status)
            where status == -34018 {
            throw XCTSkip("Simulador sin firmar carece de entitlement Keychain (-34018); requiere validación con app firmada en iPhone")
        }
        XCTAssertEqual(created.workers,5)
        XCTAssertEqual(created.revision,before?.revision ?? 1)
        let model=try await N2SyntheticTrialIOSVault.shared.clinicalFormContext()
        XCTAssertEqual(model.workers.count,5)
        XCTAssertEqual(model.products.clinical.count,432)
        XCTAssertEqual(model.products.nursing.count,98)
        XCTAssertEqual(model.revision,created.revision)
        let again=try await N2SyntheticTrialIOSVault.shared.startSyntheticDemo()
        XCTAssertEqual(again.revision,created.revision)
        // The fictional startup does not create or import the protected
        // clinical vault of the old build222 or native real-source flow.
        let actualRealSource=try await N2ProtectedClinicalIOSVault.shared.inspect()
        XCTAssertNil(actualRealSource)
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
        guard let fixture=Bundle.main.url(forResource:"n1e-clinical-stock",
                   withExtension:"json",subdirectory:"N1sDemoResources") else{
            throw XCTSkip("Clinical demo resource not bundled in this host")
        }
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
        XCTAssertEqual(review.audit.manifest.workers,original.workers)
        XCTAssertEqual(review.audit.manifest.attentions,original.attentions)
        XCTAssertEqual(review.audit.manifest.movements,original.physicalMovements)
        XCTAssertEqual(review.audit.manifest.lots,original.stockLots)
        XCTAssertEqual(review.audit.unresolvedClinicalConsumptions,
                       original.pendingClinicalItems)
        // The source fixture includes provisional clinical consumptions. They
        // must stay pending; no physical movement is invented by reviewing.
    }
    func testUnsafePasswordAndPlaintextAreRejected() throws {
        XCTAssertThrowsError(try N2NativePortableBackupMaker.createVerified(
            snapshot:try sample(),password:"short"))
        XCTAssertThrowsError(try N2NativePortableBackupMaker.createVerified(
            snapshot:Data("UNENCRYPTED".utf8),
            password:"long-and-safe-test-password"))
    }
}
