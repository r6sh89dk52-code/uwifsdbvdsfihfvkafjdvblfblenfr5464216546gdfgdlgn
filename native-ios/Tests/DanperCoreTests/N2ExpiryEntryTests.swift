import XCTest
@testable import DanperCore

final class N2ExpiryEntryTests:XCTestCase {
    func testFormattingAndPaste() {
        XCTAssertEqual(N2ExpiryEntry.format("201030"),"20/10/30")
        XCTAssertEqual(N2ExpiryEntry.format("20/10/30"),"20/10/30")
        XCTAssertEqual(N2ExpiryEntry.format("20103099"),"20/10/30")
        XCTAssertEqual(N2ExpiryEntry.format("201"),"20/1")
        XCTAssertEqual(N2ExpiryEntry.format(""),"")
    }
    func testGregorianValidation() {
        XCTAssertEqual(N2ExpiryEntry.iso("290228"),"2028-02-29")
        XCTAssertEqual(N2ExpiryEntry.iso("20/10/30"),"2030-10-20")
        for invalid in ["290227","310430","001230","201330","2010","20//1030","20a1030"] {
            XCTAssertNil(N2ExpiryEntry.iso(invalid),invalid)
        }
    }
}
