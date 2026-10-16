import Foundation
import XCTest
@testable import DanperCore

final class N1PortableInteropTests: XCTestCase {
    private let password = "N1-SINTETICO-EXCLUSIVO-2026!"
    private func directory() throws -> URL {
        guard let name = ProcessInfo.processInfo.environment["DANPER_N1_FIXTURE_DIR"],
              !name.isEmpty else {
            throw XCTSkip("Fixture TypeScript no creada: ejecute scripts/generate-native-compat-fixtures.cjs")
        }
        return URL(fileURLWithPath: name, isDirectory: true)
    }
    private func archive(_ name: String) throws -> Data {
        try Data(contentsOf: directory().appendingPathComponent(name))
    }

    func testRealTypeScriptCipherCanBeDecryptedBySwiftCrypto() throws {
        let encrypted = try archive("synthetic.danperbackup")
        let metadata = try Data(contentsOf: directory().appendingPathComponent("synthetic.meta.json"))
        struct Meta: Decodable { let plaintextSHA256: String; let plaintextByteCount: Int }
        let expected = try JSONDecoder().decode(Meta.self, from: metadata)
        let result = try N1PortableArchiveReader.inspect(archive: encrypted, password: password)
        XCTAssertEqual(result.plaintextSHA256, expected.plaintextSHA256)
        XCTAssertEqual(result.plaintextByteCount, expected.plaintextByteCount)
        XCTAssertEqual(result.manifest.workers, 2)
        XCTAssertEqual(result.manifest.attentions, 1)
        XCTAssertEqual(result.manifest.allergies, 1)
        XCTAssertEqual(result.manifest.lots, 1)
        XCTAssertEqual(result.manifest.movements, 1)
        XCTAssertEqual(result.manifest.unresolvedClinicalItems, 1)
        XCTAssertEqual(result.manifest.catalogMappings, 1)
        XCTAssertEqual(result.manifest.deliveryIncidents, 1)
        XCTAssertEqual(result.manifest.ambulatoryReconciliation, 1)
        XCTAssertTrue(result.manifest.notificationsEnabled)
    }
    func testWrongPasswordFailsAuthenticatedDecryption() throws {
        XCTAssertThrowsError(try N1PortableArchiveReader.inspect(
            archive: archive("synthetic.danperbackup"),
            password: "Contraseña-Ficticia-Incorrecta-2026")) { error in
            XCTAssertEqual(error as? N1PortableArchiveError, .authenticationFailed)
        }
    }
    func testTamperedCiphertextIsRejected() throws {
        XCTAssertThrowsError(try N1PortableArchiveReader.inspect(
            archive: archive("tampered.danperbackup"), password: password)) { error in
            XCTAssertEqual(error as? N1PortableArchiveError, .authenticationFailed)
        }
    }
    func testKDFDowngradeIsRejectedBeforeDecrypt() throws {
        XCTAssertThrowsError(try N1PortableArchiveReader.inspect(
            archive: archive("downgraded.danperbackup"), password: password)) { error in
            XCTAssertEqual(error as? N1PortableArchiveError, .unsupportedEnvelope)
        }
    }
    func testShortPasswordRejected() throws {
        XCTAssertThrowsError(try N1PortableArchiveReader.inspect(
            archive: archive("synthetic.danperbackup"), password: "short")) { error in
            XCTAssertEqual(error as? N1PortableArchiveError, .invalidPassword)
        }
    }
}
