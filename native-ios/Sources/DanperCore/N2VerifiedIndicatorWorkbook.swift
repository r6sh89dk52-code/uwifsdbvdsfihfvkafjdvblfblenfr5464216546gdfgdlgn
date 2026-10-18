import Foundation
import CoreFoundation

/// Fail-closed bridge between the complete N2 encrypted state and the
/// ten-sheet official workbook. Does not create missing stock or R values.
public enum N2VerifiedIndicatorWorkbook {
    public enum Failure:Error,Equatable {
        case invalidSnapshot,invalidCatalog,invalidPeriod,invalidVisit
        case unreviewedPeriod,unverifiedDelivery,invalidReconciliation
        case ambiguousSite,missingSelection,invalidWorkbook
    }
    public struct Result:Sendable {
        public let xlsx:Data
        public let provisional:Bool
        public let pendingLines:Int
        public let rows:Int
        public let visits:Int
        public let missingOpening:Int
        public let missingClosingCount:Int
    }

    private static func numeric(_ value:Any?)->Double? {
        guard let n=value as? NSNumber,CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite else{return nil}
        return n.doubleValue
    }
    private static func string(_ v:Any?)->String {v as? String ?? ""}
    private static func integer(_ v:Any?)->Int? {
        guard let n=numeric(v),n>=0,n<=10_000_000,n.rounded()==n else{
            return nil
        }
        return Int(n)
    }
    private static func validDay(_ value:String)->Bool {
        guard value.range(of:#"^\d{4}-\d{2}-\d{2}$"#,
                          options:.regularExpression) != nil else{return false}
        var calendar=Calendar(identifier:.gregorian)
        calendar.timeZone=TimeZone(secondsFromGMT:0)!
        let parts=value.split(separator:"-").compactMap{Int($0)}
        guard parts.count==3,
              let date=calendar.date(from:DateComponents(
                year:parts[0],month:parts[1],day:parts[2])) else{return false}
        return calendar.dateComponents([.year,.month,.day],from:date).year==parts[0]
            && calendar.dateComponents([.year,.month,.day],from:date).month==parts[1]
            && calendar.dateComponents([.year,.month,.day],from:date).day==parts[2]
    }
    private static func excelDate(_ iso:String)->Double {
        let c=iso.split(separator:"-").compactMap{Int($0)}
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(secondsFromGMT:0)!
        let date=cal.date(from:DateComponents(year:c[0],month:c[1],day:c[2]))!
        let epoch=cal.date(from:DateComponents(year:1899,month:12,day:30))!
        return Double(cal.dateComponents([.day],from:epoch,to:date).day!)
    }
    private static func time(_ s:String,optional:Bool=false)throws->Any {
        if optional && s.isEmpty{return ""}
        let parts=s.split(separator:":").compactMap{Int($0)}
        guard s.range(of:#"^([01]\d|2[0-3]):[0-5]\d$"#,
                      options:.regularExpression) != nil,parts.count==2 else{
            throw Failure.invalidVisit
        }
        return Double(parts[0]*60+parts[1])/1440.0
    }
    private static func period(_ start:String,_ end:String)throws {
        guard validDay(start),validDay(end),start<=end,
              start>="1900-03-01" else {throw Failure.invalidPeriod}
    }
    private static func recordID(_ attention:String,_ item:String?)throws->String {
        let parts:[Any]=[attention,item.map{$0 as Any} ?? NSNull()]
        let bytes=try JSONSerialization.data(withJSONObject:parts)
        return String(decoding:bytes,as:UTF8.self)
    }

