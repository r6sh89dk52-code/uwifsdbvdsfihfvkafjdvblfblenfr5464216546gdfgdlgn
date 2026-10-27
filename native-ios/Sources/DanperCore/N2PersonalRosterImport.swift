import Foundation

public struct N2PersonalImportResult:Equatable,Sendable {
    public let before:Int
    public let after:Int
    public let added:Int
    public let unchanged:Int
    public let updated:Int
    public let preservedManualCorrections:Int
}

public enum N2PersonalRosterImport {
    private static func validate(_ preview:N2PersonalImportPreview,_ site:String)throws {
        guard ["LA VENTUROSA","PLVENTUROSA","DESDE_EXCEL"].contains(site),
              preview.stats.canConfirm,
              preview.workers.count==preview.stats.valid,
              preview.workers.count<=30_000 else {
            throw N2PersonalImportError.needsReview
        }
        let ids=preview.workers.map(\.dni)
        guard Set(ids).count==ids.count,
              preview.workers.allSatisfy({
                  $0.dni.utf8.count==8 &&
                  $0.dni.utf8.allSatisfy({(48...57).contains($0)}) &&
                  !$0.name.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty
              }),
              preview.workers.allSatisfy({ row in
                  if site=="DESDE_EXCEL" {
                      return preview.stats.sourceSiteColumn &&
                          ["LA VENTUROSA","PLVENTUROSA"].contains(row.site)
                  }
                  return row.site.isEmpty || row.site==site
              }) else{throw N2PersonalImportError.needsReview}
    }
    private static func normalized(_ value:String)->String {
        value.folding(options:[.diacriticInsensitive,.caseInsensitive],
                      locale:Locale(identifier:"es_PE"))
            .trimmingCharacters(in:.whitespacesAndNewlines)
            .split(whereSeparator:{$0.isWhitespace})
            .joined(separator:" ").uppercased()
    }
    private static func worker(_ row:N2PersonalWorker,site:String)->[String:Any] {
        // Preserve each verified source site when a mixed PERSONAL workbook
        // explicitly identifies workers from both locations.
        let confirmedSite=site=="DESDE_EXCEL" ? row.site : site
        return [
            "dni":row.dni,"name":row.name,"area":row.area,
            "labor":row.labor,"sex":row.sex,"age":row.age,
            "ubigeo":row.ubigeo,"site":confirmedSite,
            "birthDate":"","source":"imported","rosterStatus":"official"
        ]
    }
    /// Only employee rows are inserted. It contains no demo histories, lots,
    /// consumption, patient allergies or clinical records.
    public static func initialSnapshot(preview:N2PersonalImportPreview,
                                       site:String)throws->Data {
        try validate(preview,site)
        let root:[String:Any]=[
            "workers":preview.workers.map{worker($0,site:site)},
            "attentions":[[String:Any]](),
            "allergies":[String:Any](),
            "stockLots":[[String:Any]](),
            "stockMovements":[[String:Any]](),
            "catalogMappings":[[String:Any]](),
            "deliveryIncidents":[[String:Any]](),
            "ambulatoryReconciliation":[[String:Any]](),
            "notifications":false
        ]
        let data=try JSONSerialization.data(withJSONObject:root,
                                            options:[.sortedKeys])
        _=try N2VersionedSnapshotAudit.inspect(data)
        _=try N1fLosslessFieldGate.inspect(data)
        return data
    }
    /// One lossless, idempotent roster transaction. Historical visits,
    /// allergies and physical movements are carried byte-for-byte as
    /// JSON subtrees and never reconstructed from the Excel.
    public static func merge(snapshot:Data,preview:N2PersonalImportPreview,
                             site:String)throws->(Data,N2PersonalImportResult) {
        try validate(preview,site)
        _=try N2VersionedSnapshotAudit.inspect(snapshot)
        _=try N1fLosslessFieldGate.inspect(snapshot)
        guard var root=try JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              var people=root["workers"] as? [[String:Any]] else {
            throw N2PersonalImportError.invalidFile
        }
        var indices=[String:Int]()
        for (i,row) in people.enumerated() {
            guard let dni=row["dni"] as? String,
                  indices.updateValue(i,forKey:dni)==nil else {
                throw N2PersonalImportError.needsReview
            }
        }
        let before=people.count
        var added=0,unchanged=0,updated=0,preserved=0
        for source in preview.workers {
            let incoming=worker(source,site:site)
            guard let i=indices[source.dni] else {
                guard people.count<30_000 else{throw N2PersonalImportError.tooLarge}
                indices[source.dni]=people.count
                people.append(incoming)
                added+=1
                continue
            }
            let previous=people[i]
            let existingName=previous["name"] as? String ?? ""
            let existingSex=previous["sex"] as? String ?? ""
            let existingSite=previous["site"] as? String ?? ""
            guard normalized(existingName)==normalized(source.name),
                  existingSex.isEmpty || source.sex.isEmpty ||
                    existingSex==source.sex,
                  existingSite.isEmpty ||
                    existingSite==(incoming["site"] as? String ?? "") else {
                // Never silently overwrite identity from a second roster.
                throw N2PersonalImportError.needsReview
            }
            var result=previous
            let manuallyCorrected=((previous["localCorrectionAt"] as? NSNumber)?
                .int64Value ?? 0)>0
            if manuallyCorrected{preserved+=1}
            result["rosterStatus"]="official"
            result["source"]=manuallyCorrected ? "manual" : "imported"
            for field in ["area","labor","age","ubigeo","site"] {
                let old=previous[field] as? String ?? ""
                let candidate=incoming[field] as? String ?? ""
                result[field]=manuallyCorrected && !old.isEmpty ?
                    old : (candidate.isEmpty ? old : candidate)
            }
            if existingSex.isEmpty{result["sex"]=source.sex}
            let previousBytes=try JSONSerialization.data(
                withJSONObject:previous,options:[.sortedKeys])
            let currentBytes=try JSONSerialization.data(
                withJSONObject:result,options:[.sortedKeys])
            if currentBytes != previousBytes {
                people[i]=result
                updated+=1
            } else {unchanged+=1}
        }
        guard added>0 || updated>0 else {
            return (snapshot,N2PersonalImportResult(
                before:before,after:before,added:0,unchanged:unchanged,
                updated:0,preservedManualCorrections:preserved))
        }
        root["workers"]=people
        let next=try JSONSerialization.data(withJSONObject:root,
                                            options:[.sortedKeys])
        _=try N2VersionedSnapshotAudit.inspect(next)
        _=try N1fLosslessFieldGate.inspect(next)
        return (next,N2PersonalImportResult(
            before:before,after:people.count,added:added,
            unchanged:unchanged,updated:updated,
            preservedManualCorrections:preserved))
    }
}
