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

    /// Mirrors Build 222: validate all historical incidents but block this
    /// export only when an incident targets a selected physical dispensing.
    /// A historic incident from an UNSELECTED attention stays in the ledger.
    static func hasIncidentInSelectedVisits(_ incidents:[[String:Any]],
        movements:[[String:Any]],selectedVisitIDs:Set<String>)throws->Bool {
        guard incidents.count<=500 else{throw Failure.invalidReconciliation}
        var incidentIDs=Set<String>(),linkedMovements=Set<String>()
        for incident in incidents {
            let id=string(incident["id"]),movementID=string(incident["movementId"]),
                attentionID=string(incident["attentionId"]),
                itemID=string(incident["itemId"]),
                reason=string(incident["reason"]),
                kind=string(incident["kind"])
            guard !id.trimmingCharacters(in:.whitespaces).isEmpty,
                  ["returned","discrepancy"].contains(kind),
                  !movementID.trimmingCharacters(in:.whitespaces).isEmpty,
                  movementID.count<=200,attentionID.count>=1,attentionID.count<=120,
                  itemID.count>=1,itemID.count<=120,
                  reason.trimmingCharacters(in:.whitespaces).count>=8,
                  reason.count<=240,
                  incident["stockRestored"] as? Bool == false,
                  let quantity=numeric(incident["quantity"]),quantity>=0,
                  kind=="returned" ? quantity>0 : quantity==0,
                  let time=numeric(incident["at"]),time>0,
                  time.rounded()==time,time<=9_007_199_254_740_991,
                  incidentIDs.insert(id).inserted,
                  linkedMovements.insert(movementID).inserted else{
                throw Failure.invalidReconciliation
            }
        }
        return movements.contains {m in
            guard let id=m["id"] as? String,linkedMovements.contains(id),
                  let ref=m["dispenseRef"] as? [String:Any],
                  let attention=ref["attentionId"] as? String else{return false}
            return selectedVisitIDs.contains(attention)
        }
    }

    /// Historical R is only a user's declaration for a provisional sheet.
    /// A recorded physical delivery takes priority and must not be counted twice.
    static func provisionalHistoricalR(
        _ record:N2PendingDispensingEvidence,
        lotCode:String,lotUnit:String,
        approvedCodes:Set<String>,alreadyLinked:Bool
    )->Int? {
        let r=record.newContainers ?? (record.confirmNewContainer ? 1 : 0)
        guard !alreadyLinked,approvedCodes.contains(lotCode),
              N2ContainerAccounting.isContainer(unit:lotUnit),
              (0...10_000).contains(r),
              r==0 || record.confirmNewContainer else{return nil}
        return r
    }

    /// Pure decision guard for an automatically certified inventory-wide cut.
    /// Source proof is checked separately for every stock product.
    static func eligibleForSharedClose(
        subdivision:String,start:String,end:String,today:String,
        selected:Set<String>,all:Set<String>,
        hasUnresolvedHistory:Bool
    )->Bool {
        guard subdivision=="AMBAS",end.hasSuffix("-08"),end<=today,
              selected==all,!selected.isEmpty,!hasUnresolvedHistory,
              let period=try? N2KardexCutPreview.period(for:end)
        else{return false}
        return period.start==start
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
        let parity=try N2VersionedSnapshotAudit.inspect(N2SimpleInventory.isActive(snapshot) ? snapshot:clinical)
        _=try N1fLosslessFieldGate.inspect(clinical)
        guard let source=try? JSONSerialization.jsonObject(with:clinical)
                    as? [String:Any],
              let visits=source["attentions"] as? [[String:Any]],
              let movement=source["stockMovements"] as? [[String:Any]],
              let recon=source["ambulatoryReconciliation"] as? [[String:Any]],
              let incidents=source["deliveryIncidents"] as? [[String:Any]],
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
        let operational=try N2OperationalMappings.read(snapshot)
        let stock=source["stockLots"] as? [[String:Any]] ?? []
        // A declaration made after an old attention is accounting evidence
        // (R=1 or R=0), not an invented physical delivery. It is eligible
        // only in an explicitly PROVISIONAL workbook.
        let historicalDeclarations=try N2PendingDispensingEvidence.read(snapshot:snapshot)
        let disputed=try hasIncidentInSelectedVisits(
            incidents,movements:movement,selectedVisitIDs:selectedVisitIDs)
        guard !disputed else{throw Failure.unverifiedDelivery}
        var approved=Set<String>()
        for link in mapped {
            guard let a=link["clinicalCode"] as? String,
                  let b=link["kardexCode"] as? String,
                  !a.isEmpty,!b.isEmpty else{throw Failure.invalidCatalog}
            approved.insert(a+"|"+b)
        }
        // User-approved batch identities are separate from the 86 official
        // associations, but the exported clinical event must still recognize
        // an actual FEFO movement produced for these reviewed products.
        for link in N2UserReviewedKardexLinks.links {
            approved.insert(link.clinicalCode+"|"+link.kardexID)
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
                  nursing==medical || approved.contains(medical+"|"+nursing) || operational.contains(where:{
                      $0.id==m["operationalMappingID"] as? String &&
                      $0.version==m["operationalMappingVersion"] as? Int &&
                      $0.clinicalCode==medical && $0.inventoryID==nursing
                  })
            else{throw Failure.unverifiedDelivery}
            let key=aid+"\u{001F}"+item
            linesByItem[key,default:0]+=quantity
        }
        if N2SimpleInventory.isActive(snapshot) {
            var index=0
            for visit in visits where string(visit["status"])=="saved" {
                for item in visit["items"] as? [[String:Any]] ?? [] {
                    if let value=parity.consumptionR[index] {linesByItem[string(visit["id"])+"\u{001F}"+string(item["id"])]=value}
                    index+=1
                }
            }
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
                    } else if linesByItem[key] != nil {
                        // A real movement with mismatched R/evidence is a
                        // contradiction, not merely an absent delivery.
                        // Never silently reclassify such a line as pending.
                        throw Failure.unverifiedDelivery
                    } else if allowPending,N2SimpleInventory.isActive(snapshot) {
                        pendingLines+=1
                        pendingNotes.append("\(aid) / \(code): R PENDIENTE; consumo físico no verificado en el régimen consolidado. Sin salida inventada ni descuento retroactivo.")
                    } else if allowPending,
                              let historical=historicalDeclarations.last(where:{
                                  $0.visitID==aid && $0.itemID==itemID
                              }),
                              let lot=stock.first(where:{
                                  string($0["id"])==historical.lotID
                              }) {
                        let inventoryCodes=Set(mapped.filter{
                            $0["clinicalCode"] as? String==code
                        }.compactMap{$0["kardexCode"] as? String})
                            .union(operational.filter{$0.clinicalCode==code}.map(\.inventoryID))
                            .union(N2UserReviewedKardexLinks.candidates(for:code).map(\.kardexID))
                        if let openings=Self.provisionalHistoricalR(
                            historical,lotCode:string(lot["code"]),
                            lotUnit:string(lot["catalogUnit"]),
                            approvedCodes:inventoryCodes,
                            alreadyLinked:linesByItem[key] != nil) {
                            physical=Double(openings)
                            consumption[code,default:0]+=openings
                            consumptionBySite[sourceSite+"|"+code,default:0]+=openings
                            pendingNotes.append(
                                "\(aid) / \(code) / \(name): R histórico declarado=\(openings) sin salida física ni FEFO retroactivo."
                            )
                        } else {
                            // Retain an incomplete declaration for manual
                            // review, but never turn its unverified package
                            // quantity into a numeric Excel R.
                            pendingNotes.append(
                                "\(aid) / \(code) / \(name): R PENDIENTE; declaración histórica sin correspondencia acreditada al lote físico."
                            )
                        }
                        pendingLines+=1
                    } else if allowPending,let declared=integer(row["quantity"]),declared>0 {
                        let inventoryCodes=Set(mapped.filter{$0["clinicalCode"] as? String==code}.compactMap{$0["kardexCode"] as? String})
                            .union(operational.filter{$0.clinicalCode==code}.map(\.inventoryID))
                            .union(N2UserReviewedKardexLinks.candidates(for:code).map(\.kardexID))
                        // No fictitious R=n for user-reviewed boxes/bottles
                        // whose opening was not explicitly declared.
                        let confirmedPackaging = !Set(["E-86","E-94","E-95"])
                            .isDisjoint(with:inventoryCodes)
                        let hasUnresolvedHistoricalLot=historicalDeclarations.contains {
                            $0.visitID==aid && $0.itemID==itemID
                        }
                        let container=confirmedPackaging || hasUnresolvedHistoricalLot ||
                            N2ContainerAccounting.isContainer(unit:type) || stock.contains {
                            inventoryCodes.contains(string($0["code"])) &&
                                N2ContainerAccounting.isContainer(unit:string($0["catalogUnit"]))
                        }
                        if container {
                            // Keep the 30 clinical fields in a PROVISIONAL
                            // workbook, but leave R truly BLANK. It must
                            // never become 0 (reuse), 1 (new opening), or the
                            // quantity of individually used needles.
                            pendingLines+=1
                            pendingNotes.append(
                                "\(aid) / \(code) / \(name): R PENDIENTE. Cantidad clínica declarada=\(declared) \(type); apertura y lote físico sin acreditar. No se contabiliza en RESU."
                            )
                        } else {
                            // Individual, non-container items preserve the
                            // declared quantity, explicitly marked pending.
                            physical=declared
                            consumption[code,default:0]+=declared
                            consumptionBySite[sourceSite+"|"+code,default:0]+=declared
                            pendingLines+=1
                            pendingNotes.append(
                                "\(aid) / \(code) / \(name): R clínico declarado=\(declared) sin entrega física confirmada; PROVISIONAL."
                            )
                        }
                    } else if allowPending {
                        // Even a zero/unknown clinical quantity may be
                        // retained as an incomplete row, with no R.
                        pendingLines+=1
                        pendingNotes.append(
                            "\(aid) / \(code) / \(name): R PENDIENTE; cantidad clínica o entrega física sin acreditar."
                        )
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

        if N2SimpleInventory.isActive(snapshot) {
            let inventory=try N2SimpleInventory.read(snapshot)
            var summary=[String:[String:Any]](),openings=0,closings=0
            for item in catalogue {
                let code=string(item["code"])
                var row:[String:Any]=["code":code,"consumed":consumption[code] ?? 0,"receiptDetails":[Any]()]
                let events=inventory.movements.filter{$0.code==code && N2SimpleInventory.day($0.at)<=end}
                let opening=events.last{N2SimpleInventory.day($0.at)<start}
                let within=events.filter{N2SimpleInventory.day($0.at)>=start}
                let unresolved=inventory.incidents.contains{$0.code==code && $0.resolutionEventID==nil && N2SimpleInventory.day($0.clinicalAt)>=start && N2SimpleInventory.day($0.clinicalAt)<=end}
                let historic=inventory.historicalUses.contains{$0.code==code}
                if let last=events.last,["initial","count"].contains(last.kind),N2SimpleInventory.day(last.at)==end {
                    row["count"]=last.after;closings+=1
                }
                if let opening,!unresolved,!historic,within.allSatisfy({$0.kind != "initial" && $0.kind != "count"}) {
                    row["opening"]=opening.after;openings+=1
                    let receipts=within.filter{$0.kind=="receipt"}
                    // The official workbook has four receipt slots. Aggregate same-day verified entries without discarding amounts.
                    let grouped=Dictionary(grouping:receipts,by:{N2SimpleInventory.day($0.at)})
                    guard grouped.count<=4 else{throw Failure.invalidReconciliation}
                    row["receiptDetails"]=grouped.keys.sorted().map {day in ["quantity":grouped[day]!.reduce(0){$0+$1.delta},"date":day,"document":"KARDEX CONSOLIDADO"] as [String:Any]}
                    row["verifiedIncome"]=receipts.reduce(0){$0+$1.delta}
                    row["closing"]=events.last?.after;row["difference"]=0
                }
                summary[code]=row
            }
            let allSavedIDs=Set(visits.filter{string($0["status"])=="saved" && string($0["date"])>=start && string($0["date"])<=end}.map{string($0["id"])})
            let provisional=allowPending || pendingLines>0 || openings<432 || closings<432 || subdivision != "AMBAS" || selectedVisitIDs != allSavedIDs
            let manifest:[String:Any]=["schema":1,"catalog":catalogue,"byCode":summary,
                "reviewed":!provisional,"provisional":provisional,"start":start,"end":end,
                "subdivision":subdivision,"rows":output.count,"plan":["lines":output],"pendingNotes":pendingNotes]
            let built=try N1sFullExcelWriter.exportIndicator(base:template,manifest:JSONSerialization.data(withJSONObject:manifest))
            guard built.sheetCount==10,built.writtenRows==output.count else{throw Failure.invalidWorkbook}
            return Result(xlsx:built.xlsx,provisional:provisional,pendingLines:pendingLines,rows:output.count,
                visits:selected.count,missingOpening:432-openings,missingClosingCount:432-closings)
        }

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
        // A single physical inventory supplies both care sites. Preserve
        // legacy site-tagged reconciliation events for audit and old imports,
        // but do not require TWO artificial inventories/reviews for new books.
        let sites=subdivision=="AMBAS"
            ? ["LA VENTUROSA","PLVENTUROSA"] : [subdivision]
        let inScope=active.filter{sites.contains(string($0["subdivision"]))}
        let allPeriodIDs=Set(visits.filter {
            string($0["status"])=="saved" &&
            string($0["date"])>=start && string($0["date"])<=end
        }.compactMap{$0["id"] as? String})
        let isWholePeriod=selectedVisitIDs==allPeriodIDs
        let periodStart=try? N2KardexCutPreview.period(for:end).start
        let clock=DateFormatter()
        clock.dateFormat="yyyy-MM-dd"
        clock.timeZone=TimeZone(identifier:"America/Lima")
        let today=clock.string(from:Date())
        // An unfinished/future period cannot have a verified closing count.
        // All clinical lines must be considered so omitted historic openings
        // cannot be masked by a partial selection.
        let projectedCut:N2AutomaticCutAccounting.Result? =
            subdivision=="AMBAS" && isWholePeriod && periodStart==start &&
            end<=today
            ? try? N2AutomaticCutAccounting.calculate(
                snapshot:clinical,mappings:mappings,through:end)
            : nil
        let sharedCloseCandidate = !allowPending && projectedCut != nil &&
            Self.eligibleForSharedClose(
                subdivision:subdivision,start:start,end:end,today:today,
                selected:selectedVisitIDs,all:allPeriodIDs,
                hasUnresolvedHistory:projectedCut?.hasUnresolvedHistory ?? true)
        // Maintain compatibility with historical signed reconciliations,
        // but the new joint inventory never REQUIRES two site reviews.
        let legacyReviewed=sites.allSatisfy({location in
            inScope.contains(where:{string($0["kind"])=="review" &&
                string($0["subdivision"])==location &&
                string($0["date"])==start &&
                string($0["periodEnd"])==end})
        })
        guard allowPending || sharedCloseCandidate || legacyReviewed else {
            throw Failure.unreviewedPeriod
        }
        var clinicalToNursing=[String:Set<String>]()
        for entry in mapped {
            if let clinical=entry["clinicalCode"] as? String,
               let kardex=entry["kardexCode"] as? String {
                clinicalToNursing[clinical,default:[]].insert(kardex)
            }
        }
        for entry in N2UserReviewedKardexLinks.links {
            clinicalToNursing[entry.clinicalCode,default:[]].insert(entry.kardexID)
        }
        for entry in operational {
            clinicalToNursing[entry.clinicalCode]=[entry.inventoryID]
        }
        // Two clinical codes referring to one physical product must never
        // duplicate that product's opening/count in the official 432 rows.
        var linkMultiplicity=[String:Int]()
        for codes in clinicalToNursing.values {
            for kardex in codes {linkMultiplicity[kardex,default:0]+=1}
        }
        let projectedByKardex=Dictionary(uniqueKeysWithValues:
            (projectedCut?.rows ?? []).map{($0.code,$0)})
        var summary=[String:[String:Any]]()
        var openingCount=0,closingCount=0
        for item in catalogue {
            let code=string(item["code"]),used=consumption[code] ?? 0
            let receipts=inScope.filter{string($0["kind"])=="receipt" &&
                string($0["code"])==code &&
                string($0["date"])>=start && string($0["date"])<=end}
                .sorted{(string($0["date"]),numeric($0["at"]) ?? 0,string($0["id"])) <
                        (string($1["date"]),numeric($1["at"]) ?? 0,string($1["id"]))}
            // The original RESU template only has four receipt groups. Never
            // drop extra receipts from the consolidated book.
            guard receipts.count<=4 else{throw Failure.invalidReconciliation}
            let income=receipts.reduce(0){$0+(integer($1["quantity"]) ?? 0)}
            var row:[String:Any]=["code":code,"consumed":used,
                                  "receipts":income,"receiptDetails":receipts]
            var knownOpenings=0,knownClosings=0
            var combinedOpening=0,combinedClosing=0,combinedFinal=0
            if sharedCloseCandidate {
                // Reconstruct once from joint physical lot counts. Demand
                // unique mapping, exact R and full receipt/adjustment evidence.
                if let codes=clinicalToNursing[code],codes.count==1,
                   let physicalCode=codes.first,
                   linkMultiplicity[physicalCode]==1,
                   let projection=projectedByKardex[physicalCode],
                   projection.unknownContainerOpenings==0,
                   projection.reportedUse==Double(used),
                   projection.received==Double(income),
                   projection.adjusted==0,
                   let beginning=projection.opening,
                   let physicalCount=projection.currentCount,
                   beginning>=0,physicalCount>=0,
                   beginning.rounded()==beginning,
                   physicalCount.rounded()==physicalCount {
                    let expected=Int(beginning)+income-used
                    guard expected>=0,expected==Int(physicalCount) else {
                        throw Failure.invalidReconciliation
                    }
                    row["opening"]=Int(beginning)
                    row["closing"]=expected
                    row["count"]=Int(physicalCount)
                    row["difference"]=0
                    // Zero (or more) receipts are explicitly supported by
                    // the complete, uniquely matched, audited stock ledger.
                    // The OOXML writer may now render this verified income
                    // instead of leaving a known-zero cell blank.
                    row["verifiedIncome"]=income
                    openingCount+=1
                    closingCount+=1
                } else if used>0 {
                    throw Failure.invalidReconciliation
                }
            } else {
            for location in sites {
                let opening=inScope.filter{string($0["kind"])=="opening" &&
                    string($0["subdivision"])==location &&
                    string($0["code"])==code && string($0["date"])==start}
                let closing=inScope.filter{string($0["kind"])=="count" &&
                    string($0["subdivision"])==location &&
                    string($0["code"])==code && string($0["date"])==end}
                guard opening.count<=1,closing.count<=1 else{
                    throw Failure.invalidReconciliation
                }
                let receiptsForSite=receipts.filter{
                    string($0["subdivision"])==location
                }.reduce(0){$0+(integer($1["quantity"]) ?? 0)}
                let usedForSite=consumptionBySite[location+"|"+code] ?? 0
                if let opening=opening.first,
                   let original=integer(opening["quantity"]) {
                    let final=original+receiptsForSite-usedForSite
                    guard final>=0 || allowPending else {
                        throw Failure.invalidReconciliation
                    }
                    knownOpenings+=1
                    combinedOpening+=original
                    combinedFinal+=final
                } else if !allowPending && usedForSite>0 {
                    // A physically dispensed product without a verified
                    // site-specific opening balance cannot be certified.
                    throw Failure.invalidReconciliation
                }
                if let closing=closing.first,
                   let actual=integer(closing["quantity"]) {
                    knownClosings+=1
                    combinedClosing+=actual
                }
            }
            if knownOpenings==sites.count {
                openingCount+=1
                row["opening"]=combinedOpening
                if !allowPending {row["closing"]=combinedFinal}
            }
            if knownClosings==sites.count {
                closingCount+=1
                row["count"]=combinedClosing
            }
            if knownOpenings==sites.count && knownClosings==sites.count {
                row["difference"]=combinedFinal-combinedClosing
            }
            }
            // A computed stock balance can be shown in the explicitly
            // provisional indicator only if all visits are selected, the
            // identity is unique and its opening/count are reconstructible.
            // These estimates NEVER replace official reconciliation events.
            if allowPending && subdivision=="AMBAS",
               let codes=clinicalToNursing[code],codes.count==1,
               let kardex=codes.first,linkMultiplicity[kardex]==1,
               let estimate=projectedByKardex[kardex],
               estimate.unknownContainerOpenings==0,
               estimate.reportedUse==Double(used),
               estimate.received==Double(income),
               estimate.adjusted==0,
               let beginning=estimate.opening,
               let physicalCount=estimate.currentCount,
               beginning>=0,physicalCount>=0,
               beginning.rounded()==beginning,
               physicalCount.rounded()==physicalCount,
               row["opening"]==nil,row["count"]==nil {
                let projectedClosing=Int(beginning)+income-used
                // A projection must reconcile to the real count. If the
                // arithmetic does not agree, don't present a verified zero
                // income or a trusted closing balance in RESU.
                if projectedClosing>=0,
                   projectedClosing==Int(physicalCount) {
                    row["opening"]=Int(beginning)
                    row["count"]=Int(physicalCount)
                    row["closing"]=projectedClosing
                    row["difference"]=0
                    row["verifiedIncome"]=income
                }
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

