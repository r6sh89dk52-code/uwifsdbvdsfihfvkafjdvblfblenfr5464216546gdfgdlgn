import XCTest
@testable import DANPERNative

final class N2RefreshDemandTests:XCTestCase {
    func testStartupBurstPerformsOneReadInsteadOfQueuedDuplicate() {
        var demand=N2RefreshDemand(),reads=0
        for _ in 0..<20 {if demand.begin(.lifecycle){reads+=1}}
        XCTAssertEqual(reads,1)
        XCTAssertFalse(demand.finish(observedRevision:7))
        XCTAssertFalse(demand.reading)
    }
    func testConcurrentWriteRequiresOneNewReadAndCannotPublishOldResult() {
        var demand=N2RefreshDemand()
        XCTAssertTrue(demand.begin(.lifecycle))
        XCTAssertFalse(demand.begin(.verifiedWrite(9)))
        XCTAssertFalse(demand.begin(.verifiedWrite(8)))
        XCTAssertFalse(demand.canPublish(7))
        XCTAssertTrue(demand.finish(observedRevision:7))
        XCTAssertTrue(demand.begin(.lifecycle))
        XCTAssertTrue(demand.canPublish(9))
        XCTAssertFalse(demand.finish(observedRevision:9))
    }
    func testWriteAlreadyIncludedInAuthenticatedResultDoesNotReadAgain() {
        var demand=N2RefreshDemand()
        XCTAssertTrue(demand.begin(.lifecycle))
        XCTAssertFalse(demand.begin(.verifiedWrite(9)))
        XCTAssertTrue(demand.canPublish(9))
        XCTAssertFalse(demand.finish(observedRevision:9))
    }
    func testExplicitManualRefreshIsPreservedAndFailuresDoNotRetryForever() {
        var demand=N2RefreshDemand()
        XCTAssertTrue(demand.begin(.lifecycle))
        XCTAssertFalse(demand.begin(.manual))
        XCTAssertTrue(demand.finish(observedRevision:9))
        XCTAssertTrue(demand.begin(.lifecycle))
        XCTAssertFalse(demand.begin(.verifiedWrite(10)))
        XCTAssertFalse(demand.finish(observedRevision:nil))
        XCTAssertTrue(demand.begin(.manual))
        XCTAssertFalse(demand.finish(observedRevision:10))
    }
}
