import Foundation

public struct N2DashboardMetrics:Equatable,Sendable {
    public let today:Int
    public let week:Int
    public let drafts:Int
    public static func calculate(visits:[N2VisitIndexRow],now:Date)->N2DashboardMetrics {
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(identifier:"America/Lima")!
        cal.firstWeekday=2
        let start=cal.dateInterval(of:.weekOfYear,for:now)!
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=cal.timeZone
        formatter.dateFormat="yyyy-MM-dd"
        let day=formatter.string(from:now)
        let monday=formatter.string(from:start.start)
        let nextMonday=formatter.string(from:start.end)
        let saved=visits.filter{$0.status=="saved"}
        return N2DashboardMetrics(today:saved.filter{$0.date==day}.count,
            week:saved.filter{$0.date>=monday && $0.date<nextMonday}.count,
            drafts:visits.filter{$0.status=="draft"}.count)
    }
}
