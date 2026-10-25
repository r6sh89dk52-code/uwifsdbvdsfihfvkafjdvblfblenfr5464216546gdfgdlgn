import Foundation

/// A read-only estimate when stock is physically counted after a 9th-day cut.
/// Does NOT create historical lot balances, FEFO assignments or movements.
public enum N2KardexCutPreview {
    public enum Failure:Error,Equatable {
        case invalidDate,invalidQuantity,negativeOpening,invalidAdjustment
    }
    public struct Period:Equatable,Sendable {
        public let start:String
        public let end:String
    }
    public struct Result:Equatable,Sendable {
        public let period:Period
        public let measured:Double
        public let verifiedUsed:Double
        public let laterReceipts:Double
        public let signedAdjustments:Double
        public let estimatedOpening:Double
        public let pendingHistory:Bool
        /// Even when mathematically balanced, this remains a preview, not
        /// a validated warehouse event or an exportable audit trail.
        public var requiresOperatorReconciliation:Bool {true}
    }
    private static func calendar()->Calendar {
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(identifier:"America/Lima")!
        return cal
    }
    public static func period(for day:String)throws->Period {
        let parts=day.split(separator:"-").compactMap{Int($0)}
        guard day.range(of:#"^\d{4}-\d{2}-\d{2}$"#,options:.regularExpression) != nil,
              parts.count==3,(1900...2100).contains(parts[0]) else{
            throw Failure.invalidDate
        }
        let cal=calendar()
        let components=DateComponents(year:parts[0],month:parts[1],day:parts[2])
        guard let parsed=cal.date(from:components),
              cal.dateComponents([.year,.month,.day],from:parsed)==components else{
            throw Failure.invalidDate
        }
        var opening=cal.date(from:DateComponents(year:parts[0],month:parts[1],day:9))!
        if parts[2]<9 {
            opening=cal.date(byAdding:.month,value:-1,to:opening)!
        }
        let next=cal.date(byAdding:.month,value:1,to:opening)!
        let end=cal.date(byAdding:.day,value:-1,to:next)!
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"en_US_POSIX")
        formatter.timeZone=cal.timeZone
        formatter.dateFormat="yyyy-MM-dd"
        return Period(start:formatter.string(from:opening),end:formatter.string(from:end))
    }
    /// The measured count is as-of the input date, so the initial amount
    /// equals measured + *verified* removals - receipts - signed adjustments.
    /// Pending, undocumented clinical uses cannot be silently counted.
    public static func calculate(asOf:String,measured:Double,
                                 verifiedUsed:Double,laterReceipts:Double,
                                 signedAdjustments:Double=0,
                                 pendingHistory:Bool=false)throws->Result {
        let p=try period(for:asOf)
        for n in [measured,verifiedUsed,laterReceipts,signedAdjustments] {
            guard n.isFinite,abs(n)<=10_000_000 else {throw Failure.invalidQuantity}
        }
        guard measured>=0,verifiedUsed>=0,laterReceipts>=0 else{
            throw Failure.invalidQuantity
        }
        let opening=measured+verifiedUsed-laterReceipts-signedAdjustments
        guard opening>=0 else{throw Failure.negativeOpening}
        let round={ (n:Double) in (n*1000).rounded()/1000 }
        return Result(period:p,measured:round(measured),
                      verifiedUsed:round(verifiedUsed),
                      laterReceipts:round(laterReceipts),
                      signedAdjustments:round(signedAdjustments),
                      estimatedOpening:round(opening),
                      pendingHistory:pendingHistory)
    }
}
