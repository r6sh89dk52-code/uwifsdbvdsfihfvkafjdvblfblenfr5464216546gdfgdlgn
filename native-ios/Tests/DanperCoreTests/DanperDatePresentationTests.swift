import Foundation
import XCTest
@testable import DanperCore

final class DanperDatePresentationTests:XCTestCase {
    func testPeruDisplayDatesAndTimes() {
        XCTAssertEqual(DanperDatePresentation.display("2026-10-17"),"17/10/2026")
        XCTAssertEqual(DanperDatePresentation.displayDateTime("2026-10-17","10:58"),
                       "17/10/2026 10:58")
        XCTAssertEqual(DanperDatePresentation.display("2028-02-29"),"29/02/2028")
        XCTAssertEqual(DanperDatePresentation.display(""),"—")
        XCTAssertEqual(DanperDatePresentation.display("2026-02-30"),"Fecha inválida")
    }
    func testTrueExcelNumericDayAndInvalidDates() {
        XCTAssertEqual(DanperDatePresentation.numericExcelDate("2026-10-18"),46313)
        XCTAssertNil(DanperDatePresentation.numericExcelDate("2026-02-30"))
        XCTAssertNil(DanperDatePresentation.numericExcelDate("18/10/2026"))
        XCTAssertNil(DanperDatePresentation.numericExcelDate("2026-01-00"))
    }
}
