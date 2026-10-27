import Foundation
import CoreFoundation

/// Audit-log editor for the independent 432-product Indicator, not the nursing
/// Kardex. Every correction appends a void event and preserves the original.
public struct N2ReconciliationEventRow:Sendable,Identifiable {
    public let id:String
    public let kind:String
    public let subdivision:String
    public let code:String
    public let date:String
    public let quantity:Int
    public let document:String
    public let voided:Bool
}
public enum N2ReconciliationEditError:Error,Equatable {
    case invalidSource, invalidEvent,invalidCatalog,duplicateEvent
    case missingOriginal, invalidPeriod,overflow
}
public enum N2NativeReconciliationEditor {
    private static func value(_ v:Any?)->String {v as? String ?? ""}
    private static func number(_ v:Any?)->Double? {
        guard let n=v as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite else{return nil}
        return n.doubleValue
    }
    private static func day(_ date:String)->Bool {
        guard date.range(of:#"^\d{4}-\d{2}-\d{2}$"#,
            options:.regularExpression) != nil else{return false}
        let c=date.split(separator:"-").compactMap{Int($0)}
        guard c.count==3 else{return false}
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(secondsFromGMT:0)!
        guard let dateValue=calendar.date(from:DateComponents(year:c[0],month:c[1],day:c[2])) else{
            return false
        }
        let check=calendar.dateComponents([.year,.month,.day],from:dateValue)
        return check.year==c[0] && check.month==c[1] && check.day==c[2]
    }
    private static func parsed(_ snapshot:Data)throws->[String:Any] {
        guard (try? N2VersionedSnapshotAudit.inspect(snapshot)) != nil,
              (try? N1fLosslessFieldGate.inspect(snapshot)) != nil,
              let root=try? JSONSerialization.jsonObject(with:snapshot)
                    as? [String:Any],
              root["ambulatoryReconciliation"] is [[String:Any]] else{
            throw N2ReconciliationEditError.invalidSource
        }
        return root
    }
    private static func valid(_ events:[[String:Any]],catalog:Set<String>)throws
        ->Set<String> {
        guard events.count<=1200 else{throw N2ReconciliationEditError.overflow}
        var ids=Set<String>(),all=[String:[String:Any]](),
            voided=Set<String>()
        for row in events {
            let id=value(row["id"]),kind=value(row["kind"]),
                site=value(row["subdivision"]),date=value(row["date"]),
                code=value(row["code"]),doc=value(row["document"]),
                expires=value(row["expires"]),until=value(row["periodEnd"]),
                target=value(row["voidOf"]),reason=value(row["reason"])
            guard !id.isEmpty,id.utf8.count<=120,
                  ids.insert(id).inserted,
                  ["opening","receipt","count","review","void"].contains(kind),
                  ["LA VENTUROSA","PLVENTUROSA"].contains(site),
                  day(date),(8...240).contains(reason.count),
                  let at=number(row["at"]),at>0,at.rounded()==at,
                  at<=9_007_199_254_740_991,
                  let q=number(row["quantity"]),q>=0,q<=10_000_000,
                  q.rounded()==q else{throw N2ReconciliationEditError.invalidEvent}
            switch kind {
            case "opening","count":
                guard catalog.contains(code),doc.isEmpty,expires.isEmpty,
                      until.isEmpty,target.isEmpty else {
                    throw N2ReconciliationEditError.invalidEvent
                }
            case "receipt":
                guard catalog.contains(code),q>0,
                      (3...100).contains(doc.count),
                      (expires.isEmpty || day(expires)),
                      until.isEmpty,target.isEmpty else{
                    throw N2ReconciliationEditError.invalidEvent
                }
            case "review":
                guard code.isEmpty,doc.isEmpty,expires.isEmpty,
                      target.isEmpty,q==0,day(until),until>=date else{
                    throw N2ReconciliationEditError.invalidPeriod
                }
            case "void":
                guard code.isEmpty,doc.isEmpty,expires.isEmpty,
                      until.isEmpty,q==0,!target.isEmpty,
                      let original=all[target],
                      value(original["kind"]) != "void",
                      value(original["subdivision"])==site,
                      (number(original["at"]) ?? 0)<=at,
                      voided.insert(target).inserted else{
                    throw N2ReconciliationEditError.missingOriginal
                }
            default:throw N2ReconciliationEditError.invalidEvent
            }
            all[id]=row
        }
        let active=events.filter {
            value($0["kind"]) != "void" && !voided.contains(value($0["id"]))
        }
        var keys=Set<String>()
        for e in active {
            let kind=value(e["kind"]),code=value(e["code"])
            let extra=kind=="review" ? value(e["periodEnd"]) :
                      (kind=="receipt" ? value(e["document"]).uppercased() : "")
            let key=[value(e["subdivision"]),kind,value(e["date"]),code,extra]
                .joined(separator:"|")
            guard keys.insert(key).inserted else{
                throw N2ReconciliationEditError.duplicateEvent
            }
        }
        let reviews=active.filter{value($0["kind"])=="review"}
        for receipt in active where value(receipt["kind"])=="receipt" {
            if reviews.contains(where:{r in
                value(r["subdivision"])==value(receipt["subdivision"]) &&
                value(receipt["date"])>=value(r["date"]) &&
                value(receipt["date"])<=value(r["periodEnd"]) &&
                (number(receipt["at"]) ?? 0)>(number(r["at"]) ?? 0)
            }){throw N2ReconciliationEditError.invalidPeriod}
        }
        return voided
    }
    public static func list(snapshot:Data)throws->[N2ReconciliationEventRow] {
        let root=try parsed(snapshot)
        let events=root["ambulatoryReconciliation"] as? [[String:Any]] ?? []
        // A read-only listing still verifies nonclinical basic shape, but
        // catalog-specific validation occurs on every subsequent append.
        let cancelled=Set(events.filter{value($0["kind"])=="void"}
                        .map{value($0["voidOf"])})
        return events.compactMap{e->N2ReconciliationEventRow? in
            guard let id=e["id"] as? String,
                  let count=number(e["quantity"]) else{return nil}
            return N2ReconciliationEventRow(
                id:id,kind:value(e["kind"]),
                subdivision:value(e["subdivision"]),
                code:value(e["code"]),date:value(e["date"]),
                quantity:Int(count),document:value(e["document"]),
                voided:cancelled.contains(id))
        }.reversed()
    }
    public static func append(snapshot:Data,event:Data,
                              catalog:Data)throws->Data {
        var root=try parsed(snapshot)
        guard var entries=root["ambulatoryReconciliation"] as? [[String:Any]],
              let input=try? JSONSerialization.jsonObject(with:event)
                  as? [String:Any],
              let products=try? JSONSerialization.jsonObject(with:catalog)
                  as? [[String:Any]],products.count==432 else{
            throw N2ReconciliationEditError.invalidSource
        }
        let codes=Set(products.compactMap{$0["code"] as? String})
        guard codes.count==432 else{throw N2ReconciliationEditError.invalidCatalog}
        entries.append(input)
        _=try valid(entries,catalog:codes)
        root["ambulatoryReconciliation"]=entries
        let data=try JSONSerialization.data(withJSONObject:root,options:[.sortedKeys])
        guard (try? N2VersionedSnapshotAudit.inspect(data)) != nil,
              (try? N1fLosslessFieldGate.inspect(data)) != nil else{
            throw N2ReconciliationEditError.invalidSource
        }
        return data
    }
}
