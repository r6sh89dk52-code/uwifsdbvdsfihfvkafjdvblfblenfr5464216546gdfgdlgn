import Foundation
import CoreFoundation

/// Native daily/range nursing ledger report, one-for-one with build222
/// dailyKardex.ts. It never converts internal mL into sealed FCO count and
/// keeps unknown stock blank instead of inventing zero.
public enum N2NursingReportError:Error,Equatable {
    case invalidSource, invalidCatalog, invalidDay, unsupportedRange
    case invalidPhysicalCount, incompleteHistory
}
public struct N2NursingRow:Equatable,Sendable {
    public let code:String
    public let name:String
    public let donated:Bool
    public let stockKnown:Bool
    public let initial:Double
    public let extraordinary:Double
    public let total:Double
    public let consumed:Double
    public let closing:Double
    public let expiry:String
    public let fs:Double?

    func value() -> [String:Any] {
        ["code":code,"name":name,"donated":donated,
         "stockKnown":stockKnown,"initial":initial,
         "extraordinary":extraordinary,"total":total,
         "consumed":consumed,"final":closing,"expiry":expiry,
         "fs":fs.map{NSNumber(value:$0) as Any} ?? NSNull()]
    }
}
public struct N2NursingReport:Sendable {
    public let date:String
    public let periodEnd:String?
    public let rows:[N2NursingRow]
    public let warnings:[String]
    public var exportable:Bool {warnings.isEmpty}

