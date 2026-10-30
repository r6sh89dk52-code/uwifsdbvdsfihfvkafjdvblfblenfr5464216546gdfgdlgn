import Foundation

/// A single validated native clinical generation yields one unchanged nursing
/// workbook. No demo manifests or guessed stock values are permitted.
public enum N2VerifiedNursingWorkbook {
    public enum Failure:Error,Equatable {
        case noPhysicalHistory, incompleteOrUnreconciled
    }
    public struct Result:Sendable {
        public let xlsx:Data
        public let stockKnownRows:Int
        public let stockUnknownRows:Int
        public let day:String
    }
    public static func export(snapshot:Data,catalog:Data,template:Data,
                              date:String,shift:String,responsible:String,site:String="",mappings:Data?=nil)throws->Result {
        if N2SimpleInventory.isActive(snapshot) {
            return try simple(snapshot:snapshot,catalog:catalog,template:template,start:date,end:date,shift:shift,responsible:responsible,mappings:mappings)
        }
        let report=try N2NursingReportBuilder.daily(
            snapshot:snapshot,catalog:catalog,date:date,site:site)
        guard report.rows.count==98 else{throw Failure.incompleteOrUnreconciled}
        let known=report.rows.filter{$0.stockKnown}.count
        // Export each absent-lot stock cell as recorded 0, without creating a physical lot.
        // The stockKnown flag remains false for unverified physical counts.
        guard report.exportable else{throw Failure.incompleteOrUnreconciled}
        let manifest=try report.manifest(shift:shift,responsible:responsible)
        let book=try N1sNursingExcelWriter.export(base:template,manifest:manifest)
        guard book.sheetCount==1,book.writtenRows==98,book.xlsx.count>20_000,
              book.xlsx.starts(with:[0x50,0x4B,0x03,0x04]) else{
            throw Failure.incompleteOrUnreconciled
        }
        return Result(xlsx:book.xlsx,stockKnownRows:known,
                      stockUnknownRows:98-known,day:date)
    }
    /// Verified multi-day report, explicitly labeled CONSOLIDADO with start/end.
    public static func exportRange(snapshot:Data,catalog:Data,template:Data,
                                   start:String,end:String,responsible:String,
                                   site:String="",mappings:Data?=nil,
                                   reconstructFromCount:Bool=false)throws->Result {
        if N2SimpleInventory.isActive(snapshot) {
            return try simple(snapshot:snapshot,catalog:catalog,template:template,start:start,end:end,shift:"CONSOLIDADO",responsible:responsible,mappings:mappings)
        }
        // Retrospective count-based reconstruction is opt-in for the 9th-day
        // export only; arbitrary date ranges keep the original physical ledger.
        let report:N2NursingReport
        if reconstructFromCount {
            guard let mappings else{throw Failure.incompleteOrUnreconciled}
            report=try N2NursingReportBuilder.reconstructedCut(
                snapshot:snapshot,catalog:catalog,mappings:mappings,
                start:start,end:end,site:site)
        } else {
            report=try N2NursingReportBuilder.range(
                snapshot:snapshot,catalog:catalog,start:start,end:end,site:site)
        }
        guard report.rows.count==98,report.exportable else{
            throw Failure.incompleteOrUnreconciled
        }
        let known=report.rows.filter(\.stockKnown).count
        // Export each absent-lot stock cell as recorded 0, without creating a physical lot.
        // The stockKnown flag remains false for unverified physical counts.
        let manifest=try report.manifest(shift:"CONSOLIDADO",responsible:responsible)
        let book=try N1sNursingExcelWriter.export(base:template,manifest:manifest)
        guard book.sheetCount==1,book.writtenRows==98,book.xlsx.count>20_000,
              book.xlsx.starts(with:[0x50,0x4B,0x03,0x04]) else{
            throw Failure.incompleteOrUnreconciled
        }
        return Result(xlsx:book.xlsx,stockKnownRows:known,
                      stockUnknownRows:98-known,day:start)
    }
    private static func simple(snapshot:Data,catalog:Data,template:Data,start:String,end:String,shift:String,
                               responsible:String,mappings:Data?)throws->Result {
        guard N2SimpleInventory.validDay(start),N2SimpleInventory.validDay(end),start<=end,
              let official=try JSONSerialization.jsonObject(with:catalog) as? [[String:Any]],official.count==98 else {
            throw Failure.incompleteOrUnreconciled
        }
        let state=try N2SimpleInventory.read(snapshot)
        // A pre-count clinical record must not permanently invalidate every
        // later monthly opening. Scope historical evidence to this report.
        // Historical uses *inside* this period still require reconciliation;
        // no unverified opening is silently certified.
        let clinicalRows=try N2SimpleInventory.clinicalRows(N2SimpleInventory.object(snapshot))
        let visitDates=Dictionary(uniqueKeysWithValues:clinicalRows.compactMap { visit -> (String,String)? in
            guard let id=visit["id"] as? String,let day=visit["date"] as? String else{return nil}
            return (id,day)
        })
        let historicalOverrides=try N2SimpleInventory.historicalOpeningOverrides(snapshot)
        let approved=try mappings.map{try JSONSerialization.jsonObject(with:$0) as? [[String:Any]] ?? []} ?? []
        var links=[String:Set<String>]()
        for row in approved {
            if let id=row["kardexCode"] as? String,let code=row["clinicalCode"] as? String {links[id,default:[]].insert(code)}
        }
        for link in N2UserReviewedKardexLinks.links {links[link.kardexID,default:[]].insert(link.clinicalCode)}
        var rows=[[String:Any]](),known=0
        for (index,officialRow) in official.enumerated() {
            guard let id=officialRow["id"] as? String,id=="E-\(index+1)",let name=officialRow["name"] as? String,
                  officialRow["donated"] as? Bool==false else {throw Failure.incompleteOrUnreconciled}
            var row:[String:Any]=["code":id,"name":name,"donated":false,"stockKnown":false,
                "initial":"NO VERIFICADO","extraordinary":NSNull(),"total":NSNull(),"consumed":NSNull(),"final":NSNull(),"expiry":"","fs":NSNull()]
            let candidates=links[id] ?? []
            if candidates.count==1,let code=candidates.first,
               links.values.filter({$0.contains(code)}).count==1,
               let product=state.products.first(where:{$0.code==code}) {
                // Only an approved identical original unit may occupy this official row.
                let mappedUnits=Set(approved.filter{$0["kardexCode"] as? String==id && $0["clinicalCode"] as? String==code}.compactMap{$0["clinicalUnit"] as? String})
                let reviewed=N2UserReviewedKardexLinks.links.contains{$0.kardexID==id && $0.clinicalCode==code && $0.clinicalUnit==product.unit}
                let originalUnit:String? = ["E-86":"FCO","E-94":"CJA","E-95":"CJA"][id] ?? (officialRow["group"] as? String=="TABLETAS" ? "UND":mappedUnits.first)
                if originalUnit==product.unit && (mappedUnits==Set([product.unit]) || (mappedUnits.isEmpty && reviewed)) {
                    let events=state.movements.filter{$0.code==code && N2SimpleInventory.day($0.at)<=end}
                    let opening=events.last{N2SimpleInventory.day($0.at)<start}
                    let inRange=events.filter{N2SimpleInventory.day($0.at)>=start}
                    let unresolved=state.incidents.contains{$0.code==code && $0.resolutionEventID==nil && N2SimpleInventory.day($0.clinicalAt)>=start && N2SimpleInventory.day($0.clinicalAt)<=end}
                    if let final=events.last {row["final"]=final.after}
                    if let reference=state.metadataEvents.last(where:{$0.code==code && N2SimpleInventory.day($0.at)<=end}),reference.verified {row["expiry"]=reference.next}
                    let historical=state.historicalUses.filter { item in
                        guard item.code==code,item.unit==product.unit,
                              let day=visitDates[item.visitID] else{return false}
                        return day>=start && day<=end
                    }
                    // Known clinical consumption can be reported independently
                    // of an unknown opening. Corrections never certify a balance
                    // or debit the counted inventory for a second time.
                    let historicalR=historical.map {
                        historicalOverrides[N2SimpleInventory.key($0.visitID,$0.itemID)] ?? $0.verifiedR
                    }
                    if !historical.isEmpty,!unresolved,historicalR.allSatisfy({$0 != nil}) {
                        row["consumed"]=historicalR.compactMap{$0}.reduce(0,+)
                            - inRange.filter{$0.kind=="outflow"}.reduce(0){$0+$1.delta}
                    }
                    if let opening,!unresolved,inRange.allSatisfy({$0.kind != "initial"}),
                       historical.isEmpty {
                        let receipts=inRange.filter{$0.kind=="receipt"}.reduce(0){$0+$1.delta}
                        var uses = -inRange.filter{$0.kind=="outflow"}.reduce(0){$0+$1.delta}
                        for incident in state.incidents where incident.code==code && incident.resolutionEventID != nil && N2SimpleInventory.day(incident.clinicalAt)>=start && N2SimpleInventory.day(incident.clinicalAt)<=end {
                            if let event=state.movements.first(where:{$0.id==incident.resolutionEventID}),["initial","count"].contains(event.kind) {
                                uses += product.mode == .presentation ? Double(incident.resolvedR ?? 0):incident.clinicalQuantity
                            }
                        }
                        let book=opening.after+receipts-uses
                        if book>=0 {
                            row["stockKnown"]=true;row["initial"]=opening.after;row["extraordinary"]=receipts
                            row["total"]=opening.after+receipts;row["consumed"]=uses;row["final"]=book
                            if inRange.contains(where:{$0.kind=="count"}) {row["fs"]=(events.last?.after ?? book)-book}
                            known+=1
                        }
                    }
                }
            }
            rows.append(row)
        }
        let manifest:[String:Any]=["date":start,"periodEnd":start==end ? "":end,"shift":shift,
            "responsible":responsible+" · CONSOLIDADO · SALDOS NO VERIFICADOS EN BLANCO · VENCIMIENTO REFERENCIAL",
            "inventorySchemaVersion":2,"rows":rows]
        let book=try N1sNursingExcelWriter.export(base:template,manifest:JSONSerialization.data(withJSONObject:manifest))
        guard book.sheetCount==1,book.writtenRows==98 else{throw Failure.incompleteOrUnreconciled}
        return Result(xlsx:book.xlsx,stockKnownRows:known,stockUnknownRows:98-known,day:start)
    }

}

