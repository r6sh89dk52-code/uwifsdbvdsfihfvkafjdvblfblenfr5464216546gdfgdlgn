import XCTest
import Foundation
import DanperCore

/// Darwin/Foundation regression: an empty search must not erase saved history.
final class N2HistorySearchNativeTests:XCTestCase {
    func testEmptyHistoryQueryRetainsSavedRowsWhileRosterStartsEmpty() {
        let rows=["ATENCION FICTICIA R1","ATENCION FICTICIA R0"]
        let index=N2SearchIndex(rows:rows,fields:{$0})
        XCTAssertTrue(index.matches("").isEmpty)
        XCTAssertEqual(index.matches("",minimumLength:0),rows)
        XCTAssertEqual(index.matches(" ",minimumLength:0,limit:1),[rows[0]])
        XCTAssertEqual(index.matches("R0",minimumLength:0),[rows[1]])
    }
}