    /// N1s official 98-product writer consumes this exact manifest.
    public func manifest(shift:String,responsible:String)throws->Data {
        // An interval cannot be represented as an official single-day XLSX.
        guard periodEnd == nil else {throw N2NursingReportError.unsupportedRange}
        guard exportable,["MAÑANA","TARDE","NOCHE","CONSOLIDADO"].contains(shift),
              !responsible.trimmingCharacters(in:.whitespaces).isEmpty else {
            throw N2NursingReportError.incompleteHistory
        }
        let record:[String:Any]=["date":date,"rows":rows.map{$0.value()},
                                  "shift":shift,"responsible":responsible]
        return try JSONSerialization.data(withJSONObject:record)
    }
}
public enum N2NursingReportBuilder {
    private static func count(_ x:Any?)->Double? {
        guard let n=x as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite else{return nil}
        return n.doubleValue
    }
    private static func rounded(_ value:Double)->Double {
        (value*1000).rounded()/1000
    }
    private static func iso(_ value:String)->Bool {
        guard value.range(of:#"^\d{4}-\d{2}-\d{2}$"#,
                          options:.regularExpression) != nil,
              let y=Int(value.prefix(4)),let m=Int(value.dropFirst(5).prefix(2)),
              let d=Int(value.suffix(2)),(1900...2100).contains(y) else{return false}
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(secondsFromGMT:0)!
        guard let date=calendar.date(from:DateComponents(year:y,month:m,day:d)) else {
            return false
        }
        let parts=calendar.dateComponents([.year,.month,.day],from:date)
        return parts.year==y && parts.month==m && parts.day==d
    }
    private static func localDay(_ at:Double)->String {
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(identifier:"America/Lima")!
        let c=calendar.dateComponents([.year,.month,.day],
                from:Date(timeIntervalSince1970:at/1000.0))
        return String(format:"%04d-%02d-%02d",c.year!,c.month!,c.day!)
    }
    private static func byDate(_ input:[String:Any])->String {
        localDay(count(input["at"]) ?? 0)
    }
    private static func packaged(_ l:[String:Any])->Bool {
        let unit=(l["catalogUnit"] as? String ?? "").trimmingCharacters(in:.whitespaces)
            .uppercased()
        let size=count(l["unitsPerContainer"]) ?? 0
        return !["UND","TBL","PAR"].contains(unit) &&
               ((l["container"] as? String) != "unidad" || size != 1)
    }
    private static func balance(_ l:[String:Any])->Double {
        if packaged(l){return count(l["sealedContainers"]) ?? 0}
        let c=count(l["unitsPerContainer"]) ?? 0
        let n=count(l["sealedContainers"]) ?? 0
        let loose=count(l["looseUnits"]) ?? 0
        let open=count(l["openedRemaining"]) ?? 0
        return rounded(n*c+loose+open)
    }
    private static func decoded(_ snapshot:Data,_ catalog:Data,site:String="")throws
        -> ([[String:Any]],[[String:Any]],[[String:Any]]) {
        guard (try? N1eLegacyClinicalAudit.inspect(snapshot)) != nil,
              (try? N1fLosslessFieldGate.inspect(snapshot)) != nil,
              let data=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let lots=data["stockLots"] as? [[String:Any]],
              let movements=data["stockMovements"] as? [[String:Any]],
              let products=try? JSONSerialization.jsonObject(with:catalog) as? [[String:Any]],
              products.count==98 else{throw N2NursingReportError.invalidSource}
        for (i,p) in products.enumerated() {
            guard p["id"] as? String == "E-\(i+1)",
                  let name=p["name"] as? String,!name.isEmpty,
                  p["donated"] as? Bool == false else{
                throw N2NursingReportError.invalidCatalog
            }
        }
        guard site.isEmpty || ["LA VENTUROSA","PLVENTUROSA"].contains(site) else {
            throw N2NursingReportError.invalidSource
        }
        guard !site.isEmpty else{return(lots,movements,products)}
        let sites=try N2StockSiteEvidence.resolve(data)
        let scoped=lots.filter{sites[$0["id"] as? String ?? ""]==site}
        let ids=Set(scoped.compactMap{$0["id"] as? String})
        return(scoped,movements.filter{ids.contains($0["lotId"] as? String ?? "")},products)
    }
    private static func day(lots:[[String:Any]],moves:[[String:Any]],
                            catalog:[[String:Any]],date:String,
                            counts:[String:Double])throws->N2NursingReport {
        guard iso(date) else{throw N2NursingReportError.invalidDay}
        var warnings:[String]=[],rows:[N2NursingRow]=[]
        for p in catalog {
            let code=p["id"] as! String,name=p["name"] as! String
            let historic=lots.filter{$0["code"] as? String==code}
            let all=moves.filter{$0["code"] as? String==code}
            let relevant=historic.filter{l in
                let lotEvents=all.filter{$0["lotId"] as? String==l["id"] as? String}
                  .sorted{(count($0["at"]) ?? 0)<(count($1["at"]) ?? 0)}
                let initial=(lotEvents.first?["before"] as? [String:Any]) ?? l
                let knownDate=localDay(count(initial["updatedAt"]) ?? 0)
                return knownDate<=date
            }
            let daily=all.filter{byDate($0)==date}
            let isKnown = !relevant.isEmpty
            let modes=Set(relevant.map{packaged($0) ? "envase":"unidad"})
            if modes.count>1 {
                warnings.append(name+": lotes con modos de conteo incompatibles")
            }
            let initial=rounded(relevant.reduce(0.0){n,l in
                let events=all.filter{$0["lotId"] as? String==l["id"] as? String}
                let today=events.filter{byDate($0)==date}
                let later=events.first(where:{byDate($0)>date})
                let atEnd=(later?["before"] as? [String:Any]) ?? l
                let before=(today.first?["before"] as? [String:Any]) ?? atEnd
                return n+balance(before)
            })
            let extraordinary=rounded(daily.filter{$0["kind"] as? String=="extraordinary"}
                .reduce(0.0){sum,m in
                    let before=m["before"] as? [String:Any] ?? [:]
                    return sum+(packaged(before)
                        ? (count(m["sealedAdded"]) ?? 0)
                        : (count(m["physicalChange"]) ?? 0))
                })
            let consumed=rounded(daily.filter{$0["kind"] as? String=="use"}
                .reduce(0.0){sum,m in
                    let before=m["before"] as? [String:Any] ?? [:]
                    return sum+(packaged(before)
                        ? (count(m["excelQuantity"]) ?? 0)
                        : (count(m["quantity"]) ?? 0))
                })
            if daily.contains(where:{$0["kind"] as? String=="adjustment"}) {
                warnings.append(name+": ajustes auditados del día pendientes de conciliación en el reporte")
            }
            let total=rounded(initial+extraordinary)
            let closing=rounded(total-consumed)
            let actual=rounded(relevant.reduce(0.0){sum,l in
                let later=all.first(where:{$0["lotId"] as? String==l["id"] as? String &&
                                            byDate($0)>date})
                let previous=(later?["before"] as? [String:Any]) ?? l
                return sum+balance(previous)
            })
            if actual != closing {
                warnings.append(name+": saldo calculado distinto del saldo histórico; revisar aperturas y ajustes")
            }
            let value=counts[code]
            if let value, !value.isFinite || value<0 {
                throw N2NursingReportError.invalidPhysicalCount
            }
            let fs=value.map{rounded($0-closing)}
            let expiry=relevant.compactMap{$0["expires"] as? String}
                .filter{!$0.isEmpty}.sorted().first ?? ""
            rows.append(N2NursingRow(code:code,name:name,donated:false,
                       stockKnown:isKnown,initial:initial,extraordinary:extraordinary,
                       total:total,consumed:consumed,closing:closing,expiry:expiry,fs:fs))
        }
        return N2NursingReport(date:date,periodEnd:nil,rows:rows,warnings:warnings)
    }
    public static func daily(snapshot:Data,catalog:Data,date:String,
                             physicalCounts:[String:Double]=[:],site:String="")throws->N2NursingReport {
        let (lots,moves,products)=try decoded(snapshot,catalog,site:site)
        return try day(lots:lots,moves:moves,catalog:products,date:date,
                       counts:physicalCounts)
    }
    public static func range(snapshot:Data,catalog:Data,start:String,end:String,
                             physicalCounts:[String:Double]=[:],site:String="")throws->N2NursingReport {
        guard iso(start),iso(end),start<=end else{
            throw N2NursingReportError.invalidDay
        }
        let (lots,moves,products)=try decoded(snapshot,catalog,site:site)
        let df=ISO8601DateFormatter()
        df.formatOptions=[.withFullDate]
        guard let begin=df.date(from:start),let finish=df.date(from:end) else{
            throw N2NursingReportError.invalidDay
        }
        let days=Int(round(finish.timeIntervalSince(begin)/86400.0))+1
        guard (1...366).contains(days) else{throw N2NursingReportError.unsupportedRange}
        var reports:[N2NursingReport]=[]
        for i in 0..<days {
            let date=df.string(from:begin.addingTimeInterval(Double(i)*86400))
            reports.append(try day(lots:lots,moves:moves,catalog:products,
                                   date:date,counts:[:]))
        }
        var warnings=[String]()
        for report in reports {
            for w in report.warnings where !warnings.contains(w) {warnings.append(w)}
        }
        let first=reports[0]
        var resulting:[N2NursingRow]=[]
        for (i,begin) in first.rows.enumerated() {
            let series=reports.map{$0.rows[i]}
            let known=series.allSatisfy{$0.stockKnown==begin.stockKnown} && begin.stockKnown
            if series.count>1 {
                for j in 1..<series.count {
                    if series[j-1].stockKnown != series[j].stockKnown ||
                      (series[j-1].stockKnown &&
                       rounded(series[j-1].closing) != rounded(series[j].initial)) {
                        warnings.append(begin.name + ": diferencia histórica entre " +
                                        reports[j-1].date + " y " + reports[j].date)
                    }
                }
            }
            let incoming=rounded(series.reduce(0){$0+($1.stockKnown ? $1.extraordinary:0)})
            let out=rounded(series.reduce(0){$0+($1.stockKnown ? $1.consumed:0)})
            let total=rounded(begin.initial+incoming),closing=rounded(total-out)
            if known && rounded(closing) != rounded(series.last!.closing) {
                warnings.append(begin.name+": saldo final del período diferente del saldo diario.")
            }
            let physical=physicalCounts[begin.code]
            if let physical,!physical.isFinite || physical<0 {
                throw N2NursingReportError.invalidPhysicalCount
            }
            resulting.append(N2NursingRow(code:begin.code,name:begin.name,
                donated:false,stockKnown:known,initial:begin.initial,
                extraordinary:incoming,total:total,consumed:out,closing:closing,
                expiry:series.last!.expiry,fs:physical.map{rounded($0-closing)}))
        }
        var unique=[String]()
        for s in warnings where !unique.contains(s){unique.append(s)}
        return N2NursingReport(date:start,periodEnd:end,
                               rows:resulting,warnings:unique)
    }
}

