import XCTest
@testable import DANPERNative

final class DanperGreetingTests:XCTestCase {
    private var calendar:Calendar {
        var c=Calendar(identifier:.gregorian);c.timeZone=TimeZone(secondsFromGMT:-5*3600)!
        return c
    }
    private func date(_ hour:Int,_ minute:Int=0,_ second:Int=0)->Date {
        calendar.date(from:DateComponents(year:2026,month:10,day:29,hour:hour,minute:minute,second:second))!
    }
    func testAllLocalTimeBoundariesAndExactFelipeEmojis() {
        for (h,m,s,expected) in [(0,0,0,"Buenas noches Felipe 🌙"),(4,59,59,"Buenas noches Felipe 🌙"),
                                 (5,0,0,"Buenos días Felipe ☀️"),(11,59,59,"Buenos días Felipe ☀️"),
                                 (12,0,0,"Buenas tardes Felipe 🌤️"),(18,59,59,"Buenas tardes Felipe 🌤️"),
                                 (19,0,0,"Buenas noches Felipe 🌙"),(23,59,59,"Buenas noches Felipe 🌙")] {
            XCTAssertEqual(DanperGreeting.text(name:"Felipe",at:date(h,m,s),calendar:calendar),expected)
        }
        var utc=calendar;utc.timeZone=TimeZone(secondsFromGMT:0)!
        XCTAssertEqual(DanperGreeting.text(name:"Felipe",at:date(4),calendar:utc),"Buenos días Felipe ☀️","Use calendar local hour, not UTC hour")
    }
    func testEmptyNameAndWhitespaceNeverInventAnIdentity() {
        for name in [""," ","\n\t"] {
            XCTAssertEqual(DanperGreeting.text(name:name,at:date(5),calendar:calendar),"Buenos días ☀️")
            XCTAssertEqual(DanperGreeting.text(name:name,at:date(12),calendar:calendar),"Buenas tardes 🌤️")
            XCTAssertEqual(DanperGreeting.text(name:name,at:date(19),calendar:calendar),"Buenas noches 🌙")
        }
        XCTAssertEqual(DanperGreeting.text(name:"  Felipe\n",at:date(5),calendar:calendar),"Buenos días Felipe ☀️")
    }
    func testInjectedClockAndNextBoundaryWithoutPolling() {
        var current=date(11,59,59)
        let clock=DanperGreetingClock(now:{current})
        XCTAssertEqual(DanperGreeting.text(name:"Felipe",at:clock.now(),calendar:calendar),"Buenos días Felipe ☀️")
        XCTAssertEqual(DanperGreeting.nextBoundary(after:clock.now(),calendar:calendar),date(12))
        current=date(12)
        XCTAssertEqual(DanperGreeting.text(name:"Felipe",at:clock.now(),calendar:calendar),"Buenas tardes Felipe 🌤️")
        XCTAssertEqual(DanperGreeting.nextBoundary(after:current,calendar:calendar),date(19))
        XCTAssertEqual(DanperGreeting.nextBoundary(after:date(4,59,59),calendar:calendar),date(5))
        let tomorrow=calendar.date(byAdding:.day,value:1,to:date(5))!
        XCTAssertEqual(DanperGreeting.nextBoundary(after:date(19),calendar:calendar),tomorrow)
        XCTAssertEqual(DanperGreeting.nextBoundary(after:date(23,59,59),calendar:calendar),tomorrow)
    }
}
