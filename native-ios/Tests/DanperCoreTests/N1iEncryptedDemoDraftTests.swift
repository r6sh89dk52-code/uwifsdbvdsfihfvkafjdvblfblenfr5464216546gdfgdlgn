import Foundation
import Crypto
import XCTest
@testable import DanperCore

final class N1iEncryptedDemoDraftTests: XCTestCase {
    private enum SyntheticCrash: Error { case triggered }
    private let key = Data(repeating:0x42,count:32)
    private let wrongKey = Data(repeating:0x70,count:32)
    private func folder() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "danper-n1i-synthetic-" + UUID().uuidString)
    }
    private func vault(_ root:URL, key:Data? = nil) throws -> N1iEncryptedDemoDraftVault {
        try N1iEncryptedDemoDraftVault(root:root,keyData:key ?? self.key)
    }
    private func fakeClinic() throws -> (N1gClinic,UUID) {
        var clinic=N1gClinic()
        let visit=clinic.newDraft(at:100)
        try clinic.edit(visit,.worker("00000001"),at:101)
        try clinic.edit(visit,.category("ENFERMEDAD"),at:102)
        try clinic.edit(visit,.system("RESPIRATORIO"),at:103)
        try clinic.edit(visit,.diagnosis("CEFALEA FICTICIA"),at:104)
        try clinic.edit(visit,.procedure("OBSERVACION"),at:105)
        try clinic.edit(visit,.product("INSUMO FICTICIO A · UND"),at:106)
        try clinic.edit(visit,.quantity(2),at:107)
        try clinic.reviewAllergy(.none,for:"00000001")
        return (clinic,visit)
    }
    func testEncryptedRoundtripPreservesEveryDraftDetailAndAllergy() throws {
        let root=folder();defer{try? FileManager.default.removeItem(at:root)}
        let (original,id)=try fakeClinic()
        let store=try vault(root)
        XCTAssertNil(try store.load())
        try store.save(original)
        let content=try Data(contentsOf:root.appendingPathComponent(
            try XCTUnwrap(FileManager.default.contentsOfDirectory(atPath:root.path)
                .first(where:{$0.hasSuffix(".gcm")}))))
        XCTAssertNil(content.range(of:Data("CEFALEA FICTICIA".utf8)))
        XCTAssertNil(content.range(of:Data("DANPER-N1I-DEMO-ONLY".utf8)))
        let reopened=try XCTUnwrap(try vault(root).load())
        XCTAssertEqual(reopened.activeDraftID,id)
        XCTAssertEqual(reopened.activeDraft?.quantity,2)
        XCTAssertEqual(reopened.activeDraft?.detailed.system,"RESPIRATORIO")
        XCTAssertEqual(reopened.allergies["00000001"],N1gAllergy.none)
        XCTAssertEqual(reopened.workers, original.workers)
        XCTAssertEqual(reopened.visits, original.visits)
        XCTAssertEqual(reopened.allergies, original.allergies)
        XCTAssertEqual(reopened.activeDraftID, original.activeDraftID)
        // JSON object-key order is not a clinical field: compare the
        // fully decoded data model, not nondeterministic Dictionary bytes.
        XCTAssertEqual(reopened.physicalMovementsCreated,0)
    }
    func testSavedAndCorrectionRemainSeparateAfterRestart() throws {
        let root=folder();defer{try? FileManager.default.removeItem(at:root)}
        var (clinic,id)=try fakeClinic()
        try clinic.saveDemo(id,at:300)
        let draft=try clinic.correctionDraft(of:id,at:301)
        try clinic.edit(draft,.diagnosis("CONTROL FICTICIO"),at:302)
        try vault(root).save(clinic)
        var loaded=try XCTUnwrap(try vault(root).load())
        XCTAssertEqual(loaded.saved.first?.diagnosis,"CEFALEA FICTICIA")
        XCTAssertEqual(loaded.drafts.first?.originID,id)
        XCTAssertEqual(loaded.drafts.first?.diagnosis,"CONTROL FICTICIO")
        XCTAssertThrowsError(try loaded.saveDemo(draft,at:303))
    }
    func testMissingPointerBeforeFirstCommitIsRecoverableAsEmpty() throws {
        let root=folder();defer{try? FileManager.default.removeItem(at:root)}
        let (state,_)=try fakeClinic()
        let store=try vault(root)
        XCTAssertThrowsError(try store.save(state,fault:{p in
            if p == .ciphertextWritten { throw SyntheticCrash.triggered }
        }))
        XCTAssertNil(try vault(root).load())
        XCTAssertThrowsError(try store.save(state,fault:{p in
            if p == .ciphertextVerified { throw SyntheticCrash.triggered }
        }))
        XCTAssertNil(try vault(root).load())
        try store.save(state)
        XCTAssertNotNil(try vault(root).load())
    }
    func testCrashBeforePointerRetainsPreviousValidGeneration() throws {
        let root=folder();defer{try? FileManager.default.removeItem(at:root)}
        var (state,id)=try fakeClinic()
        let store=try vault(root)
        try store.save(state)
        try state.edit(id,.quantity(9),at:200)
        XCTAssertThrowsError(try store.save(state,fault:{p in
            if p == .ciphertextVerified { throw SyntheticCrash.triggered }
        }))
        XCTAssertEqual(try vault(root).load()?.activeDraft?.quantity,2)
    }
    func testCrashAfterPointerRecoversNewVersion() throws {
        let root=folder();defer{try? FileManager.default.removeItem(at:root)}
        var (state,id)=try fakeClinic()
        let store=try vault(root)
        try store.save(state)
        try state.edit(id,.quantity(7),at:210)
        XCTAssertThrowsError(try store.save(state,fault:{p in
            if p == .pointerWritten { throw SyntheticCrash.triggered }
        }))
        XCTAssertEqual(try vault(root).load()?.activeDraft?.quantity,7)
    }
    func testWrongKeyAndMalformedKeyCannotOpenOrOverwrite() throws {
        let root=folder();defer{try? FileManager.default.removeItem(at:root)}
        let (state,_)=try fakeClinic()
        try vault(root).save(state)
        let wrong=try vault(root,key:wrongKey)
        XCTAssertThrowsError(try wrong.load())
        XCTAssertThrowsError(try wrong.save(state))
        XCTAssertThrowsError(try vault(root,key:Data(repeating:0x02,count:16)))
        XCTAssertNotNil(try vault(root).load())
    }
    func testTamperedCiphertextAndPointerFailClosed() throws {
        let root=folder();defer{try? FileManager.default.removeItem(at:root)}
        let (state,_)=try fakeClinic()
        let store=try vault(root)
        try store.save(state)
        let files=try FileManager.default.contentsOfDirectory(atPath:root.path)
        let encrypted=try XCTUnwrap(files.first(where:{$0.hasSuffix(".gcm")}))
        let encURL=root.appendingPathComponent(encrypted)
        var bytes=try Data(contentsOf:encURL)
        bytes[12] ^= 0x01
        try bytes.write(to:encURL,options:.atomic)
        XCTAssertThrowsError(try vault(root).load())
        XCTAssertThrowsError(try store.save(state))
        // Independently, a malformed pointer is never interpreted as empty.
        try Data("{}".utf8).write(to:root.appendingPathComponent(
            "active-demo-draft.json"),options:.atomic)
        XCTAssertThrowsError(try vault(root).load())
    }
    func testConcurrentPointerChangeAbortsWithoutOverwrite() throws {
        let root=folder();defer{try? FileManager.default.removeItem(at:root)}
        let (state,_)=try fakeClinic()
        let first=try vault(root),second=try vault(root)
        try first.save(state)
        XCTAssertThrowsError(try first.save(state,fault:{p in
            if p == .ciphertextVerified { try second.save(state) }
        })) { e in
            XCTAssertEqual(e as? N1iEncryptedDemoDraftVault.Failure,.conflictingCommit)
        }
        XCTAssertNotNil(try vault(root).load())
    }
    func testRejectsNonFictionalWorkerOrUnknownClinicalPayload() throws {
        let (clinic,_)=try fakeClinic()
        let good=try clinic.exportFictionalDrafts()
        XCTAssertNotNil(try N1iDemoArchiveCodec.decode(good).activeDraft)
        XCTAssertThrowsError(try N1iDemoArchiveCodec.decode(Data(
            "actual clinical patient record".utf8)))
        let header=Data(N1iDemoArchiveCodec.marker.utf8)
        var obj=try JSONSerialization.jsonObject(with:good.dropFirst(header.count)) as! [String:Any]
        var roster=obj["workers"] as! [[String:Any]]
        roster[0]["name"]="PERSONA VERDADERA"
        obj["workers"]=roster
        let altered=header + (try JSONSerialization.data(withJSONObject:obj))
        XCTAssertThrowsError(try N1iDemoArchiveCodec.decode(altered))
        var sessions=obj["visits"] as! [[String:Any]]
        sessions[0]["diagnosis"]="DIAGNOSTICO NO FICTICIO"
        obj["visits"]=sessions
        XCTAssertThrowsError(try N1iDemoArchiveCodec.decode(
            header + (try JSONSerialization.data(withJSONObject:obj))))
    }
    func testCannotWriteOutsideDedicatedDemoArea() throws {
        let root=FileManager.default.temporaryDirectory
            .appendingPathComponent("DANPER-REAL-CLINICAL")
        XCTAssertThrowsError(try vault(root))
        XCTAssertFalse(FileManager.default.fileExists(atPath:root.path))
    }
}
