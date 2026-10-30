import Foundation
import CoreFoundation
import Crypto

/// Append-only, encrypted-snapshot clinical rectification ledger.
/// The original saved visit, its identity, recorded administration and every
/// FEFO physical movement remain immutable. There is no second dispensing.
public enum N2CorrectionError:Error,Equatable {
    case invalidSnapshot,missingVisit,notSaved,invalidChanges,invalidReason
    case staleCorrection,duplicateCorrection,brokenHistory,unchanged
}
public struct N2CorrectionField:Sendable,Equatable {
    public let id:String
    public let code:String
    public let name:String
    public let quantity:Int
    public let originalQuantity:Int
    public let procedure:String
    /// Effective historical opening shown as one editable visit (0/1);
    /// an older physical ledger remains outside the current counted stock.
    public let historicalOpeningR:Int?
    public let historicalOpeningEditable:Bool
}
public struct N2CorrectionDetail:Sendable {
    public let id:String
    public let workerName:String
    public let date:String
    public let time:String
    public let category:String
    public let system:String
    public let segment:String
    public let diagnosis:String
    public let permission:String
    public let permissionTime:String
    public let responsible:String
    public let responsibleDni:String
    public let workStatus:String
    public let blueBandage:Bool
    public let returned:Bool
    public let photoSent:Bool
    public let procedures:[String]
    public let medications:[N2CorrectionField]
    public let previousCorrections:Int
    public let pendingMedicationDiscrepancy:Bool
    public let effectiveSHA256:String
}
public struct N2CorrectionHistoryEntry:Identifiable,Sendable {
    public let id:String
    public let recordedAt:Int64
    public let reason:String
    public let operatorName:String
    public let beforeDiagnosis:String
    public let afterDiagnosis:String
    public let medicationDiscrepancy:String
}
public struct N2PendingClinicalCorrection:Sendable {
    public let visitID:String
    public let changes:Data
    public let reason:String
    public let operatorName:String
    public let medicationDiscrepancy:String
    public let updatedAt:Int64
}
public enum N2ClinicalCorrections {
    private static let editableText:Set<String> = [
        "category","system","segment","diagnosis","permission",
        "permissionTime","responsible","responsibleDni","workStatus"
    ]
    private static let editableBools:Set<String> = [
        "blueBandage","returned","photoSent"
    ]
    private static func json(_ data:Data)throws->[String:Any] {
        guard let obj=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              obj["attentions"] is [[String:Any]],obj["stockMovements"] is [[String:Any]],
              (try? N2VersionedSnapshotAudit.inspect(data,allowEmptySynthetic:true)) != nil,
              (try? N1fLosslessFieldGate.inspect(data)) != nil else {
            throw N2CorrectionError.invalidSnapshot
        }
        return obj
    }
    private static func canonical(_ row:[String:Any])throws->Data {
        try JSONSerialization.data(withJSONObject:row,options:[.sortedKeys])
    }
    private static func digest(_ row:[String:Any])throws->String {
        SHA256.hash(data:try canonical(row)).map{String(format:"%02x",$0)}.joined()
    }
    private static func nonempty(_ x:Any?)->String? {
        guard let s=x as? String,!s.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return nil}
        return s
    }
    private static func corrected(_ before:[String:Any],changes:[String:Any],
                                  allowUnchanged:Bool=false)throws->[String:Any] {
        var next=before
        guard changes.count<=20,
              changes.keys.allSatisfy({
                editableText.contains($0) || editableBools.contains($0) ||
                $0=="standaloneProcedures" || $0=="itemProcedures" ||
                $0=="itemClinicalQuantities" ||
                $0=="itemHistoricalOpenings"
              }) else{throw N2CorrectionError.invalidChanges}
        for (key,v) in changes {
            if editableText.contains(key) {
                guard let s=v as? String,s.utf8.count<=2048,
                      !s.contains("\0") else{throw N2CorrectionError.invalidChanges}
                next[key]=s
            }else if editableBools.contains(key) {
                guard let n=v as? NSNumber, CFGetTypeID(n)==CFBooleanGetTypeID() else{
                    throw N2CorrectionError.invalidChanges
                }
                next[key]=n.boolValue
            }else if key=="standaloneProcedures" {
                guard let arr=v as? [String],arr.count<=30,
                      arr.allSatisfy({!$0.isEmpty && $0.utf8.count<=180}) else{
                    throw N2CorrectionError.invalidChanges
                }
                next[key]=arr
            }else if key=="itemProcedures" {
                guard let index=v as? [String:String],index.count<=100,
                      let items=next["items"] as? [[String:Any]] else{
                    throw N2CorrectionError.invalidChanges
                }
                let originalIDs=Set(items.compactMap{$0["id"] as? String})
                guard Set(index.keys).isSubset(of:originalIDs),
                      index.values.allSatisfy({!$0.isEmpty && $0.utf8.count<=180}) else{
                    throw N2CorrectionError.invalidChanges
                }
                next["items"]=items.map{row in
                    var item=row
                    if let id=row["id"] as? String,let p=index[id]{
                        item["procedure"]=p
                    }
                    return item
                }
            }else if key=="itemHistoricalOpenings" {
                guard let entries=v as? [String:Int],!entries.isEmpty,entries.count<=100,
                      let items=next["items"] as? [[String:Any]],
                      entries.values.allSatisfy({[0,1].contains($0)}) else {
                    throw N2CorrectionError.invalidChanges
                }
                let allowed=Set(items.compactMap { item -> String? in
                    guard let id=item["id"] as? String,
                          let unit=item["unit"] as? String,
                          N2SimpleInventory.suggestedMode(unit:unit) == .presentation
                    else{return nil}
                    return id
                })
                guard Set(entries.keys).isSubset(of:allowed) else {
                    throw N2CorrectionError.invalidChanges
                }
                next["items"]=items.map { original in
                    var row=original
                    if let id=original["id"] as? String,let opening=entries[id] {
                        row["correctedHistoricalR"]=opening
                    }
                    return row
                }
            }else if key=="itemClinicalQuantities" {
                guard let quantities=v as? [String:Int],
                      !quantities.isEmpty,quantities.count<=100,
                      let items=next["items"] as? [[String:Any]] else{
                    throw N2CorrectionError.invalidChanges
                }
                let validIDs=Set(items.compactMap{$0["id"] as? String})
                guard Set(quantities.keys).isSubset(of:validIDs),
                      quantities.values.allSatisfy({(1...100_000).contains($0)}) else{
                    throw N2CorrectionError.invalidChanges
                }
                // Preserve ORIGINAL quantity and FEFO dispenseRef. A
                // corrected clinical amount is audit-only and blocks official
                // exports until its stock discrepancy is separately resolved.
                next["items"]=items.map{original in
                    var row=original
                    if let id=original["id"] as? String,let qty=quantities[id] {
                        row["correctedClinicalQuantity"]=qty
                    }
                    return row
                }
            }
        }
        // A clinical correction must never recalculate stock, change the
        // worker, shift the original visit between dates or change FEFO refs.
        let changed=(try canonical(before)) != (try canonical(next))
        guard nonempty(next["diagnosis"]) != nil,
              nonempty(next["category"]) != nil,
              nonempty(next["system"]) != nil,
              ["NO","SI"].contains(next["permission"] as? String ?? ""),
              (next["permission"] as? String != "SI" ||
               (next["permissionTime"] as? String ?? "").range(
                of:#"^([01]\d|2[0-3]):[0-5]\d$"#,options:.regularExpression) != nil),
              nonempty(next["responsible"]) != nil,
              (allowUnchanged || changed) else{
            throw N2CorrectionError.unchanged
        }
        return next
    }
    private static func project(_ original:[String:Any])throws->
        (rows:[[String:Any]],history:[[String:Any]],pending:Set<String>) {
        guard let visits=original["attentions"] as? [[String:Any]] else{
            throw N2CorrectionError.brokenHistory
        }
        if original["clinicalCorrectionLog"] != nil &&
           !(original["clinicalCorrectionLog"] is [[String:Any]]) {
            throw N2CorrectionError.brokenHistory
        }
        let history=original["clinicalCorrectionLog"] as? [[String:Any]] ?? []
        var byID=[String:Int]()
        for (i,v) in visits.enumerated() {
            guard let id=v["id"] as? String,byID[id]==nil else{
                throw N2CorrectionError.brokenHistory
            }
            byID[id]=i
        }
        var current=visits,events=Set<String>(),
            pending=Set<String>(),previousEventSHA=""

        for event in history {
            guard let id=nonempty(event["id"]),UUID(uuidString:id) != nil,
                  events.insert(id).inserted,
                  let visitID=nonempty(event["visitID"]),let idx=byID[visitID],
                  current[idx]["status"] as? String=="saved",
                  let reason=nonempty(event["reason"]),reason.utf8.count<=1500,
                  let op=nonempty(event["operator"]),op.utf8.count<=120,
                  let millis=event["recordedAt"] as? NSNumber,
                  millis.int64Value>0,
                  let oldSHA=event["beforeSHA256"] as? String,
                  let newSHA=event["afterSHA256"] as? String,
                  let change=event["changes"] as? [String:Any],
                  let prior=event["previousEventSHA256"] as? String,
                  prior==previousEventSHA,
                  let signed=event["eventSHA256"] as? String,
                  let note=event["medicationDiscrepancy"] as? String,
                  note.utf8.count<=1500,
                  oldSHA==(try? digest(current[idx])),
                  let next=try? corrected(current[idx],changes:change,
                                          allowUnchanged:!note.isEmpty),
                  newSHA==(try? digest(next)) else{
                throw N2CorrectionError.brokenHistory
            }
            var receipt=event
            receipt.removeValue(forKey:"eventSHA256")
            guard signed==(try? digest(receipt)) else{
                throw N2CorrectionError.brokenHistory
            }
            previousEventSHA=signed
            if !note.isEmpty || change["itemClinicalQuantities"] != nil {
                pending.insert(visitID)
            }
            current[idx]=next
        }
        return(current,history,pending)
    }
    public static func detail(snapshot:Data,visitID:String)throws->N2CorrectionDetail {
        let obj=try json(snapshot)
        let evaluated=try project(obj)
        guard let visit=evaluated.rows.first(where:{$0["id"] as? String==visitID})
        else{throw N2CorrectionError.missingVisit}
        guard visit["status"] as? String=="saved" else{throw N2CorrectionError.notSaved}
        guard let worker=visit["worker"] as? [String:Any],
              let items=visit["items"] as? [[String:Any]] else{
            throw N2CorrectionError.invalidSnapshot
        }
        let priorHistorical=N2SimpleInventory.isActive(snapshot)
            ? (try N2SimpleInventory.read(snapshot).historicalUses)
            : []
        let lines=try items.map{v -> N2CorrectionField in
            guard let id=v["id"] as? String,let code=v["code"] as? String,
                  let name=v["name"] as? String,let quantity=v["quantity"] as? Int else{
                throw N2CorrectionError.invalidSnapshot
            }
            let corrected=v["correctedClinicalQuantity"] as? Int ?? quantity
            let h=priorHistorical.first{$0.visitID==visitID && $0.itemID==id}
            let eligible=h != nil &&
                N2SimpleInventory.suggestedMode(unit:v["unit"] as? String ?? "") == .presentation
            let recordedR=h?.verifiedR.flatMap{($0==0 || $0==1) ? Int($0):nil}
            let effectiveR=(v["correctedHistoricalR"] as? Int) ?? recordedR
            return N2CorrectionField(id:id,code:code,name:name,
                quantity:corrected,originalQuantity:quantity,
                procedure:v["procedure"] as? String ?? "",
                historicalOpeningR:eligible ? effectiveR:nil,
                historicalOpeningEditable:eligible)
        }
        func s(_ key:String)->String{visit[key] as? String ?? ""}
        return N2CorrectionDetail(id:visitID,workerName:worker["name"] as? String ?? "",
            date:s("date"),time:s("time"),category:s("category"),system:s("system"),
            segment:s("segment"),diagnosis:s("diagnosis"),permission:s("permission"),
            permissionTime:s("permissionTime"),responsible:s("responsible"),
            responsibleDni:s("responsibleDni"),workStatus:s("workStatus"),
            blueBandage:visit["blueBandage"] as? Bool ?? false,
            returned:visit["returned"] as? Bool ?? false,
            photoSent:visit["photoSent"] as? Bool ?? false,
            procedures:visit["standaloneProcedures"] as? [String] ?? [],
            medications:lines,
            previousCorrections:evaluated.history.filter{
                $0["visitID"] as? String==visitID
            }.count,
            pendingMedicationDiscrepancy:evaluated.pending.contains(visitID),
            effectiveSHA256:try digest(visit))
    }
    public static func history(snapshot:Data,visitID:String)throws
        ->[N2CorrectionHistoryEntry] {
        let source=try json(snapshot)
        let inspected=try project(source)
        guard let originals=source["attentions"] as? [[String:Any]],
              let original=originals.first(where:{$0["id"] as? String==visitID}),
              original["status"] as? String=="saved" else{
            throw N2CorrectionError.missingVisit
        }
        var current=original,history=[N2CorrectionHistoryEntry]()
        for event in inspected.history where event["visitID"] as? String==visitID {
            guard let changes=event["changes"] as? [String:Any],
                  let note=event["medicationDiscrepancy"] as? String else{
                throw N2CorrectionError.brokenHistory
            }
            let next=try corrected(current,changes:changes,
                                   allowUnchanged:!note.isEmpty)
            history.append(N2CorrectionHistoryEntry(
                id:event["id"] as? String ?? "",
                recordedAt:(event["recordedAt"] as? NSNumber)?.int64Value ?? 0,
                reason:event["reason"] as? String ?? "",
                operatorName:event["operator"] as? String ?? "",
                beforeDiagnosis:current["diagnosis"] as? String ?? "",
                afterDiagnosis:next["diagnosis"] as? String ?? "",
                medicationDiscrepancy:note))
            current=next
        }
        return history.reversed()
    }
    /// For history/export projections only; the encrypted saved source stays
    /// immutable and its original physical R links are authoritative.
    public static func effectiveSnapshot(_ snapshot:Data)throws->Data {
        let obj=try json(snapshot)
        let projected=try project(obj)
        var next=obj
        next["attentions"]=projected.rows
        return try JSONSerialization.data(withJSONObject:next,options:[.sortedKeys])
    }
    public static func pendingDiscrepancies(_ snapshot:Data)throws->Set<String> {
        try project(json(snapshot)).pending
    }
    /// A correction draft is stored only within the encrypted N2 journal.
    /// It never creates a second clinical attendance or physical movement.
    public static func pendingDraft(snapshot:Data,visitID:String)throws
        ->N2PendingClinicalCorrection? {
        let root=try json(snapshot)
        let current=try project(root)
        guard let original=current.rows.first(where:{$0["id"] as? String==visitID}),
              original["status"] as? String=="saved" else{
            throw N2CorrectionError.missingVisit
        }
        guard root["clinicalCorrectionDrafts"] == nil ||
              root["clinicalCorrectionDrafts"] is [[String:Any]] else{
            throw N2CorrectionError.brokenHistory
        }
        let all=root["clinicalCorrectionDrafts"] as? [[String:Any]] ?? []
        guard all.count<=100,all.filter({$0["visitID"] as? String==visitID}).count<=1 else{
            throw N2CorrectionError.brokenHistory
        }
        guard let found=all.first(where:{$0["visitID"] as? String==visitID})
        else{return nil}
        guard let patch=found["changes"] as? [String:Any],
              let expected=found["expectedEffectiveSHA"] as? String,
              expected==(try digest(original)),
              let reason=found["reason"] as? String,reason.utf8.count<=1500,
              let user=found["operator"] as? String,user.utf8.count<=120,
              let note=found["medicationDiscrepancy"] as? String,
              note.utf8.count<=1500,
              let millis=found["updatedAt"] as? NSNumber,millis.int64Value>0,
              (try? corrected(original,changes:patch,allowUnchanged:true)) != nil else {
            throw N2CorrectionError.brokenHistory
        }
        return N2PendingClinicalCorrection(
            visitID:visitID,
            changes:try JSONSerialization.data(withJSONObject:patch),
            reason:reason,operatorName:user,medicationDiscrepancy:note,
            updatedAt:millis.int64Value)
    }
    public static func savePendingDraft(snapshot:Data,visitID:String,changes:Data,
        reason:String,operatorName:String,medicationDiscrepancy:String,
        expectedEffectiveSHA:String,at:Int64)throws->Data {
        guard at>0,reason.utf8.count<=1500,operatorName.utf8.count<=120,
              medicationDiscrepancy.utf8.count<=1500,
              let change=try? JSONSerialization.jsonObject(with:changes)
                 as? [String:Any] else{throw N2CorrectionError.invalidChanges}
        var source=try json(snapshot)
        let current=try project(source)
        guard let saved=current.rows.first(where:{$0["id"] as? String==visitID}),
              saved["status"] as? String=="saved" else{
            throw N2CorrectionError.notSaved
        }
        guard try digest(saved)==expectedEffectiveSHA else{
            throw N2CorrectionError.staleCorrection
        }
        _=try corrected(saved,changes:change,allowUnchanged:true)
        guard source["clinicalCorrectionDrafts"] == nil ||
              source["clinicalCorrectionDrafts"] is [[String:Any]] else{
            throw N2CorrectionError.brokenHistory
        }
        var drafts=source["clinicalCorrectionDrafts"] as? [[String:Any]] ?? []
        guard drafts.count<100 else{throw N2CorrectionError.brokenHistory}
        let row:[String:Any]=[
            "visitID":visitID,"changes":change,
            "reason":reason,"operator":operatorName,
            "medicationDiscrepancy":medicationDiscrepancy,
            "expectedEffectiveSHA":expectedEffectiveSHA,"updatedAt":at
        ]
        if let index=drafts.firstIndex(where:{$0["visitID"] as? String==visitID}) {
            drafts[index]=row
        }else{drafts.append(row)}
        source["clinicalCorrectionDrafts"]=drafts
        let bytes=try JSONSerialization.data(withJSONObject:source,options:[.sortedKeys])
        _=try N2VersionedSnapshotAudit.inspect(bytes)
        _=try N1fLosslessFieldGate.inspect(bytes)
        return bytes
    }
    public static func deletePendingDraft(snapshot:Data,visitID:String)throws->Data {
        var source=try json(snapshot)
        let drafts=source["clinicalCorrectionDrafts"] as? [[String:Any]] ?? []
        guard drafts.contains(where:{$0["visitID"] as? String==visitID}) else{
            throw N2CorrectionError.missingVisit
        }
        source["clinicalCorrectionDrafts"]=drafts.filter{$0["visitID"] as? String != visitID}
        let bytes=try JSONSerialization.data(withJSONObject:source,options:[.sortedKeys])
        _=try N2VersionedSnapshotAudit.inspect(bytes)
        _=try N1fLosslessFieldGate.inspect(bytes)
        return bytes
    }
    public static func append(snapshot:Data,eventID:String,visitID:String,
                              changes:Data,reason:String,operatorName:String,
                              medicationDiscrepancy:String,
                              expectedEffectiveSHA:String,
                              at:Int64)throws->Data {
        guard UUID(uuidString:eventID) != nil,at>0,
              (8...1500).contains(reason.trimmingCharacters(
                in:.whitespacesAndNewlines).utf8.count),
              (3...120).contains(operatorName.trimmingCharacters(
                in:.whitespacesAndNewlines).utf8.count),
              medicationDiscrepancy.utf8.count<=1500 else{
            throw N2CorrectionError.invalidReason
        }
        var obj=try json(snapshot)
        let current=try project(obj)
        guard let index=current.rows.firstIndex(where:{$0["id"] as? String==visitID})
        else{throw N2CorrectionError.missingVisit}
        guard current.rows[index]["status"] as? String=="saved" else{
            throw N2CorrectionError.notSaved
        }
        guard let changes=try? JSONSerialization.jsonObject(with:changes) as? [String:Any]
        else{throw N2CorrectionError.invalidChanges}
        if let already=current.history.first(where:{$0["id"] as? String==eventID}) {
            // A retry after commit must be exactly the same clinical action:
            // same visit, source version, operator and clinical amendments.
            // It must not create another revision or a second FEFO movement.
            guard already["visitID"] as? String==visitID,
                  already["beforeSHA256"] as? String==expectedEffectiveSHA,
                  already["reason"] as? String ==
                    reason.trimmingCharacters(in:.whitespacesAndNewlines),
                  already["operator"] as? String ==
                    operatorName.trimmingCharacters(in:.whitespacesAndNewlines),
                  already["medicationDiscrepancy"] as? String==medicationDiscrepancy,
                  let previous=already["changes"] as? [String:Any],
                  (try? canonical(previous))==(try? canonical(changes)) else{
                throw N2CorrectionError.duplicateCorrection
            }
            return snapshot
        }
        // Only a genuine archived pre-count presentation may receive an
        // opening correction. A live V2 dispense is never rewritten here.
        if let openings=changes["itemHistoricalOpenings"] as? [String:Int] {
            guard N2SimpleInventory.isActive(snapshot) else{
                throw N2CorrectionError.invalidChanges
            }
            let archived=try N2SimpleInventory.read(snapshot).historicalUses
            let eligible=Set(archived.filter{$0.visitID==visitID}.map(\.itemID))
            guard !openings.isEmpty,Set(openings.keys).isSubset(of:eligible) else{
                throw N2CorrectionError.invalidChanges
            }
        }
        let before=current.rows[index]
        guard try digest(before)==expectedEffectiveSHA else{
            throw N2CorrectionError.staleCorrection
        }
        let after=try corrected(before,changes:changes,
                                  allowUnchanged:!medicationDiscrepancy.isEmpty)
        let previousEventSHA=current.history.last?["eventSHA256"] as? String ?? ""
        var record:[String:Any]=[
            "id":eventID,"visitID":visitID,"recordedAt":at,
            "reason":reason.trimmingCharacters(in:.whitespacesAndNewlines),
            "operator":operatorName.trimmingCharacters(in:.whitespacesAndNewlines),
            "medicationDiscrepancy":medicationDiscrepancy,
            "beforeSHA256":try digest(before),"afterSHA256":try digest(after),
            "changes":changes,"previousEventSHA256":previousEventSHA
        ]
        record["eventSHA256"]=try digest(record)
        var history=current.history
        guard history.count<10000 else{throw N2CorrectionError.brokenHistory}
        history.append(record)
        obj["clinicalCorrectionLog"]=history
        // The committed amendment atomically retires only its own
        // unfinished draft. Other saved attentions and drafts remain intact.
        if let pending=obj["clinicalCorrectionDrafts"] as? [[String:Any]] {
            obj["clinicalCorrectionDrafts"]=pending.filter{
                $0["visitID"] as? String != visitID
            }
        }
        let result=try JSONSerialization.data(withJSONObject:obj,options:[.sortedKeys])
        _=try N2VersionedSnapshotAudit.inspect(result)
        _=try N1fLosslessFieldGate.inspect(result)
        // Audit the entire chain including this newly appended revision.
        _=try project(obj)
        return result
    }
}
