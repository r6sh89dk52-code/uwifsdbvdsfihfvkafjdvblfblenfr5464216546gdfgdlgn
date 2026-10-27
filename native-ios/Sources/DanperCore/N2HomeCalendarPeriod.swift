import Foundation

/// Presentation-only date boundaries; no clinical data or persisted state.
public struct N2HomeCalendarPeriod:Equatable,Sendable {
    public let today:String
    public let weekStart:String
    public let monthStart:String
    public init(now:Date) {
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(identifier:"America/Lima")!
        calendar.firstWeekday=2
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=calendar.timeZone
        formatter.dateFormat="yyyy-MM-dd"
        today=formatter.string(from:now)
        weekStart=formatter.string(from:calendar.dateInterval(of:.weekOfYear,for:now)!.start)
        monthStart=formatter.string(from:calendar.dateInterval(of:.month,for:now)!.start)
    }
}
