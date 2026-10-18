import Foundation
import CoreFoundation

/// Lossless, copy-on-write edit operations over the build222 snapshot schema.
/// All unknown extension fields and untouched collections are preserved.
public enum N2SnapshotEditError: Error, Equatable {
    case invalidSource, invalidWorker, duplicateWorker, missingWorker
    case invalidAllergy, invalidDraft, duplicateDraft, savedIsImmutable
    case invalidClock, validationFailed
}
public enum N2SnapshotEditor {
    private static let allowedWorkerFields:Set<String> = [
        "dni","name","area","labor","sex","age","birthDate","ubigeo","site","source"
    ]
    private static let allowedDraftFields:Set<String> = [
        "worker","date","time","category","system","segment","diagnosis",
        "items","permission","workStatus","permissionTime","blueBandage",
        "returned","photoSent","standaloneProcedures","responsible",
        "responsibleDni","photoReviewed","dispensingSite"
    ]
    private static func parse(_ data:Data) throws->[String:Any] {
        guard let root=try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              root["workers"] is [[String:Any]],
              root["attentions"] is [[String:Any]],
              root["allergies"] is [String:Any] else {
            throw N2SnapshotEditError.invalidSource
        }
        return root
    }
    private static func isDni(_ value:String)->Bool {
        value.count==8 && value.utf8.allSatisfy{(48...57).contains($0)}
    }
    private static func clock(_ at:Int64)throws {
        guard at>0,at<=9_007_199_254_740_991 else{
            throw N2SnapshotEditError.invalidClock
        }
    }
    private static func finish(_ root:[String:Any])throws->Data {
        guard JSONSerialization.isValidJSONObject(root),
              let raw=try? JSONSerialization.data(withJSONObject:root,options:[.sortedKeys]),
              (try? N1eLegacyClinicalAudit.inspect(raw)) != nil,
              (try? N1fLosslessFieldGate.inspect(raw)) != nil else {
            throw N2SnapshotEditError.validationFailed
        }
        return raw
    }
    public static func addWorker(snapshot:Data,worker:Data,at:Int64)throws->Data {
        try clock(at)
        var root=try parse(snapshot)
        guard var workers=root["workers"] as? [[String:Any]],
              let input=try? JSONSerialization.jsonObject(with:worker) as? [String:Any],
              let dni=input["dni"] as? String,isDni(dni),
              let name=input["name"] as? String,
              !name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
              input.keys.allSatisfy({allowedWorkerFields.contains($0)}),
              workers.count<30_000 else {
            throw N2SnapshotEditError.invalidWorker
        }
        guard !workers.contains(where:{$0["dni"] as? String==dni}) else{
            throw N2SnapshotEditError.duplicateWorker
        }
        for (key,value) in input where key != "dni" && key != "name" {
            guard value is String else{throw N2SnapshotEditError.invalidWorker}
        }
        if let birthday=input["birthDate"] as? String,!birthday.isEmpty {
            let f=DateFormatter()
            f.calendar=Calendar(identifier:.gregorian)
            f.timeZone=TimeZone(secondsFromGMT:0)!
            f.dateFormat="yyyy-MM-dd"
            f.isLenient=false
            guard let parsed=f.date(from:birthday),
                  f.string(from:parsed)==birthday,
                  N2WorkerAge.years(birthDate:birthday,
                      on:f.string(from:Date(timeIntervalSince1970:Double(at)/1000))) != nil else {
                throw N2SnapshotEditError.invalidWorker
            }
        }
        // Identity comes from the local operator, never an inferred import.
        var final=input
        final["source"]="manual"
        final["localCorrectionAt"]=at
        workers.append(final)
        root["workers"]=workers
        return try finish(root)
    }
    public static func reviewAllergies(snapshot:Data,dni:String,status:String,
                                       substances:String,at:Int64)throws->Data {
        try clock(at)
        var root=try parse(snapshot)
        guard isDni(dni),["unknown","none","known"].contains(status),
              substances.utf8.count<=1500,
              (status=="known" ? !substances.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
                               : substances.isEmpty),
              let workers=root["workers"] as? [[String:Any]],
              workers.contains(where:{$0["dni"] as? String==dni}),
              var allergies=root["allergies"] as? [String:Any] else{
            throw N2SnapshotEditError.invalidAllergy
        }
        // Retain any unknown extension attributes of the original allergy row.
        var record=allergies[dni] as? [String:Any] ?? [:]
        record["status"]=status
        record["substances"]=substances
        record["updatedAt"]=at
        allergies[dni]=record
        root["allergies"]=allergies
        return try finish(root)
    }
    /// Creates or patches a draft without altering saved visits or movement rows.
    /// patch is whitelisted to avoid silently rewriting future metadata fields.
    public static func upsertDraft(snapshot:Data,id:String,changes:Data,
                                   at:Int64)throws->Data {
        try clock(at)
        guard !id.isEmpty,id.utf8.count<=128,
              let patch=try? JSONSerialization.jsonObject(with:changes) as? [String:Any],
              !patch.isEmpty,patch.keys.allSatisfy({allowedDraftFields.contains($0)}) else{
            throw N2SnapshotEditError.invalidDraft
        }
        var root=try parse(snapshot)
        guard var visits=root["attentions"] as? [[String:Any]],
              visits.count<100_000 else{throw N2SnapshotEditError.invalidSource}
        let idx=visits.firstIndex{$0["id"] as? String == id}
        var row:[String:Any]
        if let idx {
            guard visits[idx]["status"] as? String=="draft" else {
                throw N2SnapshotEditError.savedIsImmutable
            }
            row=visits[idx]
        }else {
            row=["id":id,"status":"draft","worker":[String:Any](),
                 "items":[[String:Any]]()]
        }
        for (k,v) in patch {row[k]=v}
        row["updatedAt"]=at
        guard row["worker"] is [String:Any],
              let items=row["items"] as? [[String:Any]],
              items.count<=1000 else {
            throw N2SnapshotEditError.invalidDraft
        }
        if let idx {visits[idx]=row}else{visits.append(row)}
        root["attentions"]=visits
        return try finish(root)
    }
    public static func deleteDraft(snapshot:Data,id:String)throws->Data {
        var root=try parse(snapshot)
        guard var visits=root["attentions"] as? [[String:Any]],
              let idx=visits.firstIndex(where:{$0["id"] as? String==id}) else{
            throw N2SnapshotEditError.invalidDraft
        }
        guard visits[idx]["status"] as? String=="draft" else{
            throw N2SnapshotEditError.savedIsImmutable
        }
        visits.remove(at:idx)
        root["attentions"]=visits
        return try finish(root)
    }
}