    public static func export(snapshot:Data,products:Data,mappings:Data,
        template:Data,start:String,end:String,subdivision:String,
        selectedVisitIDs:Set<String>,allowPending:Bool=false)throws->Result {
        try period(start,end)
        guard ["LA VENTUROSA","PLVENTUROSA","AMBAS"].contains(subdivision) else{
            throw Failure.ambiguousSite
        }
        guard !selectedVisitIDs.isEmpty else{throw Failure.missingSelection}
        // Source quantities remain tied to the original FEFO movements.
        // Any disputed medication/dose is barred from the official workbook.
        let pending=try N2ClinicalCorrections.pendingDiscrepancies(snapshot)
        guard pending.isDisjoint(with:selectedVisitIDs) else{
            throw Failure.unverifiedDelivery
        }
        let clinical=try N2ClinicalCorrections.effectiveSnapshot(snapshot)
        let parity=try N1eLegacyClinicalAudit.inspect(clinical)
        _=try N1fLosslessFieldGate.inspect(clinical)
        guard let source=try? JSONSerialization.jsonObject(with:clinical)
                    as? [String:Any],
              let visits=source["attentions"] as? [[String:Any]],
              let movement=source["stockMovements"] as? [[String:Any]],
              let recon=source["ambulatoryReconciliation"] as? [[String:Any]],
              let incidents=source["deliveryIncidents"] as? [[String:Any]],
              incidents.isEmpty,
              let mapped=try? JSONSerialization.jsonObject(with:mappings)
                    as? [[String:Any]],mapped.count==86,
              let catalogue=try? JSONSerialization.jsonObject(with:products)
                    as? [[String:Any]],catalogue.count==432 else {
            throw Failure.invalidSnapshot
        }
        let productMap=Dictionary(uniqueKeysWithValues:catalogue.compactMap { p
            -> (String,[String:Any])? in
            guard let code=p["code"] as? String else{return nil}
            return (code,p)
        })
        guard productMap.count==432 else{throw Failure.invalidCatalog}
        var approved=Set<String>()
        for link in mapped {
            guard let a=link["clinicalCode"] as? String,
                  let b=link["kardexCode"] as? String,
                  !a.isEmpty,!b.isEmpty else{throw Failure.invalidCatalog}
            approved.insert(a+"|"+b)
        }
        var linesByItem=[String:Double]()
        for m in movement {
            guard m["kind"] as? String=="use",
                  let ref=m["dispenseRef"] as? [String:Any] else{continue}
            let aid=string(ref["attentionId"]),item=string(ref["itemId"])
            guard !aid.isEmpty,!item.isEmpty,
                  let quantity=numeric(m["excelQuantity"]),quantity>=0,
                  let medical=ref["clinicalCode"] as? String,
                  let nursing=m["code"] as? String,
                  nursing==medical || approved.contains(medical+"|"+nursing)
            else{throw Failure.unverifiedDelivery}
            let key=aid+"\u{001F}"+item
            linesByItem[key,default:0]+=quantity
        }
        var parityR=[String:Double?]()
        var pointer=0
        for visit in visits where string(visit["status"])=="saved" {
            let aid=string(visit["id"])
            guard !aid.isEmpty,let items=visit["items"] as? [[String:Any]] else{
                throw Failure.invalidVisit
            }
            for item in items {
                guard pointer<parity.consumptionR.count else {
                    throw Failure.unverifiedDelivery
                }
                let key=aid+"\u{001F}"+string(item["id"])
                guard parityR[key]==nil else{throw Failure.invalidVisit}
                parityR[key]=parity.consumptionR[pointer]
                pointer+=1
            }
        }
        guard pointer==parity.consumptionR.count else{
            throw Failure.unverifiedDelivery
        }
        var selected=[[String:Any]]()
        for v in visits where string(v["status"])=="saved" {
            if selectedVisitIDs.contains(string(v["id"])) {
                selected.append(v)
            }
        }
        guard selected.count==selectedVisitIDs.count else{
            throw Failure.missingSelection
        }
        selected=selected.filter{string($0["date"])>=start &&
                                 string($0["date"])<=end}
        guard !selected.isEmpty,selected.count<=10_000 else{
            throw Failure.missingSelection
        }
        selected.sort {v,w in
            (string(v["date"]),string(v["time"]),string(v["id"])) <
            (string(w["date"]),string(w["time"]),string(w["id"]))
        }
        var pendingLines=0
        var pendingNotes=[String]()
        var frequencies=[String:Int](),frequencyByID=[String:Int]()
        for visit in visits.filter({string($0["status"])=="saved"}).sorted(by:{
            (string($0["date"]),string($0["time"]),string($0["id"])) <
            (string($1["date"]),string($1["time"]),string($1["id"]))
        }) {
            let worker=visit["worker"] as? [String:Any] ?? [:]
            let key=string(visit["date"])+"|"+string(worker["dni"])
            frequencies[key,default:0]+=1
            frequencyByID[string(visit["id"])]=frequencies[key]
        }
        var seenIDs=Set<String>(),
            consumption=[String:Int](),consumptionBySite=[String:Int](),
            output=[[String:Any]]()
        let freq=["PRIMERA","SEGUNDA","TERCERA","CUARTA","QUINTA"]
        for visit in selected {
            let aid=string(visit["id"]),iso=string(visit["date"])
            guard validDay(iso),seenIDs.insert(aid).inserted,
                  let worker=visit["worker"] as? [String:Any],
                  let dni=worker["dni"] as? String,dni.count==8,
                  dni.utf8.allSatisfy({(48...57).contains($0)}),
                  !string(worker["name"]).isEmpty,
                  !string(visit["diagnosis"]).isEmpty,
                  let items=visit["items"] as? [[String:Any]],
                  items.count<=1000,
                  (subdivision=="AMBAS" ?
                    ["LA VENTUROSA","PLVENTUROSA"].contains(string(worker["site"])) :
                    ["",subdivision].contains(string(worker["site"]))) else{
                throw Failure.invalidVisit
            }
            let sourceSite=subdivision=="AMBAS" ? string(worker["site"]) : subdivision
            let count=frequencyByID[aid] ?? 1
            let ageString=String(describing:worker["age"] ?? "")
            let birthday=string(worker["birthDate"])
            let age=N2WorkerAge.years(birthDate:birthday,on:iso) ??
                Int(ageString).flatMap{(0...120).contains($0) ? $0 : nil}
            let procedures=visit["standaloneProcedures"] as? [String] ?? []
            for row in items.isEmpty ? [[:]] : items {
                let itemID=string(row["id"]),hasItem = !items.isEmpty
                var code="",name="",type="",procedure=""
                var physical:Any=""
                if hasItem {
                    guard !itemID.isEmpty,
                          let original=productMap[string(row["code"])],
                          string(row["name"]).trimmingCharacters(
                              in:.whitespaces)==string(original["name"]).trimmingCharacters(
                                  in:.whitespaces),
                          string(row["unit"]).trimmingCharacters(
                              in:.whitespaces)==string(original["unit"]).trimmingCharacters(
                                  in:.whitespaces) else{
                        throw Failure.invalidCatalog
                    }
                    code=string(original["code"]);name=string(original["name"])
                    type=string(original["unit"])
                    procedure=string(row["procedure"])
                    guard !procedure.isEmpty,
                          integer(row["quantity"]) != nil else{
                        throw Failure.invalidVisit
                    }
                    let key=aid+"\u{001F}"+itemID
                    if let audited=parityR[key],let value=audited,
                       let sum=linesByItem[key],abs(sum-value)<0.0001,
                       value.rounded()==value,value>=0 {
                        physical=value
                        consumption[code,default:0]+=Int(value)
                        consumptionBySite[sourceSite+"|"+code,default:0]+=Int(value)
                    } else if allowPending,let declared=integer(row["quantity"]),declared>0 {
                        physical=declared
                        consumption[code,default:0]+=declared
                        consumptionBySite[sourceSite+"|"+code,default:0]+=declared
                        pendingLines+=1
                        pendingNotes.append(aid+" / "+code+" / "+name+": R declarado, sin salida física confirmada")
                    } else {throw Failure.unverifiedDelivery}
                } else {
                    procedure=procedures.joined(separator:" / ")
                }
                let detail=["INYECTABLE","CURACION DE HERIDA","SUTURAS",
                            "EXTRACCION DE CUERPO EXTRAÑO",
                            "RETIRO DE PUNTOS DE SUTURA"].contains(procedure)
                    ? "INSUMOS":"-"
                let pTime=try time(string(visit["permissionTime"]),optional:true)
                let fields:[Any]=[
                    sourceSite,string(worker["area"]),"","",
                    string(worker["labor"]),excelDate(iso),try time(string(visit["time"])),
                    dni,string(worker["name"]),age.map{$0 as Any} ?? "",
                    string(worker["sex"]),string(worker["ubigeo"]),
                    string(visit["category"]),string(visit["system"]),
                    string(visit["segment"]),code,name,physical,
                    count<=5 ? freq[count-1]:"REVISAR",
                    procedure,detail,string(visit["permission"]),
                    string(visit["workStatus"]),pTime,
                    visit["blueBandage"] as? Bool == true ? "SI":"NO",
                    visit["returned"] as? Bool == true ? "SI":"NO",
                    visit["photoSent"] as? Bool == true ? "SI":"NO",
                    string(visit["responsibleDni"]),string(visit["responsible"]),
                    string(visit["diagnosis"])
                ]
                guard fields.count==30 else{throw Failure.invalidVisit}
                let key=try recordID(aid,hasItem ? itemID : nil)
                output.append(["id":key,"cells":fields])
            }
        }
        guard output.count<=10_000 else{throw Failure.invalidVisit}

        // Events are authoritative. A review only attests the exact date cut;
        // it never supplies a fabricated opening or count for missing products.
        var ids=Set<String>(),byID=[String:[String:Any]](),
            voided=Set<String>()
        for event in recon {
            let id=string(event["id"]),kind=string(event["kind"]),
                site=string(event["subdivision"]),date=string(event["date"]),
                code=string(event["code"]),reason=string(event["reason"])
            guard !id.isEmpty,ids.insert(id).inserted,
                  ["opening","receipt","count","review","void"].contains(kind),
                  ["LA VENTUROSA","PLVENTUROSA"].contains(site),
                  validDay(date),reason.count>=8,
                  let quantity=integer(event["quantity"]),
                  let time=numeric(event["at"]),time>0,
                  time.rounded()==time else{
                throw Failure.invalidReconciliation
            }
            if kind=="void" {
                let target=string(event["voidOf"])
                guard code.isEmpty,quantity==0,
                      string(event["document"]).isEmpty,
                      string(event["expires"]).isEmpty,
                      string(event["periodEnd"]).isEmpty,
                      let previous=byID[target],
                      string(previous["kind"]) != "void",
                      string(previous["subdivision"])==site,
                      (numeric(previous["at"]) ?? 0)<=time,
                      voided.insert(target).inserted else{
                    throw Failure.invalidReconciliation
                }
            }else if kind=="review" {
                guard code.isEmpty,quantity==0,
                      string(event["document"]).isEmpty,
                      string(event["expires"]).isEmpty,
                      string(event["voidOf"]).isEmpty,
                      validDay(string(event["periodEnd"])),
                      string(event["periodEnd"])>=date else{
                    throw Failure.invalidReconciliation
                }
            }else{
                guard productMap[code] != nil,
                      string(event["periodEnd"]).isEmpty,
                      string(event["voidOf"]).isEmpty else{
                    throw Failure.invalidReconciliation
                }
                if kind=="receipt" {
                    guard quantity>0,string(event["document"]).count>=3,
                          string(event["expires"]).isEmpty ||
                            validDay(string(event["expires"])) else{
                        throw Failure.invalidReconciliation
                    }
                }else {
                    guard string(event["document"]).isEmpty,
                          string(event["expires"]).isEmpty else{
                        throw Failure.invalidReconciliation
                    }
                }
            }
            byID[id]=event
        }
        let active=recon.filter {
            string($0["kind"]) != "void" &&
            !voided.contains(string($0["id"]))
        }
        var keys=Set<String>()
        for event in active {
            let kind=string(event["kind"]),code=string(event["code"])
            let unique=[
                string(event["subdivision"]),kind,string(event["date"]),code,
                kind=="review" ? string(event["periodEnd"]) :
                     (kind=="receipt" ? string(event["document"]).uppercased() : "")
            ].joined(separator:"|")
            guard keys.insert(unique).inserted else{
                throw Failure.invalidReconciliation
            }
        }
        let reviews=active.filter{string($0["kind"])=="review"}
        for receipt in active where string(receipt["kind"])=="receipt" {
            if reviews.contains(where: { r in
                string(r["subdivision"])==string(receipt["subdivision"]) &&
                string(receipt["date"])>=string(r["date"]) &&
                string(receipt["date"])<=string(r["periodEnd"]) &&
                (numeric(receipt["at"]) ?? 0)>(numeric(r["at"]) ?? 0)
            }) {throw Failure.invalidReconciliation}
        }
        let atSite=active.filter{string($0["subdivision"])==subdivision}
        guard allowPending || atSite.contains(where:{string($0["kind"])=="review" &&
                 string($0["date"])==start &&
                 string($0["periodEnd"])==end}) else{
            throw Failure.unreviewedPeriod
        }
        var summary=[String:[String:Any]]()
        var openingCount=0,closingCount=0
        for item in catalogue {
            let code=string(item["code"]),used=consumption[code] ?? 0
            let openings=atSite.filter{string($0["kind"])=="opening" &&
                string($0["code"])==code && string($0["date"])==start}
            let ending=atSite.filter{string($0["kind"])=="count" &&
                string($0["code"])==code && string($0["date"])==end}
            let receipts=atSite.filter{string($0["kind"])=="receipt" &&
                string($0["code"])==code &&
                string($0["date"])>=start && string($0["date"])<=end}
                .sorted{ (string($0["date"]),numeric($0["at"]) ?? 0,string($0["id"])) <
                         (string($1["date"]),numeric($1["at"]) ?? 0,string($1["id"])) }
            guard openings.count<=1,ending.count<=1,receipts.count<=4 else {
                throw Failure.invalidReconciliation
            }
            let income=receipts.reduce(0){$0+(integer($1["quantity"]) ?? 0)}
            var row:[String:Any]=["code":code,"consumed":used,
                                   "receipts":income,"receiptDetails":receipts]
            if let opening=openings.first,let quantity=integer(opening["quantity"]) {
                let final=quantity+income-used
                guard final>=0 || allowPending else{throw Failure.invalidReconciliation}
                openingCount+=1
                row["opening"]=quantity
                if !allowPending {row["closing"]=final}
                if let count=ending.first,let actual=integer(count["quantity"]) {
                    row["difference"]=final-actual
                }
            }
            if let ending=ending.first,let count=integer(ending["quantity"]) {
                closingCount+=1
                row["count"]=count
            }
            summary[code]=row
        }
        guard allowPending || (openingCount>0 && closingCount>0) else {
            throw Failure.invalidReconciliation
        }
        let manifest:[String:Any]=[
            "schema":1,"catalog":catalogue,"byCode":summary,
            "reviewed":!allowPending,"provisional":allowPending,
            "start":start,"end":end,"subdivision":subdivision,
            "rows":output.count,"plan":["lines":output],"pendingNotes":pendingNotes
        ]
        let data=try JSONSerialization.data(withJSONObject:manifest)
        let built=try N1sFullExcelWriter.exportIndicator(base:template,manifest:data)
        guard built.sheetCount==10,built.writtenRows==output.count,
              built.xlsx.count>20_000,built.xlsx.starts(with:[0x50,0x4B,0x03,0x04]) else{
            throw Failure.invalidWorkbook
        }
        return Result(xlsx:built.xlsx,provisional:allowPending,pendingLines:pendingLines,rows:output.count,visits:selected.count,
                      missingOpening:432-openingCount,
                      missingClosingCount:432-closingCount)
    }
}

