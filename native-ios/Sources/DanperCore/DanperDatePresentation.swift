import Foundation

/// Dates in the encrypted clinical schema stay ISO for ordering, FEFO and
/// reconciliation. Never change persisted values to a locale-formatted string.
public enum DanperDatePresentation {
    private static var calendar:Calendar {
        var value=Calendar(identifier:.gregorian)
        value.timeZone=TimeZone(secondsFromGMT:0)!
        return value
    }

    public static func components(_ iso:String)->(year:Int,month:Int,day:Int)? {
        let parts=iso.split(separator:"-",omittingEmptySubsequences:false)
        guard parts.count==3,parts[0].count==4,parts[1].count==2,parts[2].count==2,
              parts.allSatisfy({$0.allSatisfy(\.isNumber)}),
              let year=Int(parts[0]),let month=Int(parts[1]),let day=Int(parts[2]),
              (1900...9999).contains(year),
              let date=calendar.date(from:DateComponents(year:year,month:month,day:day)),
              calendar.component(.year,from:date)==year,
              calendar.component(.month,from:date)==month,
              calendar.component(.day,from:date)==day else {return nil}
        return(year,month,day)
    }
    public static func display(_ iso:String)->String {
        guard let date=components(iso) else{return iso.isEmpty ? "—" : "Fecha inválida"}
        return String(format:"%02d/%02d/%04d",date.day,date.month,date.year)
    }
    public static func displayDateTime(_ iso:String,_ time:String)->String {
        let day=display(iso)
        return time.isEmpty ? day : day+" "+time
    }
    public static func displayTimestamp(_ milliseconds:Int64)->String {
        let formatter=DateFormatter()
        formatter.locale=Locale(identifier:"es_PE")
        formatter.timeZone=TimeZone(identifier:"America/Lima")
        formatter.dateFormat="dd/MM/yyyy HH:mm"
        return formatter.string(from:
            Date(timeIntervalSince1970:Double(milliseconds)/1000))
    }
    public static func numericExcelDate(_ iso:String)->Double? {
        guard let c=components(iso),
              let date=calendar.date(from:DateComponents(year:c.year,month:c.month,day:c.day)),
              let base=calendar.date(from:DateComponents(year:1899,month:12,day:30))
        else{return nil}
        return Double(calendar.dateComponents([.day],from:base,to:date).day ?? 0)
    }
}
