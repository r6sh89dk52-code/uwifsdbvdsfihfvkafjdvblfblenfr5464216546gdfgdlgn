import XCTest
@testable import DanperCore

final class N2SearchIndexTests:XCTestCase {
    func testLargeRosterEmptyBoundedAccentAndFinalRecord() {
        let rows=(1...9_648).map{String(format:"%08d",$0)+" PERSONA FICTICIA \($0)"}
        let index=N2SearchIndex(rows:rows,fields:{$0})
        XCTAssertTrue(index.matches("").isEmpty)
        XCTAssertTrue(index.matches(" ").isEmpty)
        XCTAssertTrue(index.matches("p").isEmpty)
        XCTAssertEqual(index.matches("PERSONA",limit:25).count,25)
        XCTAssertEqual(index.matches("PERSONA",limit:5).count,5)
        XCTAssertEqual(index.matches("00009648"),[rows.last!])
        XCTAssertTrue(index.matches("PERSONA",limit:0).isEmpty)
        XCTAssertEqual(index.matches("PERSONA").count,9_648)
        let names=N2SearchIndex(rows:["ÁZCÁRATE ÑÚÑEZ","GOMEZ"],fields:{$0})
        XCTAssertEqual(names.matches("azcarate nunez"),["ÁZCÁRATE ÑÚÑEZ"])
        XCTAssertEqual(names.matches("  gÓMeZ  "),["GOMEZ"])
    }
    func testNewIndexDoesNotRetainAnotherRosterAndOriginalIsUnchanged() {
        let original=["PERSONA ANTIGUA","OTRA PERSONA"]
        let old=N2SearchIndex(rows:original,fields:{$0})
        let new=N2SearchIndex(rows:["PERSONA NUEVA"],fields:{$0})
        XCTAssertTrue(new.matches("ANTIGUA").isEmpty)
        XCTAssertTrue(old.matches("NUEVA").isEmpty)
        XCTAssertEqual(old.matches("ANTIGUA"),[original[0]])
        XCTAssertEqual(original,["PERSONA ANTIGUA","OTRA PERSONA"])
    }
}
