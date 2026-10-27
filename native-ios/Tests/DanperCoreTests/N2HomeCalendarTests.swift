import Foundation
import XCTest
@testable import DanperCore

final class N2HomeCalendarTests:XCTestCase {
    private func date(_ value:String)throws->Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from:value))
    }
    private func visit(_ id:String,_ day:String,_ status:String="saved")->N2VisitIndexRow {
        N2VisitIndexRow(id:id,workerDNI:"00000001",workerName:"PERSONA FICTICIA",
            date:day,time:"08:00",diagnosis:"PRUEBA",status:status,frequency:nil,
            clinicalLines:5,confirmedPhysicalLines:0,pendingPhysicalLines:0,consumptionR:[])
    }
    func testLimaMidnightAndMonthBoundary()throws {
        let before=N2HomeCalendarPeriod(now:try date("2026-11-01T04:59:59Z"))
        XCTAssertEqual(before.today,"2026-10-31")
        XCTAssertEqual(before.weekStart,"2026-10-26")
        XCTAssertEqual(before.monthStart,"2026-10-01")
        let after=N2HomeCalendarPeriod(now:try date("2026-11-01T05:00:00Z"))
        XCTAssertEqual(after.today,"2026-11-01")
        XCTAssertEqual(after.weekStart,"2026-10-26")
        XCTAssertEqual(after.monthStart,"2026-11-01")
    }
    func testWeekStartsOnMondayAcrossYearBoundary()throws {
        let monday=N2HomeCalendarPeriod(now:try date("2026-12-28T05:00:00Z"))
        XCTAssertEqual(monday.weekStart,"2026-12-28")
        let friday=N2HomeCalendarPeriod(now:try date("2027-01-01T15:00:00Z"))
        XCTAssertEqual(friday.weekStart,"2026-12-28")
        XCTAssertEqual(friday.monthStart,"2027-01-01")
    }
    func testOnlyConfirmedVisitsThroughLocalTodayCount()throws {
        let visits=[visit("old","2026-09-30"),visit("month","2026-10-01"),
            visit("week","2026-10-26"),visit("today","2026-10-31"),
            visit("future","2026-11-01"),visit("draft","2026-10-31","draft")]
        let counts=N2DashboardMetrics.calculate(visits:visits,now:try date("2026-11-01T04:59:59Z"))
        XCTAssertEqual(counts.today,1)
        XCTAssertEqual(counts.week,2)
        XCTAssertEqual(counts.month,3)
        XCTAssertEqual(counts.drafts,1)
        let next=N2DashboardMetrics.calculate(visits:visits,now:try date("2026-11-01T05:00:00Z"))
        XCTAssertEqual(next.today,1);XCTAssertEqual(next.week,3);XCTAssertEqual(next.month,1)
    }
    func testFutureDaysInSameWeekAndMonthAreExcluded()throws {
        let counts=N2DashboardMetrics.calculate(visits:[visit("tomorrow","2026-10-27")],
            now:try date("2026-10-26T15:00:00Z"))
        XCTAssertEqual(counts.today,0);XCTAssertEqual(counts.week,0);XCTAssertEqual(counts.month,0)
    }
    func testLeapDayAndEmptySource()throws {
        let now=try date("2028-02-29T12:00:00Z")
        let period=N2HomeCalendarPeriod(now:now)
        XCTAssertEqual(period.today,"2028-02-29");XCTAssertEqual(period.monthStart,"2028-02-01")
        let counts=N2DashboardMetrics.calculate(visits:[],now:now)
        XCTAssertEqual(counts.today,0);XCTAssertEqual(counts.week,0);XCTAssertEqual(counts.month,0)
    }
}
