import Foundation

public struct N2SimpleCutPreview:Sendable,Equatable {
    public let period:N2KardexCutPreview.Period
    public let through:String
    public let counted:Double
    public let countedAt:Int64
    public let currentStock:Double
    public let verifiedOutflows:Double
    public let receipts:Double
    public let netAdjustments:Double
    public let estimatedOpening:Double?
    public let confirmedOpening:Double?
    public let requiresVerification:Bool
    public let extraordinaryOpening:Bool
    public let evidenceSHA256:String?
}
extension N2SimpleInventory {
    /// Clinical projection only; never changes the physical inventory ledger.
    static func historicalOpeningOverrides(_ snapshot:Data)throws->[String:Double] {
        let archived=Set(try read(snapshot).historicalUses.map{key($0.visitID,$0.itemID)})
        let projected=try N2ClinicalCorrections.effectiveSnapshot(snapshot)
        let projectedVisits=try clinicalRows(object(projected))
        var correctedR=[String:Double]()
        for visit in projectedVisits {
            guard let vid=visit["id"] as? String,let items=visit["items"] as? [[String:Any]]
            else{continue}
            for item in items {
                guard let iid=item["id"] as? String,
                      let value=item["correctedHistoricalR"] as? Int,
                      [0,1].contains(value),archived.contains(key(vid,iid)) else{continue}
                correctedR[key(vid,iid)]=Double(value)
            }
        }
        return correctedR
    }
    public static func cutPreview(snapshot:Data,code:String,through:String,
                                  catalog:N2NativeCatalogIndex,archive:N2VerifiedInventoryBackup?=nil)throws->N2SimpleCutPreview {
        guard validDay(through) else{throw N2SimpleInventoryError.invalidDate}
        let s=try read(snapshot),root=try object(snapshot),period=try N2KardexCutPreview.period(for:through)
        guard let p=s.products.first(where:{$0.code==code}) else{throw N2SimpleInventoryError.invalidProduct}
        if let archive {
            guard archive.sourceSHA256==s.regime.sourceSHA256 || s.clinicalImports.contains(where:{$0.sourceSHA256==archive.sourceSHA256}) else {throw N2SimpleInventoryError.sourceChanged}
        }
        let all=s.movements.filter{$0.code==code && day($0.at)<=through}
        guard let count=all.last(where:{["initial","count"].contains($0.kind)}) else {
            throw N2SimpleInventoryError.invalidEvent
        }
        let beforeCount=all.filter{day($0.at)>=period.start && $0.at<=count.at}
        var used=round(-beforeCount.filter{$0.kind=="outflow"}.reduce(0){$0+$1.delta})
        var received=round(beforeCount.filter{$0.kind=="receipt"}.reduce(0){$0+$1.delta})
        var adjusted=round(beforeCount.filter{$0.kind=="count"}.reduce(0){$0+$1.delta})
        let preceding=all.last(where:{day($0.at)<period.start})
        var incomplete=preceding==nil
        let visits=try clinicalRows(root)
        let visitsByID=Dictionary(uniqueKeysWithValues:visits.compactMap {v->(String,[String:Any])? in
            guard let id=v["id"] as? String else{return nil};return(id,v)
        })
        let correctedR=try historicalOpeningOverrides(snapshot)
        func effectiveR(_ h:N2SimpleHistoricalUse)->Double? {
            correctedR[key(h.visitID,h.itemID)] ?? h.verifiedR
        }
        let historical=s.historicalUses.filter {h in
            guard h.code==code,h.unit==p.unit,let v=visitsByID[h.visitID],let date=v["date"] as? String else{return false}
            return date>=period.start && date<=day(count.at)
        }
        let relevantIncidents=s.incidents.filter{$0.code==code && day($0.clinicalAt)>=period.start && $0.clinicalAt<=count.at}
        if relevantIncidents.contains(where:{$0.resolutionEventID==nil}) {incomplete=true}
        if preceding != nil && !historical.isEmpty {incomplete=true}
        for incident in relevantIncidents where incident.resolutionEventID != nil {
            if let event=s.movements.first(where:{$0.id==incident.resolutionEventID}),["initial","count"].contains(event.kind) {
                let debit:Double?
                if p.mode == .presentation {debit=incident.resolvedR.map(Double.init)}
                else {debit=incident.clinicalQuantity}
                if let debit {
                    used+=debit
                    // The physical count already contains this older consumption.
                    // Reclassify its known part only in this read-only preview;
                    // it must not be counted again as an unexplained adjustment.
                    if event.kind=="count",day(event.at)>=period.start,event.at<=count.at {adjusted+=debit}
                }else {incomplete=true}
            }
        }
        if preceding==nil,let archive {
            guard archive.sourceSHA256==s.regime.sourceSHA256 || s.clinicalImports.contains(where:{$0.sourceSHA256==archive.sourceSHA256}) else {
                throw N2SimpleInventoryError.sourceChanged
            }
            incomplete=historical.contains{effectiveR($0)==nil || $0.sourceSHA256 != archive.sourceSHA256} || relevantIncidents.contains{$0.resolutionEventID==nil}
            used+=historical.compactMap(effectiveR).reduce(0,+)
            let old=try object(archive.snapshot)
            if isActive(archive.snapshot) {
                let prior=try read(archive.snapshot)
                guard let physical=prior.products.first(where:{$0.code==code}),physical.unit==p.unit,physical.mode==p.mode else {
                    incomplete=true
                    return makeCut(period:period,through:through,count:count,current:all.last?.after ?? count.after,
                        used:used,receipts:received,adjusted:adjusted,confirmed:preceding?.after,
                        incomplete:true,extraordinary:s.openingIsExtraordinary,evidence:archive.archiveSHA256)
                }
                for m in prior.movements where m.code==code && day(m.at)>=period.start && m.at<=count.at {
                    if m.kind=="receipt" {received+=m.delta}
                    if m.kind=="count" {adjusted+=m.delta}
                }
                if day(prior.regime.activatedAt)>period.start {incomplete=true}
            }else {
                let links=catalog.approvals.filter{$0.clinicalCode==code}
                let nursing=Set(links.map(\.kardexID))
                let oldLots=old["stockLots"] as? [[String:Any]] ?? []
                let oldMoves=old["stockMovements"] as? [[String:Any]] ?? []
                if nursing.count != 1 {incomplete=true}
                for m in oldMoves {
                    guard let stockCode=m["code"] as? String,nursing.contains(stockCode),
                          let at=(m["at"] as? NSNumber)?.int64Value,
                          day(at)>=period.start,at<=count.at,
                          let kind=m["kind"] as? String else{continue}
                    let lot=oldLots.first{$0["id"] as? String==m["lotId"] as? String}
                    guard let before=m["before"] as? [String:Any],let after=m["after"] as? [String:Any],
                          lot?["catalogUnit"] as? String==p.unit else{incomplete=true;continue}
                    if kind=="extraordinary" {
                        if p.mode == .presentation {
                            if let sealed=(m["sealedAdded"] as? NSNumber)?.doubleValue,sealed.rounded()==sealed {received+=sealed}
                            else {incomplete=true}
                        }else if let delta=(m["physicalChange"] as? NSNumber)?.doubleValue {received+=delta}
                        else {incomplete=true}
                    }else if kind=="adjustment" {
                        if p.mode == .presentation,
                           let a=(before["sealedContainers"] as? NSNumber)?.doubleValue,
                           let b=(after["sealedContainers"] as? NSNumber)?.doubleValue {adjusted+=b-a}
                        else if p.mode == .units,let delta=(m["physicalChange"] as? NSNumber)?.doubleValue {adjusted+=delta}
                        else {incomplete=true}
                    }else if kind=="use",m["dispenseRef"]==nil {
                        // Do not fabricate a clinical R for an unlinked historical removal.
                        incomplete=true
                    }
                }
            }
        }
        return makeCut(period:period,through:through,count:count,current:all.last?.after ?? count.after,
            used:used,receipts:received,adjusted:adjusted,confirmed:preceding?.after,
            incomplete:incomplete,extraordinary:s.openingIsExtraordinary,evidence:archive?.archiveSHA256)
    }
    private static func makeCut(period:N2KardexCutPreview.Period,through:String,count:N2SimpleMovement,
        current:Double,used:Double,receipts:Double,adjusted:Double,confirmed:Double?,incomplete:Bool,
        extraordinary:Bool,evidence:String?)->N2SimpleCutPreview {
        let candidate=round(count.after+used-receipts-adjusted)
        let coherent=confirmed.map{abs($0-candidate)<0.0001} ?? true
        let complete = !incomplete && candidate>=0 && coherent
        return N2SimpleCutPreview(period:period,through:through,counted:count.after,countedAt:count.at,
            currentStock:current,verifiedOutflows:round(used),receipts:round(receipts),netAdjustments:round(adjusted),
            estimatedOpening:complete ? candidate:nil,confirmedOpening:complete ? confirmed:nil,
            requiresVerification:!complete || confirmed==nil,extraordinaryOpening:extraordinary && confirmed==nil,
            evidenceSHA256:evidence)
    }
}
