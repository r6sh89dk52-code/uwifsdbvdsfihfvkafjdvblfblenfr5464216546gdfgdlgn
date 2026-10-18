import Foundation

/// Read-only, full-snapshot native projection of build222. No clinical writes,
/// partial restore, clock-dependent calculations or phantom inventory numbers.
public struct N2WorkerIndexRow: Equatable, Sendable, Identifiable {
    public var id:String {dni}
    public let dni:String
    public let name:String
    public let area:String
    public let site:String
    public let labor:String
    public let rosterStatus:String
}
public struct N2VisitIndexRow: Equatable, Sendable, Identifiable {
    public let id:String
    public let workerDNI:String
    public let workerName:String
    public let date:String
    public let time:String
    public let diagnosis:String
    public let status:String
    public let frequency:String?
    public let clinicalLines:Int
    public let confirmedPhysicalLines:Int
    public let pendingPhysicalLines:Int
    public let consumptionR:[Double?]
    public var workerSite:String=""
}
public struct N2NativeReadModel: Sendable {
    public let roster:[N2WorkerIndexRow]
    public let searchableRoster:[N2WorkerIndexRow]
    public let visits:[N2VisitIndexRow]
    public let pendingClinicalLines:Int

    public func findWorkers(_ needle:String)->[N2WorkerIndexRow] {
        let q=needle.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !q.isEmpty else {return searchableRoster}
        return searchableRoster.filter{
            $0.dni.localizedStandardContains(q) ||
            $0.name.localizedStandardContains(q) ||
            $0.area.localizedStandardContains(q) ||
            $0.site.localizedStandardContains(q)
        }
    }
    public func workerHistory(_ dni:String)->[N2VisitIndexRow] {
        visits.filter{$0.workerDNI==dni}
    }
}
public enum N2NativeReadError:Error,Equatable {
    case invalidSnapshot, mismatchedClinicalRows
}
public enum N2NativeSnapshotReader {
    private static let labels=["PRIMERA","SEGUNDA","TERCERA","CUARTA","QUINTA"]
    private struct Item {
        let id:String
        let workerDNI:String
        let workerName:String
        let date:String
        let time:String
        let diagnosis:String
        let status:String
        let physical:[Double?]
        let site:String
    }
    public static func read(_ data:Data)throws->N2NativeReadModel {
        // Never mutate source visits. Apply the validated append-only clinical
        // correction ledger to the displayed history only.
        let clinical=try N2ClinicalCorrections.effectiveSnapshot(data)
        guard let parity=try? N1eLegacyClinicalAudit.inspect(clinical),
              (try? N1fLosslessFieldGate.inspect(clinical)) != nil,
              let root=try? JSONSerialization.jsonObject(with:clinical) as? [String:Any],
              let workers=root["workers"] as? [[String:Any]],
              let visits=root["attentions"] as? [[String:Any]] else {
            throw N2NativeReadError.invalidSnapshot
        }
        let roster=workers.compactMap{w -> N2WorkerIndexRow? in
            guard let dni=w["dni"] as? String,
                  let name=w["name"] as? String else{return nil}
            return N2WorkerIndexRow(dni:dni,name:name,
                area:w["area"] as? String ?? "",site:w["site"] as? String ?? "",
                labor:w["labor"] as? String ?? "",
                rosterStatus:w["rosterStatus"] as? String ?? "")
        }.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}
        guard roster.count==workers.count else{throw N2NativeReadError.invalidSnapshot}
        let official=roster.contains{$0.rosterStatus=="official"}
        let searchable=roster.filter{
            !official || $0.rosterStatus=="official" || $0.rosterStatus=="verified"
        }
        var pointer=0,lines:[Item]=[]
        for visit in visits {
            let status=visit["status"] as? String ?? ""
            let worker=visit["worker"] as? [String:Any] ?? [:]
            let items=visit["items"] as? [[String:Any]] ?? []
            var amounts:[Double?]=[]
            if status=="saved" {
                guard pointer+items.count<=parity.consumptionR.count else{
                    throw N2NativeReadError.mismatchedClinicalRows
                }
                amounts=Array(parity.consumptionR[pointer..<(pointer+items.count)])
                pointer+=items.count
            }
            lines.append(Item(id:visit["id"] as? String ?? "",
                              workerDNI:worker["dni"] as? String ?? "",
                              workerName:worker["name"] as? String ?? "",
                              date:visit["date"] as? String ?? "",
                              time:visit["time"] as? String ?? "",
                              diagnosis:visit["diagnosis"] as? String ?? "",
                              status:status,physical:amounts,
                              site:worker["site"] as? String ?? ""))
        }
        guard pointer==parity.consumptionR.count else{
            throw N2NativeReadError.mismatchedClinicalRows
        }
        // Mirrors TS ambulatoryRows.ts sorting: date + time + visit id.
        let ordered=lines.sorted{
            if $0.date != $1.date{return $0.date<$1.date}
            if $0.time != $1.time{return $0.time<$1.time}
            return $0.id<$1.id
        }
        var counts:[String:Int]=[:],indexed:[N2VisitIndexRow]=[]
        for row in ordered {
            var label:String?=nil
            if row.status=="saved" {
                let key=row.date+"\u{001F}"+row.workerDNI
                let number=(counts[key] ?? 0)+1
                counts[key]=number
                label=number<=5 ? labels[number-1] : "REVISAR"
            }
            var record=N2VisitIndexRow(
                id:row.id,workerDNI:row.workerDNI,workerName:row.workerName,
                date:row.date,time:row.time,diagnosis:row.diagnosis,
                status:row.status,frequency:label,
                clinicalLines:row.physical.count,
                confirmedPhysicalLines:row.physical.compactMap{$0}.count,
                pendingPhysicalLines:row.physical.filter{$0==nil}.count,
                consumptionR:row.physical)
            record.workerSite=row.site
            indexed.append(record)
        }
        let visible=indexed.reversed()
        return N2NativeReadModel(roster:roster,searchableRoster:searchable,
                                  visits:Array(visible),
                                  pendingClinicalLines:parity.pendingClinicalItems)
    }
}
