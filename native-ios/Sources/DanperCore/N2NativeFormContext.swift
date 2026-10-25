import Foundation

/// Single-professional identity inherited from DANPER Build 222.
/// This is the app's own preconfigured operator, not the patient's DNI.
/// Never use this identity to rewrite immutable imported attentions.
public enum N2ClinicianIdentity {
    public static let name="Felipe Azcárate Silva"
    public static let dni="74958455"
}

/// Stored birthday is the source of truth; exported age is computed on the clinical date.
public enum N2WorkerAge {
    public static func years(birthDate:String,on clinicalDate:String)->Int? {
        func parts(_ iso:String)->(Int,Int,Int)? {
            guard iso.range(of:#"^\d{4}-\d{2}-\d{2}$"#,options:.regularExpression) != nil else{return nil}
            let a=iso.split(separator:"-").compactMap{Int($0)}
            guard a.count==3 else{return nil}
            var cal=Calendar(identifier:.gregorian)
            cal.timeZone=TimeZone(secondsFromGMT:0)!
            guard let date=cal.date(from:DateComponents(year:a[0],month:a[1],day:a[2])),
                  cal.component(.year,from:date)==a[0],
                  cal.component(.month,from:date)==a[1],
                  cal.component(.day,from:date)==a[2] else{return nil}
            return (a[0],a[1],a[2])
        }
        guard let b=parts(birthDate),let d=parts(clinicalDate) else{return nil}
        let age=d.0-b.0-((d.1,d.2)<(b.1,b.2) ? 1:0)
        return (0...120).contains(age) ? age : nil
    }
}

public struct N2FormWorker:Equatable,Sendable,Identifiable {
    public var id:String{dni}
    public let dni:String
    public let name:String
    public let area:String
    public let labor:String
    public let sex:String
    public let age:String
    public let ubigeo:String
    public let site:String
    public var birthDate:String=""
}
public struct N2FormAllergy:Equatable,Sendable {
    public let status:String
    public let substances:String
    public let reviewed:Bool
}
public struct N2FormLot:Equatable,Sendable,Identifiable {
    public let id:String
    public let kardexCode:String
    public let name:String
    public let unit:String
    public let expires:String
    public let capacity:Double
    public let sealed:Int
    public let loose:Double
    public let opened:Double
    public var site:String=""
    public var reference:String=""
    public var openContainers:Int=0
    public var total:Double {Double(sealed)*capacity+loose+opened}
    public var needsOpening:Bool {openContainers==0 && sealed>0}
}
public struct N2FormContext:Sendable {
    public var operationalMappings:[N2OperationalMapping]=[]
    public var auxiliaryProducts:[N2NursingCatalogProduct]=[]
    public let revision:Int
    public let workers:[N2FormWorker]
    public let allergies:[String:N2FormAllergy]
    public let lots:[N2FormLot]
    public let products:N2NativeCatalogIndex
    /// Historical evidence is allowed for a catalogued, now-empty lot:
    /// the declaration records an old R=1/0 in the cut, not a new stock debit.
    /// Never use this method for current FEFO availability.
    public func historicalOptions(for code:String,at date:String)->[N2FormLot] {
        let operational=operationalMappings.filter{$0.clinicalCode==code}
        let linked=Set(operational.isEmpty
            ? products.authorizedNursingOptions(for:code).map(\.id)
            : operational.map(\.inventoryID))
        return lots.filter {
            linked.contains($0.kardexCode) &&
            ($0.expires.isEmpty || $0.expires>=date)
        }.sorted {
            let a=$0.expires.isEmpty ? "9999-12-31":$0.expires
            let b=$1.expires.isEmpty ? "9999-12-31":$1.expires
            return a==b ? $0.id<$1.id : a<b
        }
    }
    public func options(for code:String,at date:String,site:String="")->[N2FormLot] {
        let operational=operationalMappings.filter{$0.clinicalCode==code}
        let approved=Set(operational.isEmpty
            ? products.authorizedNursingOptions(for:code).map(\.id)
            : operational.map(\.inventoryID))
        return lots.filter {
            approved.contains($0.kardexCode) && ($0.total>0 || $0.openContainers>0) &&
            ($0.expires.isEmpty || $0.expires>=date)
        }.sorted {
            let a=$0.expires.isEmpty ? "9999-12-31":$0.expires
            let b=$1.expires.isEmpty ? "9999-12-31":$1.expires
            return a==b ? $0.id<$1.id : a<b
        }
    }
}
public enum N2FormError:Error,Equatable {
    case absentSnapshot,invalidWorker,invalidAllergy,invalidProduct
    case invalidDate,invalidVisit,unreviewedAllergies
}
public enum N2NativeFormContextReader {
    public static func read(snapshot:Data,revision:Int,products:N2NativeCatalogIndex)
        throws->N2FormContext {
        guard (try? N1eLegacyClinicalAudit.inspect(snapshot,allowEmptySynthetic:true)) != nil,
              (try? N1fLosslessFieldGate.inspect(snapshot)) != nil,
              let root=try? JSONSerialization.jsonObject(with:snapshot) as? [String:Any],
              let w=root["workers"] as? [[String:Any]],
              let allergy=root["allergies"] as? [String:Any],
              let stock=root["stockLots"] as? [[String:Any]] else {
            throw N2FormError.absentSnapshot
        }
        let roster=try N2NativeSnapshotReader.read(snapshot)
        let allowed=Set(roster.searchableRoster.map(\.dni))
        let people=w.compactMap { row->N2FormWorker? in
            guard let dni=row["dni"] as? String,
                  let name=row["name"] as? String,allowed.contains(dni) else {
                return nil
            }
            var worker=N2FormWorker(dni:dni,name:name,
                area:row["area"] as? String ?? "",
                labor:row["labor"] as? String ?? "",
                sex:row["sex"] as? String ?? "",
                age:String(describing:row["age"] ?? ""),
                ubigeo:row["ubigeo"] as? String ?? "",
                site:row["site"] as? String ?? "")
            worker.birthDate=row["birthDate"] as? String ?? ""
            return worker
        }.sorted{$0.name.localizedStandardCompare($1.name) == .orderedAscending}
        var records:[String:N2FormAllergy]=[:]
        for (dni,value) in allergy {
            guard let obj=value as? [String:Any],
                  let status=obj["status"] as? String,
                  ["known","none","unknown"].contains(status),
                  let substances=obj["substances"] as? String else{
                throw N2FormError.invalidAllergy
            }
            records[dni]=N2FormAllergy(status:status,
                                      substances:substances,reviewed:true)
        }
        let sites=try N2StockSiteEvidence.resolve(root)
        let all=stock.compactMap { row->N2FormLot? in
            guard let id=row["id"] as? String,
                  let code=row["code"] as? String,
                  let name=row["name"] as? String,
                  let unit=row["catalogUnit"] as? String,
                  let expiry=row["expires"] as? String,
                  let capacity=(row["unitsPerContainer"] as? NSNumber)?.doubleValue,
                  let sealed=(row["sealedContainers"] as? NSNumber)?.intValue,
                  let loose=(row["looseUnits"] as? NSNumber)?.doubleValue,
                  let opened=(row["openedRemaining"] as? NSNumber)?.doubleValue else {
                return nil
            }
            return N2FormLot(id:id,kardexCode:code,name:name,unit:unit,
                             expires:expiry,capacity:capacity,sealed:sealed,
                             loose:loose,opened:opened,site:sites[id] ?? "",
                              reference:row["lot"] as? String ?? "",
                              openContainers:N2ContainerAccounting.openCount(row))
        }
        guard all.count==stock.count else{throw N2FormError.invalidProduct}
        var result=N2FormContext(revision:revision,workers:people,
                             allergies:records,lots:all,products:products)
        result.operationalMappings=try N2OperationalMappings.read(snapshot)
        result.auxiliaryProducts=try N2AuxiliaryInventory.products(snapshot:snapshot)
        return result
    }
}

/// Clinical-only form state. Never stores any read-only stock amounts or any
/// credentials. Save uses the existing official A–AD compatible visit schema.
public struct N2FormMedication:Equatable,Sendable,Identifiable {
    public let id:String
    public var code:String
    public var quantity:Int
    public var procedure:String
    public var procedureConfirmed:Bool
    public var procedureSource:String
    public var selectedLotID:String
    public var physicalQuantity:Double
    public var approveOpening:Bool
    /// User explicitly confirmed the previously open container was exhausted.
    public var closePriorContainer:Bool=false
    public var reusePreviouslyOpened:Bool=false
    public var newContainers:Int=1
    public init(id:String=UUID().uuidString,code:String,quantity:Int=1,
                procedure:String="",selectedLotID:String="",
                physicalQuantity:Double=0,approveOpening:Bool=false) {
        self.id=id;self.code=code;self.quantity=quantity
        self.procedure=procedure;self.selectedLotID=selectedLotID
        self.procedureConfirmed = !procedure.isEmpty
        self.procedureSource = procedure.isEmpty ? "review" : "manual"
        self.physicalQuantity=physicalQuantity;self.approveOpening=approveOpening
    }
}
public struct N2NativeFormDraft:Equatable,Sendable {
    public let id:String
    public var dni:String=""
    public var date:String=""
    public var time:String=""
    public var dispensingSite:String=""
    public var category:String=""
    public var system:String=""
    public var segment:String=""
    public var diagnosis:String=""
    public var procedures:[String]=[]
    public var items:[N2FormMedication]=[]
    public var permission:String="NO"
    public var permissionTime:String=""
    public var photoSent:Bool=false
    public var photoReviewed:Bool=false
    public var blueBandage:Bool=false
    public var returned:Bool=false
    public var responsible:String=N2ClinicianIdentity.name
    public var responsibleDni:String=N2ClinicianIdentity.dni
    /// Older draft snapshots may omit responsibleDni. Repair the new save
    /// only when the recorded responsible is the configured sole operator.
    private var effectiveResponsibleDni:String {
        let saved=responsibleDni.trimmingCharacters(in:.whitespacesAndNewlines)
        return saved.isEmpty && responsible==N2ClinicianIdentity.name
            ? N2ClinicianIdentity.dni : saved
    }
    public init(id:String=UUID().uuidString) {self.id=id}

