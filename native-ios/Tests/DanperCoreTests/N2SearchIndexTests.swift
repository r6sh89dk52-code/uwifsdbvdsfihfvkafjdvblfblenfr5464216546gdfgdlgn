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
    func testPostingCandidatesPreserveSubstringSemanticsOrderingAndLimits() {
        let rows=["ABXYCD", "ABCD", "CDAB", "ÁBCDE", "００００９６４８", "👩‍⚕️ ALERGIA", "PERSONA 09648"]
        let index=N2SearchIndex(rows:rows,fields:{$0})
        let locale=Locale(identifier:"es_PE")
        for query in ["ABCD","CD","ab","09648","00009648","ábc","👩‍⚕️", "XYC","ausente"] {
            let folded=query.folding(options:[.caseInsensitive,.diacriticInsensitive,.widthInsensitive],locale:locale)
            let expected=rows.filter{$0.folding(options:[.caseInsensitive,.diacriticInsensitive,.widthInsensitive],locale:locale).contains(folded)}
            for limit in [1,2,25] {
                XCTAssertEqual(index.matches(query,minimumLength:1,limit:limit),Array(expected.prefix(limit)),query)
            }
        }
        XCTAssertTrue(index.matches("ABCD").contains("ABCD"))
        XCTAssertFalse(index.matches("ABCD").contains("ABXYCD"),"Pair candidates must still verify the complete substring")
    }
    func testRareFinalRecordMatchesWithoutLosingCommonPaginationOrder() {
        let rows=(1...9_648).map{String(format:"PERSONA FICTICIA PERF %05d",$0)}
        let index=N2SearchIndex(rows:rows,fields:{$0})
        XCTAssertEqual(index.matches("PERF 09648",limit:25),[rows.last!])
        XCTAssertEqual(index.matches("PERSONA",limit:25),Array(rows.prefix(25)))
        XCTAssertEqual(index.matches("PERSONA").count,rows.count)
    }

    func testExplicitUnfilteredHistoryQueryPreservesSavedRowsAndBounds() {
        let rows=["ATENCION FICTICIA R1","ATENCION FICTICIA R0"]
        let index=N2SearchIndex(rows:rows,fields:{$0})
        XCTAssertTrue(index.matches("").isEmpty,"Roster must still start empty")
        XCTAssertEqual(index.matches("",minimumLength:0),rows)
        XCTAssertEqual(index.matches("  ",minimumLength:0,limit:1),Array(rows.prefix(1)))
        XCTAssertTrue(index.matches("",minimumLength:0,limit:0).isEmpty)
        XCTAssertEqual(index.matches("R0",minimumLength:0),[rows[1]])
    }

}
