import Foundation
import XCTest
@testable import DanperCore

final class N2StockRegistrationChoiceTests:XCTestCase {
    private func item(use:Double=3,unknown:Int=0)->N2AutomaticCutAccounting.Row {
        N2AutomaticCutAccounting.Row(
            code:"E-22",name:"PARACETAMOL",currentCount:nil,
            clinicalUnits:use,reportedUse:use,
            received:0,adjusted:0,opening:nil,
            unlinkedItems:use>0 ? 1:0,
            unknownContainerOpenings:unknown,usesByDay:["2026-10-18":use])
    }
    func testCurrentPhysicalCountPreservedAndReconstructsDayNineOpening()throws {
        let result=try N2StockRegistrationChoice.resolve(
            .countedNow,quantity:20,historical:item(),isContainer:false)
        XCTAssertEqual(result.todayPhysical,20)
        XCTAssertEqual(result.cutOpening,23)
        XCTAssertEqual(result.historicalUse,3)
    }
    func testExplicitInitialStockDeductsAlreadyRecordedUseOnce()throws {
        let result=try N2StockRegistrationChoice.resolve(
            .opening,quantity:23,historical:item(),isContainer:false)
        XCTAssertEqual(result.todayPhysical,20)
        XCTAssertEqual(result.cutOpening,23)
        XCTAssertEqual(result.historicalUse,3)
    }
    func testNoPastUseKeepsTheSameQuantityEitherWay()throws {
        for basis in [N2StockRegistrationBasis.opening,.countedNow] {
            let result=try N2StockRegistrationChoice.resolve(
                basis,quantity:25,historical:nil,isContainer:false)
            XCTAssertEqual(result.todayPhysical,25)
            XCTAssertEqual(result.cutOpening,25)
        }
    }
    func testUnverifiedBottleOpeningCannotBeBackdatedAutomatically() {
        XCTAssertThrowsError(try N2StockRegistrationChoice.resolve(
            .opening,quantity:2,historical:item(use:0,unknown:1),
            isContainer:true)) {error in
            XCTAssertEqual(error as? N2StockRegistrationChoice.Failure,
                           .ambiguousHistoricalOpenings)
        }
        // Operator may still count the actual unopened bottles today.
        let physical=try? N2StockRegistrationChoice.resolve(
            .countedNow,quantity:2,historical:item(use:0,unknown:1),
            isContainer:true)
        XCTAssertEqual(physical?.todayPhysical,2)
        XCTAssertNil(physical?.cutOpening)
    }
    func testNeverCreatesNegativeOrFractionalPhysicalContainerCount() {
        XCTAssertThrowsError(try N2StockRegistrationChoice.resolve(
            .opening,quantity:2,historical:item(use:3),
            isContainer:false)) { error in
            XCTAssertEqual(error as? N2StockRegistrationChoice.Failure,
                           .negativeCurrentStock)
        }
        XCTAssertThrowsError(try N2StockRegistrationChoice.resolve(
            .opening,quantity:2,historical:item(use:0.5),
            isContainer:true)) {error in
            XCTAssertEqual(error as? N2StockRegistrationChoice.Failure,
                           .fractionalContainerBalance)
        }
    }
}
