import XCTest
import Foundation
@testable import DanperCore

final class N1hGuidedDemoTests: XCTestCase {
    private func draft() throws -> (N1gClinic,UUID) {
        var clinic=N1gClinic()
        let id=clinic.newDraft(at:100)
        try clinic.edit(id,.worker("00000001"),at:101)
        try clinic.edit(id,.category("ENFERMEDAD"),at:102)
        try clinic.edit(id,.diagnosis("CEFALEA FICTICIA"),at:103)
        try clinic.edit(id,.procedure("OBSERVACION"),at:104)
        try clinic.reviewAllergy(.none,for:"00000001")
        return (clinic,id)
    }
    func testNativeStageBlocksMissingSystemLikeTS() throws {
        var (clinic,id)=try draft()
        XCTAssertEqual(clinic.invalidFields(for:id,step:1),["clinical-system"])
        XCTAssertEqual(clinic.firstIncompleteStep(for:id),1)
        XCTAssertThrowsError(try clinic.saveDemo(id,at:200))
        try clinic.edit(id,.system("RESPIRATORIO"),at:105)
        XCTAssertEqual(clinic.invalidFields(for:id,step:1),[])
        try clinic.saveDemo(id,at:201)
        XCTAssertEqual(clinic.saved.count,1)
    }
    func testOsteomuscularSegmentIsRequiredAndDoesNotModifyStock() throws {
        var (clinic,id)=try draft()
        try clinic.edit(id,.system("OSTEOMUSCULAR"),at:105)
        XCTAssertEqual(clinic.invalidFields(for:id,step:1),["clinical-segment"])
        try clinic.edit(id,.segment("BRAZO FICTICIO"),at:106)
        XCTAssertEqual(clinic.invalidFields(for:id,step:1),[])
        try clinic.saveDemo(id,at:107)
        XCTAssertEqual(clinic.physicalMovementsCreated,0)
    }
    func testPermissionHasRequiredTimeAndControlledResult() throws {
        var (clinic,id)=try draft()
        try clinic.edit(id,.system("DIGESTIVO"),at:105)
        try clinic.edit(id,.permission("SI"),at:106)
        XCTAssertEqual(clinic.activeDraft?.result,"PERMISO FICTICIO")
        XCTAssertEqual(clinic.invalidFields(for:id,step:3),["result-permission-time"])
        try clinic.edit(id,.permissionTime("10:10"),at:107)
        XCTAssertEqual(clinic.invalidFields(for:id,step:3),[])
        try clinic.edit(id,.permission("NO"),at:108)
        XCTAssertEqual(clinic.activeDraft?.detailed.permissionTime,"")
        XCTAssertEqual(clinic.activeDraft?.result,"LABORANDO")
        try clinic.saveDemo(id,at:109)
    }
    func testPhotoAndBandageHaveConsistentFlags() throws {
        var (clinic,id)=try draft()
        try clinic.edit(id,.blueBandage(true),at:105)
        try clinic.edit(id,.returned(true),at:106)
        try clinic.edit(id,.photoSent(true),at:107)
        XCTAssertEqual(clinic.activeDraft?.detailed.returned,true)
        try clinic.edit(id,.blueBandage(false),at:108)
        XCTAssertEqual(clinic.activeDraft?.detailed.returned,false)
        XCTAssertEqual(clinic.activeDraft?.detailed.photoSent,true)
        XCTAssertThrowsError(try clinic.edit(id,.returned(true),at:109))
    }
    func testClosedDateAndTimeOptionsRejectFreeText() throws {
        var (clinic,id)=try draft()
        XCTAssertThrowsError(try clinic.edit(id,.date("2026-10-17"),at:105))
        XCTAssertThrowsError(try clinic.edit(id,.time("00:00"),at:106))
        XCTAssertEqual(clinic.activeDraft?.detailed.date,"2026-10-16")
    }
    func testProceduresRemainSeparateFromPhysicalKardex() throws {
        var (clinic,id)=try draft()
        try clinic.edit(id,.system("RESPIRATORIO"),at:105)
        try clinic.edit(id,.standaloneProcedure("CONTROL",true),at:106)
        try clinic.edit(id,.standaloneProcedure("OBSERVACION",true),at:107)
        XCTAssertEqual(clinic.activeDraft?.detailed.standaloneProcedures,["CONTROL","OBSERVACION"])
        try clinic.edit(id,.standaloneProcedure("CONTROL",false),at:108)
        XCTAssertEqual(clinic.activeDraft?.detailed.standaloneProcedures,["OBSERVACION"])
        try clinic.saveDemo(id,at:109)
        XCTAssertEqual(clinic.physicalMovementsCreated,0)
    }
    func testBorradorCorrectionClonesEveryNewFieldButCannotOverwrite() throws {
        var (clinic,id)=try draft()
        try clinic.edit(id,.system("OSTEOMUSCULAR"),at:105)
        try clinic.edit(id,.segment("PIERNA FICTICIA"),at:106)
        try clinic.edit(id,.photoSent(true),at:107)
        try clinic.saveDemo(id,at:108)
        let fix=try clinic.correctionDraft(of:id,at:109)
        XCTAssertEqual(clinic.activeDraft?.detailed.system,"OSTEOMUSCULAR")
        XCTAssertEqual(clinic.activeDraft?.detailed.segment,"PIERNA FICTICIA")
        XCTAssertEqual(clinic.activeDraft?.detailed.photoSent,true)
        try clinic.edit(fix,.photoSent(false),at:110)
        XCTAssertEqual(clinic.saved.first?.detailed.photoSent,true)
        XCTAssertThrowsError(try clinic.saveDemo(fix,at:111))
    }
}
