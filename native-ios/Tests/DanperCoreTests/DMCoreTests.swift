import XCTest
@testable import DanperCore

final class DMCoreTests:XCTestCase {
    private func certificate(dni:String="12345678",start:String="2026-10-19",
                             end:String="2026-10-20",number:String="A-244-00012345-26")->DMCertificate {
        var value=DMCertificate()
        value.dni=dni;value.name="PERSONA FICTICIA"
        value.startDate=start;value.endDate=end
        value.receiptDate="2026-10-25"
        value.documentDays=DMDate.days(start,end)
        value.certificateNumber=number
        return value
    }
    func testCITTDistinguishesCurrentAndAccumulatedDays()throws {
        let text="""
        CERTIFICADO DE INCAPACIDAD TEMPORAL PARA EL TRABAJO
        CITT No.: A-244-00012345-26
        Nombre Asegurado: PERSONA FICTICIA
        Doc. de Identidad: D.N.I. 12345678
        Contingencia: ENFERMEDAD COMUN
        Fecha de Inicio: 19/10/2026
        Fecha Fin: 20/10/2026
        Total de Dias: 2
        F. de Otorgamiento: 19/10/2026
        CMP: 101108
        Dias de Incapacidad Temporal Acumulado: 9
        """
        let c=DMCITTParser.parse(text)
        XCTAssertEqual(c.dni,"12345678")
        XCTAssertEqual(c.certificateNumber,"A-244-00012345-26")
        XCTAssertEqual(c.documentDays,2)
        XCTAssertEqual(c.accumulatedDays,9)
        XCTAssertEqual(c.calculatedDays,2)
        XCTAssertFalse(c.needsClearance)
        XCTAssertEqual(c.issuedDate,"2026-10-19")
        XCTAssertEqual(c.expectedReturn,"2026-10-21")
        XCTAssertEqual(c.hospitalization,.unknown)
        XCTAssertEqual(c.diagnosis,"")
    }
    func testReceiptDateIndependentFromCITT()throws {
        var c=certificate()
        c.receiptDate="2026-10-23"
        XCTAssertTrue(c.isValid)
        XCTAssertEqual(c.issuedDate,"")
        XCTAssertEqual(c.receiptDate,"2026-10-23")
    }
    func testFiveDaysOrConfirmedHospitalizationRequiresClearance()throws {
        var five=certificate(end:"2026-10-23")
        XCTAssertTrue(five.needsClearance)
        XCTAssertThrowsError(try five.markReturned(on:"2026-10-24")) {
            XCTAssertEqual($0 as? DMError,.clearanceRequired)
        }
        five.clearanceVerified=true
        try five.markReturned(on:"2026-10-24")
        XCTAssertEqual(five.state,.returned)
        var two=certificate()
        two.hospitalization = .yes
        XCTAssertTrue(two.needsClearance)
    }
    func testDuplicateCITTAndOverlappingEpisodes()throws {
        var ledger=DMLedger()
        let first=certificate(start:"2026-10-19",end:"2026-10-21",number:"C1")
        let next=certificate(start:"2026-10-21",end:"2026-10-23",number:"C2")
        try ledger.add(first);try ledger.add(next)
        XCTAssertEqual(ledger.episodeDays(for:first.dni),5)
        XCTAssertThrowsError(try ledger.add(first)){
            XCTAssertEqual($0 as? DMError,.duplicate)
        }
    }
    func testBadDatesAndDiscrepancyCannotBeSaved()throws {
        XCTAssertNil(DMDate.parse("2026-02-30"))
        var c=certificate()
        c.documentDays=9
        XCTAssertTrue(c.discrepancy)
        XCTAssertFalse(c.isValid)
        var ledger=DMLedger()
        XCTAssertThrowsError(try ledger.add(c))
    }
    func testISOConversionUsesCalendarNotTimezoneHours()throws {
        XCTAssertEqual(DMDate.fromPrinted("19/10/2026"),"2026-10-19")
        XCTAssertEqual(DMDate.days("2026-12-31","2027-01-01"),2)
        XCTAssertEqual(DMDate.following("2026-12-31"),"2027-01-01")
    }
}