    public func makeSavedVisit(context:N2FormContext)throws->Data {
        guard let worker=context.workers.first(where:{$0.dni==dni}) else {
            throw N2FormError.invalidWorker
        }
        guard let allergy=context.allergies[dni],allergy.reviewed,
              (allergy.status != "known" || !allergy.substances.isEmpty) else {
            throw N2FormError.unreviewedAllergies
        }
        let parts=date.split(separator:"-").compactMap{Int($0)}
        var cal=Calendar(identifier:.gregorian)
        cal.timeZone=TimeZone(secondsFromGMT:0)!
        let parsed=parts.count==3 ? cal.date(from:DateComponents(
            year:parts[0],month:parts[1],day:parts[2])) : nil
        guard date.range(of:#"^\d{4}-\d{2}-\d{2}$"#,
                         options:.regularExpression) != nil,
              parts.count==3,(1900...2100).contains(parts[0]),
              let parsed,
              cal.component(.year,from:parsed)==parts[0],
              cal.component(.month,from:parsed)==parts[1],
              cal.component(.day,from:parsed)==parts[2],
              time.range(of:#"^([01]\d|2[0-3]):[0-5]\d$"#,
                        options:.regularExpression) != nil else {
            throw N2FormError.invalidDate
        }
        guard (0...3).allSatisfy({clinicalIssues(step:$0,context:context).isEmpty}),
              (!procedures.isEmpty || !items.isEmpty),
              !diagnosis.trimmingCharacters(in:.whitespaces).isEmpty,
              ["NO","SI"].contains(permission),
              (permission != "SI" || permissionTime.range(of:
                  #"^([01]\d|2[0-3]):[0-5]\d$"#,
                  options:.regularExpression) != nil),
              !responsible.isEmpty,
              effectiveResponsibleDni.range(of:#"^\d{8}$"#,
                  options:.regularExpression) != nil,
              (!hasWound || photoReviewed) else {
            throw N2FormError.invalidVisit
        }
        var lines=[[String:Any]]()
        for med in items {
            guard med.quantity>0,med.quantity<=10_000_000,
                  !med.procedure.isEmpty,
                  let product=context.products.clinical.first(where:{$0.code==med.code})
            else {throw N2FormError.invalidProduct}
            var row:[String:Any]=[
                "id":med.id,"code":product.code,"name":product.name,
                "unit":product.unit,"quantity":med.quantity,
                "procedure":med.procedure,
                "procedureConfirmed":med.procedureConfirmed,
                "procedureSource":med.procedureSource,
                "confirmNewContainer":med.approveOpening,"newContainers":med.approveOpening ? med.newContainers:0,
                "previousContainerExhausted":med.approveOpening && med.closePriorContainer,
                "reusePreviouslyOpened":med.reusePreviouslyOpened && !med.approveOpening
            ]
            if !med.selectedLotID.isEmpty || med.physicalQuantity>0 {
                // Preserve the operator's clinical record if stock changed
                // while editing. The transactional engine verifies identity,
                // availability and scope and records a pending reason instead.
                guard med.physicalQuantity>=0,med.physicalQuantity.isFinite else{
                    throw N2FormError.invalidProduct
                }
                row["physicalUse"]=[
                    "lotId":med.selectedLotID,
                    "quantity":med.physicalQuantity,
                    "confirmNewContainer":med.approveOpening,"newContainers":med.approveOpening ? med.newContainers:0,
                "previousContainerExhausted":med.approveOpening && med.closePriorContainer,
                "reusePreviouslyOpened":med.reusePreviouslyOpened && !med.approveOpening
                ] as [String:Any]
            }
            lines.append(row)
        }
        let workerRaw:[String:Any]=[
            "dni":worker.dni,"name":worker.name,"area":worker.area,
            "labor":worker.labor,"sex":worker.sex,
            "age":N2WorkerAge.years(birthDate:worker.birthDate,on:date)
                .map(String.init) ?? worker.age,
            "birthDate":worker.birthDate,
            "ubigeo":worker.ubigeo,"site":worker.site
        ]
        let hasWound=(procedures + items.map(\.procedure)).contains{
            $0.contains("HERIDA") || $0.contains("SUTUR")
        }
        let source:[String:Any]=[
            "id":id,"status":"saved","date":date,"time":time,
            "dispensingSite":dispensingSite,
            "worker":workerRaw,"category":category,"system":system,
            "segment":segment,"diagnosis":diagnosis,"items":lines,
            "permission":permission,
            "workStatus":permission=="SI" ? "PERMISO":"LABORANDO",
            "permissionTime":permissionTime,
            "blueBandage":blueBandage,"returned":returned,
            "photoSent":hasWound && photoSent,
            "responsible":responsible,"responsibleDni":effectiveResponsibleDni,
            "standaloneProcedures":procedures
        ]
        return try JSONSerialization.data(withJSONObject:source)
    }
    public func makeDraftPatch(context:N2FormContext,stage:Int=0)throws->Data {
        let worker=context.workers.first(where:{$0.dni==dni})
        let workerRaw:[String:Any]=worker.map {
            ["dni":$0.dni,"name":$0.name,"area":$0.area,
             "labor":$0.labor,"sex":$0.sex,
             "age":N2WorkerAge.years(birthDate:$0.birthDate,on:date)
                 .map(String.init) ?? $0.age,
             "birthDate":$0.birthDate,
             "ubigeo":$0.ubigeo,"site":$0.site]
        } ?? [:]
        let itemRows:[[String:Any]]=items.map { med in
            var row:[String:Any]=[
                "id":med.id,"code":med.code,"quantity":med.quantity,
                "procedure":med.procedure,
                "procedureConfirmed":med.procedureConfirmed,
                "procedureSource":med.procedureSource,
                "confirmNewContainer":med.approveOpening,"newContainers":med.approveOpening ? med.newContainers:0,
                "previousContainerExhausted":med.approveOpening && med.closePriorContainer,
                "reusePreviouslyOpened":med.reusePreviouslyOpened && !med.approveOpening
            ]
            if let catalog=context.products.clinical.first(where:{$0.code==med.code}) {
                row["name"]=catalog.name;row["unit"]=catalog.unit
            }
            if !med.selectedLotID.isEmpty || med.physicalQuantity>0 {
                row["physicalUse"]=[
                    "lotId":med.selectedLotID,"quantity":med.physicalQuantity,
                    "confirmNewContainer":med.approveOpening,"newContainers":med.approveOpening ? med.newContainers:0,
                "previousContainerExhausted":med.approveOpening && med.closePriorContainer,
                "reusePreviouslyOpened":med.reusePreviouslyOpened && !med.approveOpening
                ] as [String:Any]
            }
            return row
        }
        return try JSONSerialization.data(withJSONObject:[
            "worker":workerRaw,"items":itemRows,"nativeDraftStep":max(0,min(3,stage)),
            "date":date,"time":time,"category":category,
            "dispensingSite":dispensingSite,
            "system":system,"segment":segment,"diagnosis":diagnosis,
            "permission":permission,"permissionTime":permissionTime,
            "blueBandage":blueBandage,"returned":returned,
            "photoSent":photoSent,"photoReviewed":photoReviewed,"responsible":responsible,
            "responsibleDni":effectiveResponsibleDni,
            "standaloneProcedures":procedures,
            "workStatus":permission=="SI" ? "PERMISO":"LABORANDO"
        ])
    }
}

