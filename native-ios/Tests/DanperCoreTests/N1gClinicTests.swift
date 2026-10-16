import Foundation
import XCTest
@testable import DanperCore

final class N1gClinicTests: XCTestCase {
    private func prepared() throws -> (N1gClinic, UUID) {
        var c=N1gClinic()
        let id=c.newDraft(at:100)
        try c.edit(id,.worker("00000001"),at:101)
        try c.edit(id,.category("ENFERMEDAD"),at:102)
        try c.edit(id,.diagnosis("CEFALEA FICTICIA"),at:103)
        try c.edit(id,.procedure("OBSERVACION"),at:104)
        try c.reviewAllergy(.none,for:"00000001")
        return (c,id)
    }
    func testWorkerSearchAndFixedFictionalIds() throws {
        var c=N1gClinic()
        XCTAssertEqual(c.workers.map(\.id),["00000001","00000002"])
        XCTAssertEqual(c.search("PLVENTUROSA").count,1)
        let w=try c.addFictionalWorker()
        XCTAssertEqual(w.id,"00000003")
        XCTAssertTrue(w.name.contains("FICTICIA"))
        for _ in 0..<3 { try c.addFictionalWorker() }
        XCTAssertThrowsError(try c.addFictionalWorker())
    }
    func testCannotEnterRealWorkerOrFreeText() throws {
        var c=N1gClinic()
        let id=c.newDraft(at:1)
        XCTAssertThrowsError(try c.edit(id,.worker("12345678"),at:2))
        XCTAssertThrowsError(try c.edit(id,.diagnosis("REAL PATIENT"),at:2))
        XCTAssertThrowsError(try c.edit(id,.product("REAL MEDICINE"),at:2))
        XCTAssertThrowsError(try c.edit(id,.quantity(0),at:2))
        XCTAssertThrowsError(try c.edit(id,.quantity(21),at:2))
    }
    func testDraftSurvivesTabNavigationInSessionButNotNewState() throws {
        var c=N1gClinic()
        let id=c.newDraft(at:1)
        XCTAssertEqual(c.newDraft(at:2),id)
        try c.edit(id,.worker("00000002"),at:3)
        c.closeDraft()
        XCTAssertEqual(c.drafts.map(\.id),[id])
        try c.openDraft(id)
        XCTAssertEqual(c.activeDraftID,id)
        XCTAssertTrue(N1gClinic().visits.isEmpty)
    }
    func testCannotSaveBeforeReviewingAllergies() throws {
        var (c,id)=try prepared()
        c.closeDraft()
        var other=N1gClinic()
        let d=other.newDraft(at:1)
        try other.edit(d,.worker("00000001"),at:2)
        try other.edit(d,.category("ENFERMEDAD"),at:3)
        try other.edit(d,.diagnosis("CEFALEA FICTICIA"),at:4)
        try other.edit(d,.procedure("OBSERVACION"),at:5)
        XCTAssertThrowsError(try other.saveDemo(d,at:6)) { e in
            XCTAssertEqual(e as? N1gError,.allergyNotReviewed)
        }
        try c.saveDemo(id,at:200)
        XCTAssertEqual(c.saved.count,1)
    }
    func testThreeAllergyStatesAreExplicit() throws {
        var (c,id)=try prepared()
        XCTAssertEqual(c.allergies["00000001"],.none)
        try c.reviewAllergy(.unknown,for:"00000001")
        XCTAssertEqual(c.allergies["00000001"],.unknown)
        try c.reviewAllergy(.known,for:"00000001")
        XCTAssertEqual(c.allergies["00000001"],.known)
        try c.saveDemo(id,at:200)
        XCTAssertEqual(c.physicalMovementsCreated,0)
    }
    func testSimulatedSavedNeverCreatesKardexMovements() throws {
        var (c,id)=try prepared()
        try c.edit(id,.product("INSUMO FICTICIO A · UND"),at:105)
        try c.edit(id,.quantity(4),at:106)
        try c.saveDemo(id,at:107)
        XCTAssertEqual(c.saved.first?.quantity,4)
        XCTAssertTrue(c.drafts.isEmpty)
        XCTAssertEqual(c.physicalMovementsCreated,0)
        XCTAssertThrowsError(try c.edit(id,.result("LABORANDO"),at:108))
    }
    func testCorrectionDraftProtectsSavedVisit() throws {
        var (c,id)=try prepared()
        try c.saveDemo(id,at:200)
        let fix=try c.correctionDraft(of:id,at:201)
        try c.edit(fix,.diagnosis("CONTROL FICTICIO"),at:202)
        XCTAssertThrowsError(try c.saveDemo(fix,at:203)) { e in
            XCTAssertEqual(e as? N1gError,.correctionNeedsAudit)
        }
        XCTAssertEqual(c.saved.first?.diagnosis,"CEFALEA FICTICIA")
        XCTAssertEqual(c.drafts.first?.originID,id)
    }
    func testCanDeleteDraftButNotSavedHistory() throws {
        var (c,id)=try prepared()
        try c.saveDemo(id,at:200)
        XCTAssertThrowsError(try c.removeDraft(id))
        let d=try c.correctionDraft(of:id,at:210)
        try c.removeDraft(d)
        XCTAssertEqual(c.saved.count,1)
        XCTAssertTrue(c.drafts.isEmpty)
    }
}
