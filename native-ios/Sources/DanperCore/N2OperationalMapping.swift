import Foundation

public struct N2OperationalMapping:Codable,Sendable,Equatable,Identifiable {
    public let id:String
    public let clinicalCode:String
    public let clinicalName:String
    public let clinicalUnit:String
    public let inventoryID:String
    public let inventoryName:String
    public let presentation:String
    public let physicalUnit:String
    public let physicalUnitsPerClinicalUnit:Double
    public let confirmedAt:Int64
    public let operatorName:String
    public let evidence:String
    public let version:Int
    public let status:String
    public init(clinical:N2ClinicalCatalogProduct,inventory:N2NursingCatalogProduct,
                physicalUnit:String,conversion:Double,confirmedAt:Int64,
                operatorName:String,evidence:String) {
        id=UUID().uuidString;clinicalCode=clinical.code;clinicalName=clinical.name
        clinicalUnit=clinical.unit;inventoryID=inventory.id;inventoryName=inventory.name
        presentation=inventory.unit ?? "";self.physicalUnit=physicalUnit
        physicalUnitsPerClinicalUnit=conversion;self.confirmedAt=confirmedAt
        self.operatorName=operatorName;self.evidence=evidence
        version=1;status="operational-verified"
    }
}

public enum N2OperationalMappings {
    public enum Failure:Error {case invalidRule,conflictingRule,invalidSnapshot}
    public static func read(_ snapshot:Data)throws->[N2OperationalMapping] {
        guard let root=try JSONSerialization.jsonObject(with:snapshot) as? [String:Any] else {
            throw Failure.invalidSnapshot
        }
        guard let value=root["nativeOperationalMappings"] else{return []}
        let rules=try JSONDecoder().decode([N2OperationalMapping].self,
            from:JSONSerialization.data(withJSONObject:value))
        guard rules.count<=500,Set(rules.map(\.id)).count==rules.count,
              Set(rules.map(\.clinicalCode)).count==rules.count else{throw Failure.invalidRule}
        for rule in rules {try validate(rule)}
        return rules
    }
    private static func validate(_ rule:N2OperationalMapping)throws {
        guard rule.version==1,rule.status=="operational-verified",rule.confirmedAt>0,
              !rule.clinicalCode.isEmpty,!rule.clinicalName.isEmpty,!rule.clinicalUnit.isEmpty,
              !rule.inventoryID.isEmpty,!rule.inventoryName.isEmpty,!rule.presentation.isEmpty,
              ["UND","PAR","mL","g"].contains(rule.physicalUnit),
              rule.physicalUnitsPerClinicalUnit.isFinite,
              rule.physicalUnitsPerClinicalUnit>0,rule.physicalUnitsPerClinicalUnit<=10_000_000,
              rule.operatorName.trimmingCharacters(in:.whitespacesAndNewlines).count>=3,
              rule.evidence.trimmingCharacters(in:.whitespacesAndNewlines).count>=10 else {
            throw Failure.invalidRule
        }
        if ["UND","TBL","PAR"].contains(rule.clinicalUnit.uppercased()) {
            guard rule.physicalUnitsPerClinicalUnit==1,
                  rule.physicalUnit==(rule.clinicalUnit=="PAR" ? "PAR":"UND") else{throw Failure.invalidRule}
        }
    }
    public static func append(snapshot:Data,rule:N2OperationalMapping,
                              catalog:N2NativeCatalogIndex,explicitConsent:Bool)throws->Data {
        try validate(rule)
        let inventory=catalog.nursing + (try N2AuxiliaryInventory.products(snapshot:snapshot))
        guard explicitConsent,
              catalog.clinical.contains(where:{$0.code==rule.clinicalCode && $0.name==rule.clinicalName && $0.unit==rule.clinicalUnit}),
              inventory.contains(where:{$0.id==rule.inventoryID && $0.name==rule.inventoryName && $0.unit==rule.presentation}) else {
            throw Failure.invalidRule
        }
        var rules=try read(snapshot)
        if rules.contains(rule){return snapshot}
        guard !rules.contains(where:{$0.clinicalCode==rule.clinicalCode}) else {
            throw Failure.conflictingRule
        }
        rules.append(rule)
        var root=try JSONSerialization.jsonObject(with:snapshot) as! [String:Any]
        root["nativeOperationalMappings"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(rules))
        return try JSONSerialization.data(withJSONObject:root,options:.sortedKeys)
    }
}
