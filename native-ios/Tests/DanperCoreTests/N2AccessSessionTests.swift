import XCTest
@testable import DanperCore

final class N2AccessSessionTests:XCTestCase {
    func testAutomaticSuccessDoesNotRequireAnotherManualEntry() {
        var session=N2AccessSession()
        XCTAssertTrue(session.reserveAutomatic())
        XCTAssertTrue(session.begin())
        XCTAssertFalse(session.begin())
        session.complete(success:true)
        XCTAssertTrue(session.authenticated)
        XCTAssertFalse(session.reserveAutomatic())
        XCTAssertFalse(session.begin())
    }
    func testCancellationDoesNotLoopAndManualRetryRemainsPossible() {
        var session=N2AccessSession()
        XCTAssertTrue(session.reserveAutomatic())
        XCTAssertTrue(session.begin())
        session.complete(success:false)
        XCTAssertFalse(session.authenticated)
        XCTAssertFalse(session.reserveAutomatic())
        XCTAssertTrue(session.begin())
        session.complete(success:true)
        XCTAssertTrue(session.authenticated)
    }
    func testBackgroundLocksAndAllowsOneNewAttempt() {
        var session=N2AccessSession()
        XCTAssertTrue(session.reserveAutomatic());XCTAssertTrue(session.begin())
        session.complete(success:true)
        session.lock()
        XCTAssertFalse(session.authenticated)
        session.complete(success:true)
        XCTAssertFalse(session.authenticated)
        XCTAssertTrue(session.reserveAutomatic())
        XCTAssertFalse(session.reserveAutomatic())
    }
}
