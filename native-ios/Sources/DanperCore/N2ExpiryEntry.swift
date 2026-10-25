import Foundation

public enum N2ExpiryEntry {
    public static func format(_ input:String)->String {
        let digits=Array(input.filter { $0.isASCII && $0.isNumber }.prefix(6))
        return digits.enumerated().map { index, digit in
            (index==2 || index==4 ? "/" : "")+String(digit)
        }.joined()
    }
    public static func iso(_ input:String)->String? {
        guard input.allSatisfy({($0.isASCII && $0.isNumber) || $0=="/"}),
              input.filter(\.isNumber).count==6 else{return nil}
        let formatted=format(input)
        guard input==formatted || !input.contains("/") else{return nil}
        let values=formatted.split(separator:"/").compactMap {Int($0)}
        guard values.count==3 else{return nil}
        let year=2000+values[2],month=values[1],day=values[0]
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(secondsFromGMT:0)!
        guard let date=calendar.date(from:DateComponents(year:year,month:month,day:day)),
              calendar.component(.year,from:date)==year,
              calendar.component(.month,from:date)==month,
              calendar.component(.day,from:date)==day else{return nil}
        return String(format:"%04d-%02d-%02d",year,month,day)
    }
}
