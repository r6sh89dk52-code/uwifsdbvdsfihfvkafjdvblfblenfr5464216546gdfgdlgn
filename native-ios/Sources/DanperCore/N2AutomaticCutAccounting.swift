import Foundation
import CoreFoundation

/// Read-only consumption accounting for ONE inventory and its dated reports.
/// An attention in "saved" status confirms its clinical use exactly once,
/// irrespective of whether a matching lot was known when it was recorded.
/// A recorded FEFO movement is preferred when computing packaged Excel units.
public enum N2AutomaticCutAccounting {
    public enum Failure:Error,Equatable {
        case invalidSource,invalidMappings,invalidDate,duplicateLine
    }
    public struct Row:Equatable,Sendable {
        public let code:String
        public let name:String
        public let currentCount:Double?
        public let clinicalUnits:Double
        public let reportedUse:Double
        public let received:Double
        public let adjusted:Double
        public let opening:Double?
        public let unlinkedItems:Int
        public let unknownContainerOpenings:Int
        public let usesByDay:[String:Double]
    }
    public struct Result:Sendable {
        public let start:String
        public let end:String
        public let rows:[Row]
        public let unmatchedClinicalLines:Int
        public var hasUnresolvedHistory:Bool {
            unmatchedClinicalLines>0 || rows.contains{$0.unknownContainerOpenings>0}
        }
    }
    private static func num(_ value:Any?)->Double? {
        guard let n=value as? NSNumber,
              CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite else {return nil}
        return n.doubleValue
    }
    private static func round(_ n:Double)->Double {(n*1000).rounded()/1000}
    private static func day(_ ms:Double)->String {
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(identifier:"America/Lima")!
        let parts=calendar.dateComponents([.year,.month,.day],
            from:Date(timeIntervalSince1970:ms/1000))
        return String(format:"%04d-%02d-%02d",parts.year!,parts.month!,parts.day!)
    }
    public static func calculate(snapshot:Data,mappings:Data,
                                 through date:String)throws->Result {
        let period=try N2KardexCutPreview.period(for:date)
        guard let root=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let lots=root["stockLots"] as? [[String:Any]],
              let movements=root["stockMovements"] as? [[String:Any]],
              let visits=root["attentions"] as? [[String:Any]],
              let approved=try? JSONSerialization.jsonObject(with:mappings)
                                  as? [[String:Any]],approved.count==86,
              (try? N1eLegacyClinicalAudit.inspect(snapshot)) != nil,
              (try? N1fLosslessFieldGate.inspect(snapshot)) != nil else{
            throw Failure.invalidSource
        }
        struct Key:Hashable {
            let clinicalCode:String
            let name:String
            let unit:String
        }
        var catalog=[Key:[(code:String,name:String)]]()
        for map in approved {
            guard let c=map["clinicalCode"] as? String,
                  let name=map["clinicalName"] as? String,
                  let unit=map["clinicalUnit"] as? String,
                  let code=map["kardexCode"] as? String,
                  let kardexName=map["kardexName"] as? String else{
                throw Failure.invalidMappings
            }
            catalog[Key(clinicalCode:c,name:name,unit:unit),default:[]]
                .append((code:code,name:kardexName))
        }
        struct Acc {
            var name=""
            var used=0.0,clinical=0.0,received=0.0,adjusted=0.0
            var unlinked=0,unknownPackage=0
            var daily=[String:Double]()
        }
        var totals=[String:Acc]()
        var ids=Set<String>()
        var unresolved=0
        let linked=Dictionary(grouping:movements.filter{
            $0["kind"] as? String=="use" && $0["dispenseRef"] != nil
        },by:{movement -> String in
            let ref=movement["dispenseRef"] as? [String:Any] ?? [:]
            let attentionID=ref["attentionId"] as? String ?? ""
            let itemID=ref["itemId"] as? String ?? ""
            return [attentionID,itemID].joined(separator:"\u{001F}")
        })
        for visit in visits where visit["status"] as? String=="saved" {
            guard let visitID=visit["id"] as? String,
                  let visitDay=visit["date"] as? String,
                  let items=visit["items"] as? [[String:Any]] else{
                throw Failure.invalidSource
            }
            guard visitDay>=period.start,visitDay<=date else{continue}
            for item in items {
                guard let itemID=item["id"] as? String,
                      let code=item["code"] as? String,
                      let name=item["name"] as? String,
                      let unit=item["unit"] as? String,
                      let n=num(item["quantity"]),n>0,
                      n.rounded()==n else {throw Failure.invalidSource}
                let id=visitID+"\u{001F}"+itemID
                guard ids.insert(id).inserted else{throw Failure.duplicateLine}
                let events=linked[id] ?? []
                let candidates=catalog[Key(clinicalCode:code,name:name,unit:unit)] ?? []
                let match:(code:String,name:String)
                if let event=events.first,let inventoryCode=event["code"] as? String,
                   let inventoryName=event["name"] as? String {
                    match=(inventoryCode,inventoryName)
                }else if candidates.count==1 {match=candidates[0]}
                else {unresolved+=1;continue}
                var line=totals[match.code] ?? Acc()
                line.name=match.name
                line.clinical+=n
                if !events.isEmpty {
                    // Recorded opening/reuse R has authority for containers.
                    let debit=events.reduce(0.0){$0+(num($1["excelQuantity"]) ?? 0)}
                    line.used+=debit
                    line.daily[visitDay,default:0]+=debit
                }else if ["UND","TBL","PAR"].contains(unit.uppercased()) &&
                    !lots.contains(where:{$0["code"] as? String==match.code &&
                        N2ContainerAccounting.isContainer(unit:$0["catalogUnit"] as? String ?? "")}) {
                    // A saved attention confirms its units, even when it was
                    // entered before its initial lot was catalogued.
                    line.used+=n
                    line.daily[visitDay,default:0]+=n
                    line.unlinked+=1
                }else {
                    // Open bottle=1, reuse=0 cannot be recovered without an
                    // opening movement. Clinical use remains confirmed.
                    line.unlinked+=1
                    line.unknownPackage+=1
                }
                totals[match.code]=line
            }
        }
        for m in movements {
            guard let code=m["code"] as? String,
                  let at=num(m["at"]),
                  (period.start...date).contains(day(at)) else{continue}
            var line=totals[code] ?? Acc()
            if let name=m["name"] as? String {line.name=name}
            if m["kind"] as? String=="extraordinary" {
                let before=m["before"] as? [String:Any] ?? [:]
                let quantity=N2ContainerAccounting.isContainer(unit:before["catalogUnit"] as? String ?? "") ?
                    (num(m["sealedAdded"]) ?? 0) : (num(m["physicalChange"]) ?? 0)
                line.received+=quantity
            }else if m["kind"] as? String=="adjustment" {
                let before=m["before"] as? [String:Any] ?? [:],after=m["after"] as? [String:Any] ?? [:]
                line.adjusted += N2ContainerAccounting.isContainer(unit:before["catalogUnit"] as? String ?? "") ?
                    (num(after["sealedContainers"]) ?? 0)-(num(before["sealedContainers"]) ?? 0) : (num(m["physicalChange"]) ?? 0)
            }
            totals[code]=line
        }
        let lotsByCode=Dictionary(grouping:lots,by:{
            $0["code"] as? String ?? ""
        })
        for (code,stock) in lotsByCode where !code.isEmpty {
            if totals[code]==nil {totals[code]=Acc()}
            if totals[code]?.name.isEmpty==true {
                totals[code]?.name=stock.first?["name"] as? String ?? code
            }
        }
        let rows=totals.map {code,item -> Row in
            let associated=(lotsByCode[code] ?? []).compactMap {lot -> [String:Any]? in
                let events=movements.filter{$0["lotId"] as? String==lot["id"] as? String}
                    .sorted{(num($0["at"]) ?? 0)<(num($1["at"]) ?? 0)}
                let initial=(events.first?["before"] as? [String:Any]) ?? lot
                guard day(num(initial["updatedAt"]) ?? 0)<=date else{return nil}
                let later=events.first{day(num($0["at"]) ?? 0)>date}
                return (later?["before"] as? [String:Any]) ?? lot
            }
            // Current counted stock is known only if a lot is on record.
            // Packaged material needs opening-unit evidence, not mL totals.
            let count:Double?=associated.isEmpty ? nil : associated.reduce(0.0){sum,l in
                let sealed=num(l["sealedContainers"]) ?? 0
                let loose=num(l["looseUnits"]) ?? 0
                let opened=num(l["openedRemaining"]) ?? 0
                let capacity=num(l["unitsPerContainer"]) ?? 1
                let unit=(l["catalogUnit"] as? String ?? "").uppercased()
                // Official Kardex counts sealed FCO/CJA when a new
                // container is opened (R=1); never mistake its 100 mL
                // capacity for 100 Kardex units.
                if !["UND","TBL","PAR"].contains(unit) {return sum+sealed}
                return sum+sealed*capacity+loose+opened
            }
            let correctable=count != nil && item.unknownPackage==0
            let opening=correctable ? round(count!+item.used-item.received-item.adjusted) : nil
            return Row(code:code,name:item.name,currentCount:count.map(round),
                clinicalUnits:round(item.clinical),reportedUse:round(item.used),
                received:round(item.received),adjusted:round(item.adjusted),
                opening:opening.flatMap{$0>=0 ? $0:nil},
                unlinkedItems:item.unlinked,
                unknownContainerOpenings:item.unknownPackage,
                usesByDay:item.daily.mapValues(round))
        }.sorted{$0.code<$1.code}
        return Result(start:period.start,end:date,rows:rows,
                      unmatchedClinicalLines:unresolved)
    }
}
