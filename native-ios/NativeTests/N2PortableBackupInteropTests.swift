import XCTest
import Foundation
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
    func testUnsafePasswordAndPlaintextAreRejected() throws {
        XCTAssertThrowsError(try N2NativePortableBackupMaker.createVerified(
            snapshot:try sample(),password:"short"))
        XCTAssertThrowsError(try N2NativePortableBackupMaker.createVerified(
            snapshot:Data("UNENCRYPTED".utf8),
            password:"long-and-safe-test-password"))
    }
}
