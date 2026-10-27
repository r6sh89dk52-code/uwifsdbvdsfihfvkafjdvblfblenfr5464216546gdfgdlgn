import Foundation

public struct N2DashboardMetrics:Equatable,Sendable {
    public let today:Int
    public let week:Int
    public let month:Int
    public let drafts:Int
    public static func calculate(visits:[N2VisitIndexRow],now:Date)->N2DashboardMetrics {
        let period=N2HomeCalendarPeriod(now:now)
        let day=period.today,monday=period.weekStart
        let saved=visits.filter{$0.status=="saved"}
        return N2DashboardMetrics(today:saved.filter{$0.date==day}.count,
            week:saved.filter{$0.date>=monday && $0.date<=day}.count,
            month:saved.filter{$0.date>=period.monthStart && $0.date<=day}.count,
            drafts:visits.filter{$0.status=="draft"}.count)
    }
}
