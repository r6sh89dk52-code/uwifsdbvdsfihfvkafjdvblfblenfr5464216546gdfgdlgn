import Foundation

public struct N2SimpleActivation:Codable,Sendable {
    public let id:String
    public let at:Int64
    public let operatorName:String
    public let confirmed:Bool
    public let backupAvailable:Bool
    public let initialProducts:[N2SimpleProduct]
    public let extraordinaryOpening:Bool
    public init(id:String=UUID().uuidString,at:Int64,operatorName:String,confirmed:Bool,
                backupAvailable:Bool,initialProducts:[N2SimpleProduct],extraordinaryOpening:Bool=true) {
        self.id=id;self.at=at;self.operatorName=operatorName;self.confirmed=confirmed
        self.backupAvailable=backupAvailable;self.initialProducts=initialProducts
        self.extraordinaryOpening=extraordinaryOpening
    }
}
extension N2SimpleInventory {
    static func historicalUses(_ raw:Data,report:N1eClinicalParityReport)throws->[N2SimpleHistoricalUse] {
        let root=try object(raw),fingerprint=try self.fingerprint(raw)
        var evidence=[N2SimpleHistoricalUse](),offset=0
        for visit in try clinicalRows(root) where visit["status"] as? String=="saved" {
            guard let vid=visit["id"] as? String,let items=visit["items"] as? [[String:Any]] else {
                throw N2SimpleInventoryError.invalidClinicalLink
            }
            for i in items {
                guard offset<report.consumptionR.count,let iid=i["id"] as? String,
                      let code=i["code"] as? String,let unit=i["unit"] as? String,
                      let quantity=i["quantity"] as? NSNumber else{throw N2SimpleInventoryError.invalidClinicalLink}
                evidence.append(N2SimpleHistoricalUse(visitID:vid,itemID:iid,code:code,unit:unit,
                    quantity:quantity.doubleValue,verifiedR:report.consumptionR[offset],sourceSHA256:fingerprint))
                offset+=1
            }
        }
        guard offset==report.consumptionR.count else{throw N2SimpleInventoryError.invalidClinicalLink}
        return evidence
    }
    public static func activate(snapshot:Data,backup:N2VerifiedInventoryBackup,
                                request:N2SimpleActivation,catalog:N2NativeCatalogIndex)throws->Data {
        guard request.confirmed else{throw N2SimpleInventoryError.confirmationRequired}
        guard request.backupAvailable else{throw N2SimpleInventoryError.missingBackup}
        if isActive(snapshot) {
            let s=try read(snapshot)
            guard s.regime.id==request.id else{throw N2SimpleInventoryError.alreadyActive}
            guard s.regime.sourceSHA256==backup.sourceSHA256,s.regime.backupSHA256==backup.archiveSHA256,
                  s.regime.activationSHA256 == (try fingerprint(JSONEncoder().encode(request))) else {
                throw N2SimpleInventoryError.sourceChanged
            }
            return snapshot
        }
        let report=try N2VersionedSnapshotAudit.inspect(snapshot,allowEmptySynthetic:true)
        guard try fingerprint(snapshot)==backup.sourceSHA256,backup.schemaVersion==1,
              UUID(uuidString:request.id) != nil,validTime(request.at),text(request.operatorName),
              !request.initialProducts.isEmpty,request.initialProducts.count<=1000,
              Set(request.initialProducts.map(\.code)).count==request.initialProducts.count else {
            throw N2SimpleInventoryError.sourceChanged
        }
        var root=try object(snapshot)
        let regime=N2SimpleRegime(id:request.id,activatedAt:request.at,timeZone:"America/Lima",schemaVersion:2,
            sourceSHA256:backup.sourceSHA256,activationSHA256:try fingerprint(JSONEncoder().encode(request)),backupSHA256:backup.archiveSHA256,operatorName:request.operatorName,
            confirmationID:UUID().uuidString,auditID:UUID().uuidString,migrationStatus:"active")
        var s=N2SimpleInventoryState(regime:regime,products:[],movements:[],metadataEvents:[],incidents:[],
            clinicalImports:[],historicalUses:try historicalUses(snapshot,report:report),
            openingIsExtraordinary:request.extraordinaryOpening,appliedCommands:[:])
        for (index,original) in request.initialProducts.enumerated() {
            var p=original;p.lastCountAt=request.at
            guard validProduct(p),let actual=catalog.clinical.first(where:{$0.code==p.code}),
                  actual.name==p.name,actual.unit==p.unit else{throw N2SimpleInventoryError.invalidProduct}
            let id="INITIAL:"+request.id+":"+String(index)
            var empty=p;empty.quantity=0
            s.products.append(p)
            s.movements.append(movement(id:id,p:empty,kind:"initial",at:request.at,after:p.quantity,
                op:request.operatorName,reason:"Conteo físico inicial confirmado"))
            s.metadataEvents.append(metadata(id:id+":expiry",code:p.code,at:request.at,op:request.operatorName,
                reason:"Próximo vencimiento inicial de referencia",previous:"",next:p.expiry,verified:p.expiryVerified))
        }
        // Only obsolete operational data is retired. Clinical dictionaries and
        // all unknown clinical extensions remain semantically byte-for-byte.
        for name in ["stockLots","stockMovements","ambulatoryReconciliation","deliveryIncidents","nativePendingDispensingEvidence",
                     "nativeStockSiteVerifications","nativeLotMetadataCorrections"] {root[name]=[Any]()}
        let next=try putting(s,in:root)
        _=try N2ClinicalCorrections.pendingDiscrepancies(next)
        return next
    }
    public static func restoreClinical(snapshot:Data,backup:N2VerifiedInventoryBackup,
                                       eventID:String,operatorName:String,at:Int64,confirmed:Bool)throws->Data {
        guard confirmed else{throw N2SimpleInventoryError.confirmationRequired}
        _=try audit(snapshot)
        var root=try object(snapshot),s=try state(root)
        guard text(eventID),text(operatorName),validTime(at),at>=s.regime.activatedAt else {
            throw N2SimpleInventoryError.invalidEvent
        }
        if s.clinicalImports.contains(where:{$0.sourceSHA256==backup.sourceSHA256}) {return snapshot}
        let source=try object(backup.snapshot)
        let sourceReport=try N2VersionedSnapshotAudit.inspect(backup.snapshot,allowEmptySynthetic:true)
        guard var workers=root["workers"] as? [[String:Any]],let incomingWorkers=source["workers"] as? [[String:Any]],
              var visits=root["attentions"] as? [[String:Any]],let incomingVisits=source["attentions"] as? [[String:Any]],
              var allergies=root["allergies"] as? [String:Any],let incomingAllergies=source["allergies"] as? [String:Any] else {
            throw N2SimpleInventoryError.invalidSnapshot
        }
        let initialWorkers=workers.count,initialVisits=visits.count
        var knownWorkers=Dictionary(uniqueKeysWithValues:workers.compactMap{w->(String,[String:Any])? in
            guard let id=w["dni"] as? String else{return nil};return(id,w)})
        var knownVisits=Dictionary(uniqueKeysWithValues:visits.compactMap{v->(String,[String:Any])? in
            guard let id=v["id"] as? String else{return nil};return(id,v)})
        // An established canonical DNI wins, including updated employment/name.
        // No imported profile overwrites the current person's identity silently.
        for worker in incomingWorkers {
            guard let dni=worker["dni"] as? String else{throw N2SimpleInventoryError.invalidClinicalLink}
            if knownWorkers[dni]==nil {workers.append(worker);knownWorkers[dni]=worker}
        }
        var addedVisitIDs=Set<String>()
        for visit in incomingVisits {
            guard let id=visit["id"] as? String else{throw N2SimpleInventoryError.invalidClinicalLink}
            if let prior=knownVisits[id] {
                guard try bytes(prior)==bytes(visit) else{throw N2SimpleInventoryError.conflictingClinicalRecord}
            }else {visits.append(visit);knownVisits[id]=visit;addedVisitIDs.insert(id)}
        }
        for (dni,value) in incomingAllergies {
            if let prior=allergies[dni] {
                guard try JSONSerialization.data(withJSONObject:prior,options:.sortedKeys)==JSONSerialization.data(withJSONObject:value,options:.sortedKeys) else {
                    throw N2SimpleInventoryError.conflictingClinicalRecord
                }
            }else {allergies[dni]=value}
        }
        root["workers"]=workers;root["attentions"]=visits;root["allergies"]=allergies
        // Approved correspondences and clinical correction histories are retained.
        // Conflicting immutable IDs or nonidentical same-key dictionaries fail closed.
        let operational:Set<String>=["workers","attentions","allergies","stockLots","stockMovements","ambulatoryReconciliation","deliveryIncidents",
            "nativePendingDispensingEvidence","nativeStockSiteVerifications","nativeLotMetadataCorrections",
            "inventorySchemaVersion","simpleInventory","notifications"]
        for name in source.keys.sorted() where !operational.contains(name) {
            guard let incoming=source[name] else{continue}
            if let list=incoming as? [[String:Any]] {
                var target=root[name] as? [[String:Any]] ?? []
                var canonical=Set(try target.map{try bytes($0)})
                for row in list {
                    let data=try bytes(row)
                    if canonical.contains(data){continue}
                    if let id=row["id"] as? String,target.contains(where:{$0["id"] as? String==id}) {
                        throw N2SimpleInventoryError.conflictingClinicalRecord
                    }
                    target.append(row);canonical.insert(data)
                }
                root[name]=target
            }else {
                if let old=root[name] {
                    guard try JSONSerialization.data(withJSONObject:old,options:[.sortedKeys,.fragmentsAllowed]) == JSONSerialization.data(withJSONObject:incoming,options:[.sortedKeys,.fragmentsAllowed]) else {
                        throw N2SimpleInventoryError.conflictingClinicalRecord
                    }
                } else {root[name]=incoming}
            }
        }
        let historical=try historicalUses(backup.snapshot,report:sourceReport)
        s.historicalUses.append(contentsOf:historical.filter{addedVisitIDs.contains($0.visitID)})
        s.clinicalImports.append(N2SimpleClinicalImport(id:eventID,sourceSHA256:backup.sourceSHA256,at:at,
            operatorName:operatorName,workersAdded:workers.count-initialWorkers,visitsAdded:visits.count-initialVisits))
        let next=try putting(s,in:root)
        _=try N2ClinicalCorrections.pendingDiscrepancies(next)
        return next
    }
}
